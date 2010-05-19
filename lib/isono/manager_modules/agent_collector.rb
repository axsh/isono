# -*- coding: utf-8 -*-

module Isono
  module ManagerModules
    class AgentCollector < Base
      include Logger

      config_section do
        desc "time in second to recognize if the agent is timed out"
        timeout_sec (60*20).to_f
        desc "the agent to be killed from the datasource after the time of second"
        kill_sec (60*20*2).to_f
        desc ""
        gc_period 20.0
      end

      def on_init(args)
        # GC event trigger for agent timer & status
        @gc_timer = EM::PeriodicTimer.new(config_section.gc_period) {
          DataStore.pass {
            # Sqlite3 is unlikely to modify table while iterating
            # the result set. the following is the case of the
            # iteration for the opened result set.
            # Models::AgentPool.dataset.each { |row|
            # 
            # while Model.dataset.all, it returns a Ruby array
            # containing rows so that i had no table lock exception.
            # see:
            # http://www.mail-archive.com/sqlite-users@sqlite.org/msg03328.html
            # TODO: paging support for the large result set.
            Models::AgentPool.dataset.all.each { |row|
              sm = row.state_machine
              next if sm.state == :offline

              diff_time = Time.now - row[:last_ping_at]
              if sm.state != :timeout && diff_time > config_section.timeout_sec
                sm.on_timeout
                row.save_changes
                EventRouter.emit('agent_collector/timedout', agent.agent_id, row.hash)
              end
              
              if diff_time > config_section.kill_sec
                sm.on_unmonitor

                EventRouter.emit('agent_collector/killed', agent.agent_id, row.hash)
                row.delete
              end
            }
          }
        }
 
        agent.amq.fanout('heartbeat')
        agent.define_queue("hertbeat.#{agent.agent_id}", 'heartbeat', {:exclusive=>true}) { |data|
          data = Serializer.instance.unmarshal(data)
          DataStore.pass {
            # find_or_create did work well...
            a = (Models::AgentPool.find(:agent_id=>data[:agent_id], :boot_token=>data[:boot_token]) ||
                 Models::AgentPool.new(:agent_id=>data[:agent_id],
                                       :boot_token=>data[:boot_token]))
            a.state_machine.on_ping
            a[:last_ping_at] = Time.now
            if a.new?
              a.save
              EventRouter.emit('agent_collector/monitored', agent.agent_id, a.hash)
            else
              a.save_changes
              EventRouter.emit('agent_collector/pong', agent.agent_id, a.hash)
            end
          }
        }
      end
      

      def on_terminate
        @agent_timeout_timer.cancel
      end

    end
  end
end
