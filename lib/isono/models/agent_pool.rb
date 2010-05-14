# -*- coding: utf-8 -*-

require 'statemachine'

module Isono
  module Models
    class AgentPool < Sequel::Model
      include Logger
      plugin :schema
      plugin :hook_class_methods

      set_schema {
        primary_key :id, :type => Integer, :auto_increment=>true, :unsigned=>true
        column :agent_id, :varchar, :size=>80, :null=>false
        column :boot_token, :varchar, :size=>10, :null=>false
        column :status, :varchar, :size=>10
        column :created_at, :datetime, :null=>false
        column :updated_at, :datetime, :null=>false
        column :last_ping_at, :datetime, :null=>false
        index [:agent_id, :boot_token], {:unique=>true}
      }

      before_create(:set_created_at) do
        self.updated_at = self.created_at = Time.now
      end
      before_update(:set_updated_at) do
        self.updated_at = Time.now
      end

      def state_machine
        model = self
        st = Statemachine.build do
          startstate :init
          trans :init,    :on_ping,      :online
          trans :online,  :on_timeout,   :timeout
          trans :timeout, :on_ping,      :online
          trans :online,  :on_unmonitor, :offline
          trans :timeout, :on_unmonitor, :offline
          # do nothing on transition from and to the same state
          trans :online,  :on_ping,      :online 
          trans :timeout, :on_timeout,   :timeout

          on_entry_of :online, proc {
            model.status = :online
            model.logger.debug("become online: #{model.agent_id}-#{model.boot_token}")
          }
          on_entry_of :timeout, proc {
            model.status = :timeout
            model.logger.debug("become timeout: #{model.agent_id}-#{model.boot_token}")
          }
          on_entry_of :offline, proc {
            model.status = :offline
            model.logger.debug("becomes offline: #{model.agent_id}-#{model.boot_token}")
          }
        end

#         {:online => proc {
#             self.status = :online
#             EventRouter.publish(:agent_online, self.agent_id)
#           },
#           :timeout => proc{
#             self.status = :timeout
#             EventRouter.publish(:agent_timedout, self.agent_id)
#           },
#           :offline => proc{
#             self.status = :offline
#             EventRouter.publish(:agent_offline, self.agent_id)
#           }
#         }.each { |k, v|
#           st.states[k].entry_action = v
#         }
        
        if self[:status]
          if st.has_state(self[:status].to_sym)
            st.state = self[:status].to_sym
          else
            raise "Unknown state: #{self[:status]}"
          end
        else
          st.reset
        end
        st
      end

    end
  end
end
