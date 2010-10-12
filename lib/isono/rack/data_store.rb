# -*- coding: utf-8 -*-

module Isono::Rack
  # Runs app.call() in the thread context of DataStore's worker.
  class DataStore < Decorator
    def call(req, res)
      NodeModules::DataStore.pass {
        @app.call(req, res)
      }
    end
  end
end
