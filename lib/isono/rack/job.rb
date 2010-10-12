# -*- coding: utf-8 -*-

module Isono::Rack
  class Job < Decorator
    include Logger
    
    def initialize(app, job_worker)
      super(app)
      @job_worker = job_worker
    end
    
    def call(req, res)
      job = @job_worker.run(){
        begin
          app.call(res, req)
          
          res.response(1) unless res.responded?
        ensure
        end
      }
      res.progress({:job_id=>job.job_id})
    end
  end
end
