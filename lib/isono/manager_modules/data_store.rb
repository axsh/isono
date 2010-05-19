# -*- coding: utf-8 -*-

require 'sequel'

module Isono
  module ManagerModules
    class DataStore < Base
      include Logger

      config_section do
        desc ""
        database_dsn ''
      end
      
      def self.pass(&blk)
        instance.db_writer_thread.pass {
          instance.db.transaction {
            blk.call
          }
        }
      end

      def self.barrier(&blk)
        instance.db_writer_thread.barrier {
          instance.db.transaction {
            blk.call
          }
        }
      end

      attr_reader :db_writer_thread, :db
      
      def on_init(args)
        @db_writer_thread = ThreadPool.new(1)

        @db_writer_thread.barrier {
          #@db = Sequel.connect(config_section.database_dsn, {:logger=>logger})
          @db = Sequel.connect(config_section.database_dsn)
          logger.debug("connected to the database: #{config_section.database_dsn}, #{@db}")
        }
      end
      
      def on_terminate
        @db_writer_thread.shutdown
        @db.disconnect
      end
      
    end
  end
end
