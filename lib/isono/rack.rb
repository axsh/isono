# -*- coding: utf-8 -*-

module Isono::Rack
  class RpcError < RuntimeError; end
  class UnknownMethodError < RpcError; end
  class ResponseIncompleteError < RpcError; end
  
  class << self
    def build(&blk)
      Builder.new.instance_eval &blk
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
    def initialize(request_hash)
      @r = request_hash
    end
    
    def command() @r[:command]; end
    alias :key :command
    def args() @r[:args]; end
  end
  
end
