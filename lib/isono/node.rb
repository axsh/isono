# -*- coding: utf-8 -*-

require 'isono'
require 'digest/sha1'

module Isono
  # A node instance which joins AMQP network.
  # 
  class Node
    include Logger
    include AmqpClient
    include EventObservable

    def self.inherited(klass)
      klass.class_eval {
        include Logger
      }
    end

    def self.instance
      @instance
    end
    
    def self.start(manifest, opts)
      new_instance = proc {
        stop
        @instance = new(manifest)
        @instance.connect(opts[:amqp_server_uri], *opts)
      }
      
      if EventMachine.reactor_running?
        EventMachine.schedule {
          new_instance.call
        }
      else
        EventMachine.run new_instance
      end
    end
    
    def self.stop(&blk)
      return if @instance.nil?
      EventMachine.schedule {
        begin
          if @instance.connected?
            @instance.close {
              blk.call(@instance) if blk
            }
          end
        ensure
          @instance = nil
        end
      }
    end
    
    attr_reader :manifest, :boot_token, :value_objects
    
    def initialize(manifest)
      initialize_event_observable
      raise ArgumentError unless manifest.is_a? Manifest
      @manifest = manifest
      @boot_token = Digest::SHA1.hexdigest(Process.pid.to_s)[0,5]
      @value_objects = {}
    end

    def node_id
      manifest.node_id
    end

    def on_connect
      raise "node_id is not set" if node_id.nil?

      #amq.prefetch(1)
      identity_queue(node_id)
      init_modules

      fire_event(:node_ready, {:node_id=> self.node_id})
      logger.info("Started : AMQP Server=#{amqp_server_uri.to_s}, ID=#{node_id}, token=#{boot_token}")
    end

    def on_close
      term_modules
    end

    private
    
    def init_modules
      manifest.node_modules.each { |modclass, *args|
        if !@value_objects.has_key?(modclass)
          @value_objects[modclass] = vo = ValueObject.new(self, modclass)

          if modclass.initialize_hook.is_a?(Proc)
            vo.instance_eval(&modclass.initialize_hook)
          end

          logger.debug("Initialized #{modclass.to_s}")
        end
      }
    end

    def term_modules
      manifest.node_modules.reverse.each { |modclass, *args|
        vo = @value_objects[modclass]
        if vo && modclass.terminate_hook.is_a?(Proc)
          vo.instance_eval(&modclass.terminate_hook)
        end
        logger.info("Terminated #{modclass.to_s}")
      }
    end

    class ValueObject
      module DelegateMethods
        def self_class
          @_tmp[:modclass]
        end
        
        def myinstance
          @_tmp[:myself] ||= self_class.new(self.node)
        end
        
        def node
          @_tmp[:node]
        end
        
        def amq
          self.node.amq
        end
        
        def manifest
          self.node.manifest
        end
        
        def config_section
          manifest.config.send(@_tmp[:modclass].instance_variable_get(:@config_section_name))
        end
      end

      def initialize(node, modclass)
        @_tmp = {:node=>node, :modclass=>modclass}
      end

      include DelegateMethods
      
      def copy_instance_variables(vo)
        self.instance_variables.each { |n|
          next if n == '@_tmp'
          vo.instance_variable_set(n, self.instance_variable_get(n))
        }
        vo
      end

    end

  end
end 
