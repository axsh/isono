# -*- coding: utf-8 -*-

module Isono
module Rack
  class ObjectMethod
    include Logger
    
    def initialize(obj, opts={})
      @obj = obj
      @opts = {:extract_args=>false}.merge(opts)
    end
    
    def call(req, res)
      @request = req
      @response = res
      begin
        m = @obj.method(req.key)
        raise UnknownMethodError, "#{req.key}" if m.nil?
        if @opts[:extract_args]
          ret = m.arity > 0 ? m.call(*res.args) : m.call
          res.response(ret)
        else
          m.call
          raise ResponseIncompleteError unless res.responded?
        end
      ensure
        @request = @response = nil
      end
    end
    
  end
end
end
