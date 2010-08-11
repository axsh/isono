# -*- coding: utf-8 -*-

require 'isono'

module Isono
  module ManagerModules
    class ResourceInstance < Base
      include Logger

      config_section do
        desc "Instance ref of resource.manifest file"
        resource_manifest nil
      end

      attr_reader :manifest
      
      def on_init(args)
        @thread_pool = ThreadPool.new(1, self.class.to_s)
        @event_handler_holder = {}

        if config_section.resource_manifest.nil?
          raise "resource manifest object is not given. please to check the path for resource.manifest."
        end

        # register the command provider of this RI.
        agent.manifest.command.register("ri.#{agent.agent_id}")
        
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
        edc = EventDelegateContext.new(@manifest.stm)
        # common event handlers
        edc.add_observer(:on_entry_state) { |state, arg|
          EventRouter.emit('resource_instance/state_changed', nil,
                           common_args({:state=>state, :args=>arg}))
        }
        edc.add_observer(:on_exit_state) { |arg|
          unsubscribe_event_all
          # clear the queued tasks when the state changed.
          @thread_pool.clear
          # clear the command hook for the current state.
          agent.manifest.command.namespaces["ri.#{agent.agent_id}"].table.clear
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

          unless sec.on_command.empty?
            edc.add_observer(key) { |args|
              sec.on_command.each { |k, v|
                agent.manifest.command.namespaces["ri.#{agent.agent_id}"].table[k] = {
                  :action=> proc { |req|
                    v[:task].call(self, [req])
                    true
                  }
                }
              }
            }
          end
        }
          
        
        @manifest.exit_state.each { |state, sec|
          key = "on_exit_of_#{state}".to_sym

          if sec.task
            edc.add_observer(key) { |args|
              @thread_pool.pass {
                sec.task.call(self)
              }
            }
          end
        }
        
        @manifest.stm.process_event(:on_load)
        EventRouter.emit('resource_instance/loaded', nil, common_args())
      end
      
      def unload
        EventRouter.emit('resource_instance/unloaded', nil, common_args())
      end
      
      private
      def common_args(hash={})
        {:resource_uuid=>agent.manifest.node_id, :resource_type=>@manifest.name}.merge(hash)
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
