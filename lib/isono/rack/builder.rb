# -*- coding: utf-8 -*-

module Isono::Rack
  class Builder
    def initialize
      @filters = []
    end
    
    def use(decorator_class, *args)
      raise TypeError unless decorator_class < Decorator
      @filters << lambda {|disp| decorator_class.new(disp, *args) }
    end
    
    def run(app)
      @app = app
    end
    
    def call(req, res)
      raise "main app is not set" if @app.nil?
      @filters.reverse.inject(@app) {|d, f| f.call(d) }.call(req, res)
    end
  end
end
