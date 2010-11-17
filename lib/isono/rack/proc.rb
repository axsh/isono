# -*- coding: utf-8 -*-

module Isono
module Rack
  class Proc
    include Logger

    THREAD_LOCAL_KEY=self.to_s
    
    attr_accessor :context
    
    def initialize(context=nil, opts={}, &blk)
      @context = context || Object.new
      @blk = blk
    end
    
    def call(req, res)
      Thread.current["#{THREAD_LOCAL_KEY}/request"] = req
      Thread.current["#{THREAD_LOCAL_KEY}/response"] = res
      begin
        # create per-request context object from original.
        c = @context.dup
        c.extend InjectMethods
        begin
          c.instance_eval(&@blk)
          # send empty message back to client if the response is not handled in block.
          res.response(nil) unless res.responded?
        rescue ::Exception => e
          res.response(e)
          raise e
        end
      ensure
        Thread.current["#{THREAD_LOCAL_KEY}/request"] = nil
        Thread.current["#{THREAD_LOCAL_KEY}/response"] = nil
      end
    end

    module InjectMethods
      def request
        Thread.current["#{THREAD_LOCAL_KEY}/request"]
      end
      
      def response
        Thread.current["#{THREAD_LOCAL_KEY}/response"]
      end
    end
    
  end
end
end
