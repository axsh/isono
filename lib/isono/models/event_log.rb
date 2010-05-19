# -*- coding: utf-8 -*-

module Isono
  module Models
    class EventLog < Sequel::Model
      include Logger
      plugin :schema
      plugin :hook_class_methods

      set_schema {
        primary_key :id, :type => Integer, :auto_increment=>true, :unsigned=>true
        column :event, :varchar, :size=>80, :null=>false
        column :sender, :varchar, :size=>80, :null=>false
        column :message, :text, :null=>false
        column :publised_at, :datetime, :null=>false
        column :created_at, :datetime, :null=>false
        #index [:agent_id, :boot_token], {:unique=>true}
      }

      before_create(:set_created_at) do
        self.created_at = Time.now
      end
      before_update(:set_updated_at) do
      end

    end
  end
end
