# -*- coding: utf-8 -*-

module Isono
module Rack
  class ObjectMethod
    include Logger
    
    def initialize(obj)
      @obj = obj
    end
    
    def call(req, res)
      m = @obj.method(req.command)
      raise UnknownMethodError, "#{req.command}" if m.nil?
      res.response(m.arity.abs > 0 ? m.call(*req.args) : m.call)
    end
    
  end
end
end
