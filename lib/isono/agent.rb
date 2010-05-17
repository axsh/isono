# -*- coding: utf-8 -*-

require 'isono'
require 'digest/sha1'

module Isono
  class Agent
    include Logger
    include AmqpClient
    include EventObservable
    include ManagerHost

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
        new_instance.call
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
    
    attr_reader :manifest, :boot_token
    
    def initialize(manifest)
      initialize_event_observable
      raise ArgumentError unless manifest.is_a? Manifest
      @manifest = manifest
      @boot_token = Digest::SHA1.hexdigest(Process.pid.to_s)[0,5]
    end

    def agent_id
      manifest.agent_id
    end

    def managers
      manifest.managers
    end

    def on_connect
      raise "agent_id is not set" if agent_id.nil?

      identity_queue(agent_id)
      load_managers

      fire_event(:agent_ready, {:agent_id=> self.agent_id})
      logger.info("Started : AMQP Server=#{amqp_server_uri.to_s}, ID=#{agent_id}, token=#{boot_token}")
    end

    def on_close
      unload_managers
    end

  end
end 
