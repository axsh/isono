# -*- coding: utf-8 -*-

module Isono
module Rack
  # Runs app.call() in the thread context of DataStore's worker.
  class DataStore < Decorator
    def call(req, res)
      NodeModules::DataStore.pass {
        begin
          ret = @app.call(req, res)
          res.response(ret) unless res.responded?
        rescue ::Exception => e
          res.response(e)
          raise e
        end
      }
    end
  end
end
end
