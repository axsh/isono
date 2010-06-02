
require 'thread'
require 'statemachine'
require 'ostruct'

module Isono
  module ManagerModules
    class MqCommand < Base
      include Logger

      def on_init(args)
        @active_requests = {}

        agent.amq.queue("command-recv.#{agent.agent_id}", {:exclusive=>true}).subscribe { |header, data|
          req = @active_requests[header.message_id]
          if req
            data = Serializer.instance.unmarshal(data)
            req.process_event(:on_received, data)
            EventRouter.emit('mq_command/request_received', agent.agent_id, data)
            begin
              if data[:type] == :error
                req.error_cb.call(data[:body]) if req.error_cb
              else
                req.success_cb.call(data[:body]) if req.success_cb
              end
            rescue => e
              logger.error(e)
            ensure
              @active_requests.delete req.ticket
              req.timer.cancel if req.timer
            end
          end
        }

        # register new command namespace will be created later.
        agent.manifest.command.add_observer(:registered) { |data|
          EventMachine.schedule {
            register_namespace(data[:namespace])
          }
        }

        # setup command-provider queues for namespaces already registered.
        agent.manifest.command.namespaces.keys.each { |ns|
          register_namespace(ns)
        }
      end

      def on_terminate
        agent.manifest.command.namespaces.keys.each { |ns|
          agent.amq.queue(provider_queue_name(ns), {:exclusive=>true}).delete
        }
        agent.amq.queue("command-recv.#{agent.agent_id}", {:exclusive=>true}).delete
      end

      def async_request(namespace, command, args={}, &blk)
        req = AsyncRequestContext.new(namespace, command, args)
        blk.call(req) if blk
        # records the req object here. the blk.call may face exception.
        @active_requests[req.ticket] = req

        if req.timeout_sec > 0
          # register the timeout hook.
          req.timer = EventMachine::Timer.new(req.timeout_sec) {
            @active_requests.delete req.ticket
            req.error_cb.call(:timeout) if req.error_cb
          }
        end

        req.process_event(:on_ready)

        # use amq.direct exchange
        agent.amq.direct('', {:key=>provider_queue_name(namespace)}).
          publish(Serializer.instance.marshal(req.request.dup),
                  {:message_id => req.ticket,
                    :key => provider_queue_name(namespace),
                    :reply_to=>"command-recv.#{agent.agent_id}"}
                  )
        
        req.process_event(:on_sent)
        EventRouter.emit('mq_command/request_sent', agent.agent_id, req.hash)
        req
      end

      def sync_request(namespace, command, args={})
        q = ::Queue.new
        async_request(namespace, command, args) { |req|
          req.on_success { |r|
            q << [:success, r]
          }

          req.on_error { |r|
            q << [:error, r]
          }
        }

        r = q.deq
        case r[0]
        when :success
          r[1]
        when :error
          r[1]
        end
      end


      private
      def register_namespace(namespace)

        queue = agent.amq.queue(provider_queue_name(namespace), {:exclusive=>true}).subscribe(:ack=>true) { |header, data|
          data = Serializer.instance.unmarshal(data)
          keytable = agent.manifest.command.namespaces[data[:namespace]]
          next unless keytable
          
          EventRouter.emit('mq_command/request_received', agent.agent_id, data)

          begin
            ret = keytable.dispatch(data[:command], data[:args])
          rescue Exception => e
            logger.error(e)
            ret = e
          ensure
            header.ack

            if ret.is_a? Exception
              msg = {:type => :error, :body=>{:message=> e.message, :error_type => e.class.to_s}}
            else
              msg = {:type=> :success, :body => ret}
            end
            agent.amq.queue(header.reply_to).publish(Serializer.instance.marshal(msg),
                                                     {:key=>header.reply_to,
                                                       :message_id=>header.message_id}
                                                     )
            EventRouter.emit('mq_command/response_sent', agent.agent_id, msg)
          end
        }
      end

      def unregister_namespace(namespace)
        agent.amq.queue(provider_queue_name(namespace), {:exclusive=>true}).delete
      end

      def provider_queue_name(ns)
        "command-provider.#{ns}"
      end
      
      class AsyncRequestContext < OpenStruct
        attr_reader :error_cb, :success_cb
        attr_accessor :timer

        def initialize(namespace, command, args)
          super({:request=>{
                    :namespace=> namespace,
                    :command => command,
                    :args => args
                  }.freeze,
                  :ticket => Util.gen_id,
                  :timeout_sec => 0.0 
                })
          
          @success_cb = nil
          @error_cb = nil
          @timer = nil

          @stm = Statemachine.build {
            trans :init, :on_ready, :ready
            trans :ready, :on_sent, :waiting
            trans :waiting, :on_received, :done
          }
          @stm.context = self
        end

        def state
          @stm.state
        end

        def process_event(ev, *args)
          @stm.process_event(ev, *args)
        end

        def hash
          @table.dup.merge({:state=>self.state})
        end

        def on_success=(cb)
          raise ArgumentError unless cb.is_a? Proc
          @success_cb = cb
        end

        def on_error=(cb)
          raise ArgumentError unless cb.is_a? Proc
          @error_cb = cb
        end

        def on_success(&blk)
          raise ArgumentError unless blk
          @success_cb = blk
        end

        def on_error(&blk)
          raise ArgumentError unless blk
          @error_cb = blk
        end
      end

    end
  end
end
