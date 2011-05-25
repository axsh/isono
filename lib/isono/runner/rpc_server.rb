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

          def build(endpoint, node)
            helper_context = self.new(node)
            
            app_builder = lambda { |builders|
              unless builders.empty?
                map_app = Rack::Map.new
                builders.each { |b|
                  b.call(map_app, helper_context)
                }
                map_app
              end
            }

            app = app_builder.call(@builders[:job])
            if app
              NodeModules::JobChannel.new(node).register_endpoint(endpoint, Rack.build do
                                                                    run app
                                                                  end)
            end
            
            app = app_builder.call(@builders[:rpc])
            if app
              NodeModules::RpcChannel.new(node).register_endpoint(endpoint, Rack.build do
                                                                    use Rack::ThreadPass
                                                                    run app
                                                                  end
                                                                  )
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
            extend BuildMethods
          }
        end

        def initialize(node)
          @node = node
        end
      end
      

      DEFAULT_MANIFEST = Manifest.new(Dir.pwd) do
        load_module NodeModules::EventChannel
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
          @builder_block = builder_block
        end

        # DSL method
        def endpoint(endpoint, builder)
          raise TypeError unless builder.respond_to?(:build)
          builder.build(endpoint, @node)
        end
        
        protected
        def run_main(manifest=nil)
          @node = Isono::Node.new(manifest)
          @node.connect(@options[:amqp_server_uri]) do
            self.instance_eval(&@builder_block) if @builder_block
          end
        end
        
      end
      
    end
  end
end
