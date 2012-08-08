# -*- coding: utf-8 -*-

require 'sequel'

module Isono
module Rack
  # Middleware for Sequel transaction.
  class Sequel < Decorator
    include Isono::Logger
    
    def initialize(app, retry_count=10)
      @app = app
      @retry_count = retry_count
    end
    
    def call(req, res)
      retry_count=0
      begin
        ::Sequel::DATABASES.first.transaction do
          @app.call(req, res)
          res.response(ret) unless res.responded?
        end
      rescue ::Sequel::DatabaseError, ::Sequel::DatabaseConnectionError => e
        retry_count += 1
        if retry_count < @retry_count
          logger.error("Database Error: #{e.message} retrying #{retry_count}/#{@retry_count}")
          retry
        end
        
        res.response(e) unless res.responded?
        raise e
      end
    end
  end
end
end
