# -*- coding: utf-8 -*-

require 'isono'

module Isono
  module ManagerModules
    class ResourceInstance < Base
      include Logger

      config_section do
        desc "Instance ref of resource.manifest file"
        resource_manifest nil
        rake_bin_path nil
      end

      attr_reader :state_monitor, :monitors
      
      def on_init(args)
        @thread_pool = ThreadPool.new(1, self.class.to_s)
        @event_handler_holder = {}

        if config_section.resource_manifest.nil?
          raise "resource manifest object is not given. please to check the path for resource.manifest."
        end
        
        @manifest = config_section.resource_manifest
        load
      end

      def on_terminate
        unload
      end

      
      def state
        @manifest.stm.state
      end

      def load
        @manifest.load_path.each { |path|
          $LOAD_PATH.unshift path
        }
        
        @manifest.monitors.each { |mon|
        }
        
        if @manifest.state_monitor
          @state_monitor = @manifest.state_monitor.new
        end
        
        edc = EventDelegateContext.new(@manifest.stm)
        # common event handlers
        edc.add_observer(:on_entry_state) { |state, arg|
          fire_event(:resource_state_changed, common_args({:state=>state, :args=>arg}))
        }
        edc.add_observer(:on_exit_state) { |arg|
          unsubscribe_event_all
          # clear the queued tasks when the state changed.
          @thread_pool.clear
        }
        
        @manifest.entry_state.each { |state, sec|
          key = "on_entry_of_#{state}".to_sym

          if sec.task
            edc.add_observer(key) { |args|
              @thread_pool.pass {
                sec.task.call(self)
              }
            }
          end
        }
        
        @manifest.exit_state.each { |state, sec|
          key = "on_exit_of_#{state}".to_sym
          edc.add_observer(key, &blk)
        }
        
        @manifest.stm.process_event(:on_load)
        fire_event(:resource_loaded, common_args())
      end
      
      def unload
        fire_event(:resource_unloaded, common_args())
      end
      
      private
      def common_args(hash={})
        {:resource_uuid=>agent.agent_id, :resource_type=>@manifest.name}.merge(hash)
      end
      
      def subscribe_event(evname, sender, &blk)
        ticket = Util.gen_id
        @event_handler_holder[ticket] = {:evname=>evname, :sender=>sender}
        EventChannel.instance.subscribe(evname, "#{@manifest.resource_type}-#{agent.agent_id}", sender, &blk)
        ticket
      end
      
      def unsubscribe_event(ticket)
        ev = @event_handler_holder.delete(ticket)
        return unless ev
        EventChannel.instance.unsubscribe(ev[:evname], "#{@manifest.resource_type}-#{agent.agent_id}")
      end
      
      def unsubscribe_event_all
        EventMachine.schedule  {
          @event_handler_holder.keys.each { |ticket|
            unsubscribe_event(ticket)
          }
        }
      end



    end
  end
end
