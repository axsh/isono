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
                      request.fail_cb do
                        self.instance_eval(&fail_cb)
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
      
      def start(manifest=nil, &blk)
        rpcsvr = Server.new(ARGV)
        rpcsvr.run(manifest, &blk)
      end
      module_function :start

      class Server
        def initialize(argv)
          @argv = argv.dup
          
          @options = {
            :amqp_server_uri => URI.parse('amqp://guest:guest@localhost/'),
          }
          
          parser.parse! @argv
        end
        
        def parser
          @parser ||= OptionParser.new do |opts|
            opts.banner = "Usage: agent [options]"
            
            opts.separator ""
            opts.separator "Agent options:"
            opts.on( "-i", "--id ID", "Manually specify the Node ID" ) {|str| @options[:node_id] = str }
            opts.on( "-s", "--server AMQP_URI", "amqp broker server to connect" ) {|str|
              begin
                @options[:amqp_server_uri] = URI.parse(str)
              rescue URI::InvalidURIError => e
                abort "#{e}"
              end
            }
          end
        end
        
        def run(manifest=nil, &blk)
          %w(EXIT).each { |i|
            Signal.trap(i) { Isono::Node.stop }
          }
          
          # .to_s to avoid nil -> String conversion failure.
          if @options[:node_id]
            manifest.node_instance_id(@options[:node_id])
          elsif manifest.node_instance_id.nil?
            manifest.node_instance_id(default_node_id)
          end
          
          EventMachine.epoll
          EventMachine.run {
            @node = Isono::Node.new(manifest)
            @node.connect(@options[:amqp_server_uri], @options) do
              self.instance_eval(&blk) if blk
            end
          }
        end
        
        def endpoint(endpoint, builder)
          raise TypeError unless builder.respond_to?(:build)
          builder.build(endpoint, @node)
        end
        
        private
        def default_node_id
          # use the ip address for the default routeas key value
          Digest::SHA1.hexdigest(`/sbin/ip route get 8.8.8.8`.split("\n")[0].split.last)[0, 10]
        end
      end
      
    end
  end
end
