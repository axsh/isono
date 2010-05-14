# -*- coding: utf-8 -*-

require 'digest/sha1'
require 'hmac-sha1'

module Isono
  module Util
    def gen_id(str=nil)
      Digest::SHA1.hexdigest( (str.nil? ? rand.to_s : str) )
    end
    module_function :gen_id

    class CheckerTimer < EventMachine::PeriodicTimer
      def initialize(time, &blk)
        @interval = time
        @code = proc {
          begin
            blk.call
          rescue => e
            Wakame.log.error(e)
          end
        }
        stop
      end

      def start
        if !running?
          @cancelled = false
          schedule
        end
      end

      def stop
        @cancelled = true
      end

      def running?
        !@cancelled
      end

    end
     
  end
end

