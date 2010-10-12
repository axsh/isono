# -*- coding: utf-8 -*-

module Isono
module Rack
  class Proc
    include Logger

    def self.build(opts={}, &blk)
      n = self.new(opts)
      blk.call(n)
      n
    end
    
    def initialize(opts={}, &blk)
      @table = {}
      @opts = {:extract_args=>false}.merge(opts)
      default(&blk) if blk
    end
    
    def command(key, &blk)
      @table[key.to_s] = blk
      self
    end

    def default(&blk)
      @table[''] = blk
      self
    end

    def call(req, res)
      d = @table[req.command.to_s] || @table['']
      if d
        if @opts[:extract_args]
          res.response(d.call(*req.args))
        else
          Thread.current["#{self.class.to_s}/request"] = req
          Thread.current["#{self.class.to_s}/response"] = res
          begin
            # handle response in the block
            instance_eval(&d)
            # send empty message back to client if the response is not handled in block.
            res.response(nil) unless res.responded?
          ensure
            Thread.current["#{self.class.to_s}/request"] = nil
            Thread.current["#{self.class.to_s}/response"] = nil
          end
        end
      else
        raise UnknownMethodError, "#{req.command}"
      end
        
    end

    protected
    def request
      Thread.current["#{self.class.to_s}/request"]
    end

    def response
      Thread.current["#{self.class.to_s}/response"]
    end
  end
end
end
