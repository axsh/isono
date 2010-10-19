# -*- coding: utf-8 -*-

module Isono
module Rack
  class RpcError < RuntimeError; end
  class UnknownMethodError < RpcError; end
  class ResponseIncompleteError < RpcError; end
  
  class << self
    def build(&blk)
      Builder.new(&blk)
    end
  end
  
  class Decorator
    attr_reader :app
    
    def initialize(app)
      raise TypeError unless app.respond_to?(:call)
      @app = app
      
      set_instance_logger(@app.class.to_s) if self.respond_to? :set_instance_logger
    end
    
    def call(req, res)
      app.call(req, res)
    end
  end

  class Request
    attr_reader :r
    
    def initialize(request_hash)
      @r = request_hash
    end
    
    def command() @r[:command]; end
    alias :key :command
    def args() @r[:args]; end
    def sender() @r[:sender]; end
    def message_id() @r[:message_id]; end
  end

  class Response
    attr_reader :ctx
    
    # @param [NodeModules::RpcChannel::ResponseContext] ctx
    def initialize(ctx)
      raise TypeError unless ctx.is_a?(NodeModules::RpcChannel::ResponseContext)
      @ctx = ctx
    end

    def responded?
      @ctx.responded?
    end

    def progress(msg)
      @ctx.progress(msg)
    end

    def response(msg)
      @ctx.response(msg)
    end
    
  end
end  
end
