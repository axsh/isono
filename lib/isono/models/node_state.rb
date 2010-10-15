# -*- coding: utf-8 -*-

require 'sequel/model'
require 'statemachine'

module Isono
  module Models
    class NodeState < Sequel::Model
      include Logger
      plugin :schema
      plugin :hook_class_methods

      set_schema {
        primary_key :id, :type => Integer, :auto_increment=>true, :unsigned=>true
        column :node_id, :varchar, :size=>80, :null=>false
        column :boot_token, :varchar, :size=>10, :null=>false
        column :state, :varchar, :size=>10
        column :created_at, :datetime, :null=>false
        column :updated_at, :datetime, :null=>false
        column :last_ping_at, :datetime, :null=>false
        index :node_id, {:unique=>true}
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
          trans :init,    :on_ping,      :online, proc {model.last_ping_at = Time.now}
          trans :online,  :on_timeout,   :timeout
          trans :timeout, :on_ping,      :online, proc {model.last_ping_at = Time.now}
          trans :online,  :on_unmonitor, :offline
          trans :timeout, :on_unmonitor, :offline
          # do nothing on transition from and to the same state
          trans :online,  :on_ping,      :online, proc {model.last_ping_at = Time.now}
          trans :timeout, :on_timeout,   :timeout

          on_entry_of :online, proc {
            model.state = :online
          }
          on_entry_of :timeout, proc {
            model.state = :timeout
          }
          on_entry_of :offline, proc {
            model.state = :offline
          }
        end

        if self[:state]
          if st.has_state(self[:state].to_sym)
            st.state = self[:state].to_sym
          else
            raise "Unknown state: #{self[:state]}"
          end
        else
          st.reset
        end
        st
      end

    end
  end
end
