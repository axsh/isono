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
      def after_initialize
        self[:state] = :init
      end
      
      def process_event(ev, *args)
        case [ev, self.state]
        when [:on_ping, :init]
          self.state = :online
          self.last_ping_at = Time.now
        when [:on_ping, :timeout]
          self.state = :online
          self.last_ping_at = Time.now
        when [:on_ping, :online]
          self.state = :online
          self.last_ping_at = Time.now
        when [:on_unmonitor, :online]
          self.state = :offline
        when [:on_unmonitor, :timeout]
          self.state = :offline
        when [:on_timeout, :online]
          self.state = :timeout
        when [:on_timeout, :timeout]
          self.state = :timeout
        else
          raise "Unknown state transition: #{ev}, #{self.state}"
        end
      end

    end
  end
end
