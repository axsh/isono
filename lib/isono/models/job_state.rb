# -*- coding: utf-8 -*-

require 'sequel/model'

module Isono
  module Models
    class JobState < Sequel::Model
      include Logger
      plugin :schema
      plugin :hook_class_methods

      set_schema {
        primary_key :id, :type => Integer, :auto_increment=>true, :unsigned=>true
        column :job_id, :varchar, :size=>80, :null=>false
        column :parent_job_id, :varchar, :size=>80, :null=>true
        column :session_id, :varchar, :size=>80, :null=>true
        column :node_id, :varchar, :size=>80, :null=>false
        column :state, :varchar, :size=>10, :null=>false
        column :message, :text, :null=>false, :default=>''
        column :job_name, :varchar, :size=>255, :null=>false, :default=>''
        column :created_at, :datetime, :null=>false
        column :updated_at, :datetime, :null=>false
        column :started_at, :datetime, :null=>true
        column :finished_at, :datetime, :null=>true
        index :job_id, {:unique=>true}
      }

      before_create(:set_created_at) do
        self.created_at = self.updated_at= Time.now
      end
      before_update(:set_updated_at) do
        self.updated_at= Time.now
      end

    end
  end
end
