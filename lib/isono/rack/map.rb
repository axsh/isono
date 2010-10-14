# -*- coding: utf-8 -*-


module Isono
  module Rack
    class Map
      def self.build(&blk)
        n = self.new
        blk.call(n)
        n
      end
      
      def initialize(&blk)
        @table = {}
        instance_eval(&blk) if blk
      end

      # @example
      #  map :xxxx do
      #    response.response('xxxxx')
      #  end
      # @example
      #   map :xxxx, A.new do
      #     puts self # A.new
      #   end
      # @example
      #   map :xxxx, App.new
      def map(command, app=nil, &blk)
        command = command.to_s
        
        if app && blk
          @table[command]=Rack::Proc.new(app, &blk)
        elsif app && !blk
          raise TypeError unless app.respond_to?(:call)
          @table[command]=app
        elsif !app && blk
          @table[command]=Rack::Proc.new(&blk)
        else
          raise ArgumentError
        end
        self
      end
      
      def default(&blk)
        map('', blk)
      end
      
      def call(req, res)
        mapped_app = @table[req.command.to_s] || @table['']
        raise UnknownMethodError if mapped_app.nil?
        
        mapped_app.call(req, res)
      end
    end
  end
end
