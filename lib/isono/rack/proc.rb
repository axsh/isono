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
      dup.__send__(:_call, req, res)
    end

    private
    def _call(req, res)
      Thread.current["#{THREAD_LOCAL_KEY}/request"] = req
      Thread.current["#{THREAD_LOCAL_KEY}/response"] = res
      begin
        # handle response in the block
        @context.extend InjectMethods
        @context.instance_eval(&@blk)
        # send empty message back to client if the response is not handled in block.
        res.response(nil) unless res.responded?
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
