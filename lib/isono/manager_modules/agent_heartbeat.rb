# -*- coding: utf-8 -*-

module Isono
  module ManagerModules
    class AgentHeartbeat < Base

      config_section do |c|
        desc "second(s) to wait until send the next heartbeat signal"
        heartbeat_offset_time 10
      end

      def on_init(args)
        agent.amq.fanout('heartbeat', {:auto_delete=>true})
        
        @timer = EventMachine::PeriodicTimer.new(config_section.heartbeat_offset_time.to_f) {
          agent.publish_to('heartbeat', {:agent_id=>agent.agent_id, :boot_token=>agent.boot_token})
        }
        agent.publish_to('heartbeat', {:agent_id=>agent.agent_id, :boot_token=>agent.boot_token})
      end
      
      def on_terminate
        @timer.cancel
      end
    end
  end
end
