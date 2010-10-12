# -*- coding: utf-8 -*-

require 'isono'
require 'eventmachine'

module Isono
  # @example Sync RPC call with object method. 
  # mc = MessagingClient.start
  # puts mc.request('endpoint', 'func1', xxxx, xxxx)
  # puts mc.request('endpoint', 'func2', xxx, xxx)
  #
  # @example Sync RPC call using delegated object
  # mc = MessagingClient.start
  # endpoint = mc.sync_rpc('endpoint')
  # endpoint.func1(xxxx, xxxx)
  # endpoint.func2(xxx, xxx)
  #
  class MessagingClient < Node
    include Logger

    def self.start(amqp_uri, manifest=nil, &blk)
      node = self.new(manifest, &blk)

      if EventMachine.reactor_thread?
        EventMachine.schedule {
          node.connect(amqp_uri)
        }
      else
        q = ::Queue.new
        EventMachine.schedule {
          node.connect(amqp_uri) { |type|
            q << type
          }
        }
        case q.deq
        when :success
        when :error
          raise "Connection failed: #{amqp_uri}"
        end
      end

      node
    end

    def stop
      if connected?
        close {
          EventMachine.schedule {
            EventMachine.stop
          }
        }
      end
    end
    
    def initialize(m=nil, &blk)
      m ||= Manifest.new(Dir.pwd) {
        node_name 'msgclient'
        node_instance_id Util.gen_id

        load_module NodeModules::EventChannel
        load_module NodeModules::RpcChannel
      }
      m.instance_eval(&blk) if blk
      super(m)
    end

    class RpcSyncDelegator
      attr_reader :endpoint
      
      def initialize(rpc, endpoint, opts={})
        @rpc = rpc
        @endpoint = endpoint
        @opts = {:timeout=>0.0, :oneshot=>false}.merge(opts)
      end

      private
      def method_missing(m, *args)
        if @opts[:oneshot]
          oneshot_request(m, *args)
        else
          normal_request(m, *args)
        end
      end

      def oneshot_request(m, *args)
        @rpc.request(@endpoint, m, *args) { |req|
          req.oneshot = true
        }
      end

      def normal_request(m, *args)
        @rpc.request(@endpoint, m, *args)
      end
    end
    
    def sync_rpc(endpoint, opts={})
      rpc = NodeModules::RpcChannel.new(self)
      RpcSyncDelegator.new(rpc, endpoint, opts)
    end

    def request(endpoint, key, *args, &blk)
      rpc = NodeModules::RpcChannel.new(self)
      rpc.request(endpoint, key, *args, &blk)
    end

  end
end
