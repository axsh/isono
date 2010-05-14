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
        
        @timer = Util::CheckerTimer.new(config_section.heartbeat_offset_time) {
          agent.publish_to('heartbeat', {:agent_id=>agent.agent_id, :boot_token=>agent.boot_token})
        }
        @timer.start
        agent.publish_to('heartbeat', {:agent_id=>agent.agent_id, :boot_token=>agent.boot_token})
      end
      
      def on_terminate
        @timer.stop
      end
    end
  end
end
