# -*- coding: utf-8 -*-

require 'optparse'
require 'amqp'
require 'digest/sha1'

require 'isono'
require 'isono/amqp_client'

module Isono
  module Runner
    # Run a new agent which provides RPC endpoint and delayed job.
    #
    # @example
    #
    # class RpcEndpoint1
    #   def func1
    #   end
    # end
    #
    # class RpcEndpoint2
    #   def func2
    #   end
    # end
    # 
    # Isono::Runner::RpcServer.start do
    #  endpoint('xxxx1', RpcEndpoint1.new)
    #  endpoint('xxxx2', RpcEndpoint2.new)
    # end
    #
    # mc = MessagingClient.new
    # xxxx1 = mc.rpc('xxxx1')
    # xxxx1.func1
    #
    # xxxx2 = mc.rpc('xxxx2')
    # xxxx2.func2
    module RpcServer

      class EndpointBuilder
        def session_id
          job_context.session_id
        end
        def job_context
          Thread.current[Isono::NodeModules::JobWorker::JOB_CTX_KEY]
        end
        module BuildMethods
          # @exmaple
          # job 'command1', proc {
          #     # do somthing.
          #   }, proc {
          #     # do somthing on job failure.
          #   }
          # @example
          # job 'command1' do
          #   response.fail_cb {
          #     # do somthing on job failure.
          #   }
          #   sleep 10
          # end
          def job(command, run_cb=nil, fail_cb=nil, &blk)
            app = if run_cb.is_a?(Proc)
                    proc {
                      if fail_cb.is_a?(Proc)
                        response.fail_cb do
                          self.instance_eval(&fail_cb) 
                        end
                      end

                      self.instance_eval(&run_cb)
                    }
                  elsif blk
                    blk
                  else
                    raise ArgumentError, "callbacks were not set propery"
                  end
            add(:job, command, &app)
          end

          def rpc(command, &blk)
            add(:rpc, command, &blk)
          end

          def concurrency(num)
            raise ArgumentError unless num.is_a?(Fixnum)
            @concurrency = num
          end

          def job_thread_pool(thread_pool)
            raise ArgumentError unless thread_pool.is_a?(Isono::ThreadPool)
            @job_thread_pool = thread_pool
          end
          
          def setup(endpoint_name, builder)
            app_builder = lambda { |builder_hooks|
              return nil if builder_hooks.empty?
              map_app = Rack::Map.new
              builder_hooks.each { |b|
                b.call(map_app, builder)
              }
              map_app
            }
            
            app = app_builder.call(@builders[:job])
            if app
              builder.job_channel.register_endpoint(endpoint_name,
                                                    Rack.build do
                                                      run app
                                                    end,
                                                    {:concurrency=>@concurrency,
                                                      :thread_pool=>@job_thread_pool})
            end
            
            app = app_builder.call(@builders[:rpc])
            if app
              builder.rpc_channel.register_endpoint(endpoint, Rack.build do
                                                      run app
                                                    end, {:prefetch=>@concurrency})
            end
          end
          
          protected
          def add(type, command, &blk)
            @builders[type] << lambda { |rack_map, ctx|
              rack_map.map(command, Rack::Proc.new(ctx, &blk))
            }
          end
        end
        
        def self.inherited(klass)
          klass.class_eval {
            @builders = {:job=>[], :rpc=>[]}
            @concurrency = 1
            @job_thread_pool = nil
            extend BuildMethods
          }
        end

        def initialize(node)
          @node = node
          @rpc_channel = NodeModules::RpcChannel.new(@node)
          @job_channel = NodeModules::JobChannel.new(@node)
          after_initialize
        end

        def job_channel
          @job_channel
        end
        alias :job :job_channel

        def rpc_channel
          @rpc_channel
        end
        alias :rpc :rpc_channel

        protected
        def after_initialize
        end
      end

      DEFAULT_MANIFEST = Manifest.new(Dir.pwd) do
        load_module NodeModules::EventChannel
        load_module NodeModules::DirectChannel
        load_module NodeModules::RpcChannel
        load_module NodeModules::JobWorker
        load_module NodeModules::JobChannel
      end
      
      def start(manifest=nil, opts={}, &blk)
        rpcsvr = Server.new(blk)
        rpcsvr.run(manifest)
      end
      module_function :start

      class Server < Base
        def initialize(builder_block)
          super()
          @endpoints = {}
          @builder_block = builder_block
        end

        # DSL method
        def endpoint(endpoint, builder_class, *args)
          raise ArgumentError unless builder_class.is_a?(Class) && builder_class < EndpointBuilder
          raise "Duplicate endpoint name: #{endpoint}" if @endpoints[endpoint.to_s]
          @endpoints[endpoint.to_s] = builder_class.new(@node, *args)
        end
        
        protected
        def run_main(manifest=nil)
          @node = Isono::Node.new(manifest)
          @node.connect(@options[:amqp_server_uri]) do
            self.instance_eval(&@builder_block) if @builder_block

            @endpoints.each {|name, i| i.class.setup(name, i) }
          end
        end
        
      end
      
    end
  end
end
