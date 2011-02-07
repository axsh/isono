# -*- coding: utf-8 -*-

require 'thread'

require 'eventmachine'
require 'amqp'
require 'mq'

require 'uri/generic'

module URI
  # Declare amqp:// URI scheme.
  class AMQP < Generic
    COMPONENT = [
      :scheme,
      :userinfo, :host, :port,
      :path
    ].freeze

    DEFAULT_PORT=5672

    def self.build(args)
      tmp = Util::make_components_hash(self, args)
      return super(tmp)
    end

    def initialize(*args)
      args[5] = '/' if args[5].nil? || args[5] == ''
      super(*args)
    end

    alias :vhost :path
    alias :vhost= :path=
  end

  @@schemes['AMQP'] = AMQP
end


module Isono
  # AMQP Client module for master and agent
  # 
  # @example 
  # class Client
  #   include Isono::AmqpClient
  #
  #   def logger()
  #   end
  # end
  module AmqpClient
    attr_reader :mq, :amqp_client
    
    def amqp_server_uri
      raise "The connection is not established yet." unless @amqp_client && connected?

      URI::AMQP.build(:host => @amqp_client.settings[:host],
                      :port => @amqp_client.settings[:port],
                      :path => @amqp_client.settings[:vhost]
                      )
    end

    def connect(broker_uri, *args, &blk)
      raise "the connection is still alive for: #{amqp_server_uri}" if connected?

      broker_uri = URI.parse(broker_uri.to_s) unless broker_uri.is_a?(URI)
      default = ::AMQP.settings
      opts = {:host => broker_uri.host, 
        :port => broker_uri.port || default[:port],
        :vhost => broker_uri.vhost || default[:vhost],
        :user=>broker_uri.user || default[:user],
        :pass=>broker_uri.password ||default[:pass]
      }
      opts.merge!(args) if args.is_a?(Hash)
      
      @amqp_client = ::AMQP.connect(opts)
      @amqp_client.instance_eval {
        def settings
          @settings
        end
      }
      @amqp_client.connection_status { |t|
        case t
        when :connected
          # here is tried also when reconnected
          on_connect
        when :disconnected
          on_disconnected
        end
      }
      # the block argument is called once at the initial connection.
      @amqp_client.callback {
        if blk
          blk.arity == 1 ? blk.call(:success) : blk.call
        end
      }
      @amqp_client.errback {
        logger.error("Failed to connect to the broker: #{amqp_server_uri}")
        blk.call(:error) if blk && blk.arity == 1
      }
            
      self
    end

    def connected?
      !@amqp_client.nil? && @amqp_client.connected?
    end

    def amq
      raise 'AMQP connection is not established yet' unless connected?
      Thread.current[:mq]
    end

    def on_connect
    end

    def on_disconnected
    end
    
    def on_close
    end

    def close(&blk)
      return unless connected?

      @amqp_client.close {
        begin
          on_close
          blk.call if blk
        ensure
          @amqp_client = nil
          Thread.current[:mq] = nil
        end
      }
    end

    def create_channel
      MQ.new(@amqp_client)
    end

    # Publish a message to the designated exchange.
    # 
    # @param [String] exname The exchange name
    # @param [String] message Message body to be sent
    # @param [Hash] opts Options with the message.
    #    :key => 'keyname'
    # @return [void]
    #
    # @example Want to broadcast the data to all bound queues:
    #  publish_to('topic exchange', 'data', :key=>'*')
    # @example Want to send the data to the specific queue(s):
    #  publish_to('exchange name', 'group.1', 'data')
    def publish_to(exname, message, opts={})
      EventMachine.schedule {
        ex = amq.exchanges[exname] || raise("Undefined exchange name : #{exname}")
        case ex.type
        when :topic
          unless opts.has_key? :key
            opts[:key] = '*'
          end
        end
        ex.publish(Serializer.instance.marshal(message), opts)
      }
    end

  end
end
