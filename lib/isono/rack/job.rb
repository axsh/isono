# -*- coding: utf-8 -*-

module Isono
module Rack
  class Job < Decorator
    include Logger

    class NullResponse < NodeModules::RpcChannel::ResponseContext
      def progress(ret)
      end

      def response(ret)
      end
    end

    
    def initialize(app, job_worker)
      super(app)
      @job_worker = job_worker
    end
    
    def call(req, res)
      orig_res = res
      case req.r[:job_request_type]
      when :submit
        res = NullResponse.new(res.node, res.header)
      end
      
      job = @job_worker.run(req.r[:parent_job_id]){
        begin
          app.call(req, res)
          
          res.response(1) unless res.responded?
        rescue Exception => e
          logger.error(e)
          res.response(e)
        end
      }

      case req.r[:job_request_type]
      when :submit
        orig_res.response(job.to_hash)
      else
        res.progress(job.to_hash)
      end
    end
  end
end
end
