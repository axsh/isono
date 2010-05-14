# -*- coding: utf-8 -*-

require 'statemachine'

module Isono
  # Catch all the event from the Statemachine and delegate.
  class EventDelegateContext
    include EventObservable
    include Logger
    
    def initialize(stm)
      raise ArgumentError unless stm.is_a? Statemachine::Statemachine
      initialize_event_observable
      @stm = stm
      @stm.context = self
      inject_event_handlers
    end

    protected
    def on_event_fired(evtype, *args)
      logger.debug("#{evtype}")
    end
    
    private
    # analyze the current statemachine object and inject
    # event handlers where the stm can trigger the events:
    # - all entry/exit events from/to each state.
    # - transition events
    def inject_event_handlers
      states = @stm.instance_variable_get(:@states)
      states.each { |k, st|
        prev = st.entry_action
        st.entry_action = proc { |*args|
          on_entry_state(st.id, *args)
        }
        prev = st.exit_action
        st.exit_action = proc { |*args|
          on_exit_state(st.id, *args)
        }
      }
    end
    
    def on_entry_state(state, *args)
      evname = "on_entry_of_#{state}"
      fire_event(:on_entry_state, {:evname=>evname.to_sym, :args=>args})
      fire_event(evname.to_sym, args)
    end

    def on_exit_state(state, *args)
      evname = "on_exit_of_#{state}"
      fire_event(:on_exit_state, {:evname=>evname.to_sym, :args=>args})
      fire_event(evname.to_sym, args)
    end
    
  end
end
