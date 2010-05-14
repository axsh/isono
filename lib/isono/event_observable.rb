# -*- coding: utf-8 -*-

module Isono
  # Add event handling support to the arbitrary class.
  # TODO: make it thread safe.
  module EventObservable
    class Timeout
    end
    
    def fire_event(evtype, *args)
      if logger && @debug_event
        logger.debug("fire_event(#{evtype}, #{args.nil? ? 'nil' : args.inspect})")
      end
      begin
        on_event_fired(evtype, *args)
      rescue => e
        if logger
          logger.error(e)
        else
          puts e
        end
      end
      return unless @tickets[evtype]

      deleted_tickets = []
      @tickets[evtype].each { |ticket|
        h = @handlers[ticket]
        if h
          begin
            h.call(*args)
          rescue Exception => e
            logger.error("caught exception: #{ticket}, proc=#{h.to_s}: #{e.to_s}")
            logger.error(e)
          end
        else
          deleted_tickets << ticket
        end
      }

      @tickets[evtype] -= deleted_tickets
    end

    def add_observer(evtype, &blk)
      ticket = Util.gen_id
      @handlers[ticket] = blk
      (@tickets[evtype] ||= []) << ticket
      ticket
    end

    def add_observer_once(evtype, timeout=0, &blk)
      ticket = add_observer(evtype) { |*args|
        begin
          blk.call(*args)
        ensure
          remove_observer(ticket)
        end
      }

      if timeout > 0
        EM.add_timer(timeout) {
          if @handlers.has_key? ticket
            blk.call(Timeout.new)
            remove_observer(ticket)
          end
        }
      end
      
      ticket
    end

    def remove_observer(ticket)
      @handlers.delete(ticket)
    end

    protected
    def initialize_event_observable
      @tickets = {}
      @handlers = {}
      @debug_event = false
    end


    def on_event_fired(evtype, *args)
    end
  end
end
