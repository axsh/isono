# -*- coding: utf-8 -*-

module Isono
module Rack
  class Job < Decorator
    include Logger

    # Response class for nothing response.
    # It is used when the job request type is :submit.
    class NullResponse < Response
      def progress(ret)
      end

      def response(ret)
      end
    end

    class JobResponse < Response
      # @param [NodeModules::RpcChannel::ResponseContext] ctx
      # @param [NodeModules::JobWorker::JobContext] jobctx
      def initialize(ctx, jobctx)
        super(ctx)
        @job = jobctx
      end

      # Register call back which called on the job failure. 
      def fail_cb(&blk)
        @job.fail_cb = blk
      end
    end

    class JobRequest < Request
      # @param [Hash] request_hash
      # @param [NodeModules::JobWorker::JobContext] jobctx
      def initialize(request_hash, jobctx)
        @job = jobctx
        @r = request_hash
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
        res = NullResponse.new(res.ctx)
      end
      
      job = @job_worker.run(req.r[:parent_job_id]){
        @app.call(JobRequest.new(req.r, job), JobResponse.new(res.ctx, job))
          
        res.response(nil) unless res.responded?
      }

      case req.r[:job_request_type]
      when :submit
        orig_res.response(job.to_hash)
      else
        # send job context info back at the first progress message.
        # following progress messages to be handled as usual.
        res.progress(job.to_hash)
      end
    end
  end
end
end
