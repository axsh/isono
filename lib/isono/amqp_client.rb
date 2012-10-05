# -*- coding: utf-8 -*-

require 'thread'

require 'eventmachine'
require 'amqp'

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

      prepare_connect {
        @amqp_client = ::AMQP.connect(opts)
        @amqp_client.instance_eval {
          def settings
            @settings
          end

          @on_disconnect = Proc.new do
            # This block will be executed when you start the Agent if the AMQP server has been stopped.
            Isono.at_disconnected.each do |blk|
              blk.call
            end
            blk.call(:error)
          end
        }
        @amqp_client.connection_status { |t|
          case t
          when :connected
            # here is tried also when reconnected
            on_connect
          when :disconnected
            # This block is executed if the AMQP server goes down during startup.
            on_disconnected
            Isono.at_disconnected.each do |blk|
              blk.call
            end
          end
        }
        # the block argument is called once at the initial connection.
        @amqp_client.callback {
          after_connect
          if blk
            blk.arity == 1 ? blk.call(self) : blk.call
          end
        }
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

    def before_connect
    end

    def after_connect
    end

    def before_close
    end

    def after_close
    end
    
    def close(&blk)
      return unless connected?

      prepare_close {
        @amqp_client.close {
          begin
            on_close
            after_close
            blk.call if blk
          ensure
            @amqp_client = nil
            Thread.current[:mq] = nil
          end
        }
      }
    end

    # Create new AMQP channel object
    #
    # @note Do not have to close by user. Channel close is performed
    #       as part of connection close.
    def create_channel
      AMQP::Channel.new(@amqp_client)
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

    private
    def prepare_connect(&blk)
      before_connect
      blk.call
    end

    def prepare_close(&blk)
      before_close
      blk.call
    end
    
  end
end
