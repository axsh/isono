# -*- coding: utf-8 -*-

module Isono
module Rack
  class Job < Decorator
    include Logger

    class JobResponse < Response
      attr_reader :job

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

      # Job may run in asynchronous mode. So response() should not
      # raise error even when it is called multiple times during session.
      def response(msg)
        if responded?
          Job.logger.info("Defered response message from #{@job.job_id}: #{msg}")
        else
          super(msg)
        end
      end
    end

    class JobRequest < Request
      attr_reader :job
      
      # @param [Hash] request_hash
      # @param [NodeModules::JobWorker::JobContext] jobctx
      def initialize(request_hash, jobctx)
        @job = jobctx
        @r = request_hash
      end
    end
    
    def initialize(app, job_worker)
      super(app)
      raise ArgumentError unless job_worker.respond_to?(:start)
      @job_worker = job_worker
    end
    
    def call(req, res)
      job = @job_worker.start do |job|
        job.job_id = req.r[:job_id]
        job.parent_job_id = req.r[:parent_job_id]
        job.session_id = req.r[:session_id]
        job.job_name = req.r[:job_name]
        job.run_cb = proc {
          begin
            @app.call(JobRequest.new(req.r, job), JobResponse.new(res.ctx, job))
            res.response(nil) unless res.responded?
          rescue Exception => e
            res.response(e) unless res.responded?
            raise e
          end
        }
      end

      # send the new job context info back as the first progress message.
      # the progress messages that follow will be handled as usual.
      res.progress(job.to_hash)
    end
  end
end
end
