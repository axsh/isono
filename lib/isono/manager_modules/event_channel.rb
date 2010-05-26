# -*- coding: utf-8 -*-

module Isono
  module ManagerModules
    # Setup mq based event dispatch channels.
    # It prepares a single point topic exchange which receives all the
    # events from publishers. The event consumers setup queues
    # respectively to bound to the exchange. The most of queues
    # have the key string which filters the event. The event publisher
    # puts the key when it sends each new event.
    # 
    # The key consists of two parts with dot separated:
    # event type and the event sender (ie. "event1.sender1").
    # The event publisher can put any format of data into the message
    # body part.
    # 
    # These rules make the message queue broker to work as the event
    # dispacher.
    class EventChannel < Base
      def on_init(args)
        # it creates the event receiver exchange in synchronous
        # mode.
        agent.amq.topic('event', {:nowait=>false})
        agent.amq.direct('event_direct', {:nowait=>false})
      end

      def on_terminate
      end

      def publish(evname, sender=nil, message=nil)
        sender ||= agent.agent_id
        body = {
          :event => evname,
          :published_at=> Time.now,
          :sender  => sender,
          :origin_agent  => agent.agent_id,
          :message => message
        }
        
        EventMachine.schedule {
          agent.amq.exchanges['event'].publish(Serializer.instance.marshal(body), {:key=>"#{evname}.#{sender}"})
        }
      end
      
      def subscribe(evname, sender, receiver_id=agent.agent_id, &blk)
        agent.define_queue("#{evname}-#{receiver_id}", 'event',
                           {:exclusive=>true, :key=>"#{evname}.#{sender}"}) { |data|
          data = Serializer.instance.unmarshal(data)
          case blk.arity
          when 2
            m = data.delete(:message)
            blk.call(data, m)
          when 1
            blk.call(data[:message])
          end
        }
      end

      def unsubscribe(evname, receiver_id=agent.agent_id)
        EventMachine.schedule {
          q = agent.amq.queue("#{evname}-#{receiver_id}")
          q.unsubscribe
        }
      end

    end
  end
end
