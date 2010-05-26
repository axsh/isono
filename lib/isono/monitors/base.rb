# -*- coding: utf-8 -*-

require 'ostruct'
require 'eventmachine'

module Isono
  module Monitors
    class Base < OpenStruct
      def initialize
        super()
        self.monitor_uuid = Util.gen_id
        self.create_at = Time.now
        self.start_at = nil
        self.last_check_at = nil
        self.interval = 10.0

        # do not involve status_changed event emittion.
        table[:status] = false
        @timer = nil
      end
      
      def start
        if @timer.nil?
          @timer = new_timer
          self.start_at = Time.now
          EventRouter.emit('monitor/started', self.to_hash)
        end
      end

      def stop
        @timer.cancel
        @timer = nil
        EventRouter.emit('monitor/stopped', self.to_hash)
      end

      def status=(s)
        if @table[:status] != s
          prev_stat = @table[:status]
          @table[:status] = s
          EventRouter.emit('monitor/status_changed',
                           self.to_hash.merge({:prev_status=>prev_stat}))
        end
      end

      def to_hash
        @table.merge({})
      end
      

      def check
      end


      private
      def new_timer
        timer = EventMachine::PeriodicTimer.new(self.interval) {
          EventMachine.defer {
            begin
              self.last_check_at = Time.now
              self.status = self.check
            rescue Exception =>  e
              logger.error(e)
            end
            
          }
        }
      end
    end
  end
end
