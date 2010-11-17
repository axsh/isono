# -*- coding: utf-8 -*-

module Isono
module Rack
  class ThreadPass < Decorator
    include Logger
    
    def call(req, res)
      ::Thread.new {
        begin
          app.call(req, res)
        rescue Exception => e
          logger.error(e)
          res.response(e) unless res.responded?
        else
          raise ResponseIncompleteError unless res.responded?
        end
      }
    end
  end
end
end
