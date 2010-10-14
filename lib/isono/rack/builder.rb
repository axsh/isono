# -*- coding: utf-8 -*-

module Isono
module Rack
  class Builder
    def initialize(&blk)
      @filters = []
      @app = Map.new
      instance_eval(&blk) if blk
    end
    
    def use(decorator_class, *args)
      raise TypeError unless decorator_class < Decorator
      @filters << lambda {|disp| decorator_class.new(disp, *args) }
    end
    
    def run(app)
      raise TypeError unless app.respond_to?(:call)
      @app.map('', app)
    end

    def map(command, app=nil, &blk)
      raise ArgumentError if app && blk
      if app
        raise TypeError unless app.respond_to?(:call)
        @app.map(command, app)
      elsif blk
        @app.map(command, self.class.new(&blk))
      else
        raise ArgumentError
      end
    end

    def call(req, res)
      raise "main app is not set" if @app.nil?
      @filters.reverse.inject(@app) {|d, f| f.call(d) }.call(req, res)
    end
  end
end
end
