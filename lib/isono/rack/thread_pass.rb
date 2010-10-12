# -*- coding: utf-8 -*-

module Isono::Rack
  class ThreadPass < Decorator
    include Logger
    
    def call(req, res)
      ::Thread.new {
        begin
          app.call(req, res)
        rescue Exception => e
          logger.error(e)
          res.response(e)
        else
          raise RsponseIncompleteError unless res.responded?
        end
      }
    end
  end      
end
