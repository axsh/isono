# -*- coding: utf-8 -*-

module Isono
  module ManagerModules
    class EventLogger < Base
      def on_init(args)
        agent.amq.topic('event')

        agent.define_queue("event-logger.#{agent.agent_id}", 'event', {:key=>'*.*', :exclusive=>true}) { |data|
        #agent.amq.queue("event-logger.#{agent.agent_id}", {:exclusive=>true}).bind('event', {:key=>'*.*'}).subscribe { |data|
          data = Serializer.instance.unmarshal(data)
          next unless filter_event(data)
          
          DataStore.pass {
            Models::EventLog.create(:event=>data[:event],
                                    :sender=>data[:sender],
                                    :message=>data[:message].inspect,
                                    :publised_at=>data[:published_at])
          }
        }
      end

      def on_terminate
        agent.amq.queue("event-logger.#{agent.agent_id}").delete
      end


      private
      def filter_event(data)
        case data[:event]
        when 'agent_collector/pong'
          return false
        end
        return true
      end
      
    end
  end
end
