# -*- coding: utf-8 -*-

require 'statemachine'
require 'pathname'

module Isono
  class ResourceManifest

    # DSL to define a new resource manifest.
    class Loader
      def initialize(m)
        @manifest = m
      end
      
      def description(desc)
        @manifest.description = desc
      end

      def statemachine(&blk)
        @manifest.stm = Statemachine.build(&blk)
      end

      def load_path(path)
        @manifest.load_path << if Pathname.new(path).absolute?
                                 path
                               else
                                 File.expand_path(path, @manifest.resource_root_path)
                               end
        @manifest.load_path.uniq!
      end

      def name(name)
        @manifest.name = name
      end
      
      def state_monitor(monitor_class, args=[])
        #raise ArgumentError unless
        #monitor_class.is_kind?(Isono::Monitor)
        @manifest.state_monitor = monitor_class
        monitor(monitor_class, args)
      end
      
      def monitor(monitor_class, args=[])
        #raise ArgumentError unless monitor_class.is_kind?(Isono::Monitor)
        @manifest.monitors[monitor_class]=args
      end
      
      def entry_state(state, &blk)
        (@manifest.entry_state[state] ||= StateItem.new).instance_eval(&blk)
      end
      
      def exit_state(state, &blk)
        (@manifest.exit_state[state] ||= StateItem.new).instance_eval(&blk)
      end
            
    end
    
    def self.load(path)
      root_path = File.dirname(path)
      buf = File.read(path)
      manifest = new(root_path)
      Loader.new(manifest).instance_eval buf
      manifest
    end

    attr_reader :resource_root_path, :monitors, :entry_state, :exit_state, :helpers, :load_path
    attr_accessor :name, :description, :stm, :state_monitor
    
    def initialize(root_path)
      @resource_root_path = root_path
      @state_monitor = nil
      @monitors = {}
      @entry_state = {}
      @exit_state  = {}
      @helpers = {}
      @load_path = ['lib']
    end

    class StateItem
      def initialize()
        @task = nil
        @on_event = {}
      end
      
      def on_event(evname, sender, &blk)
        @on_event[evname] = {
          :evname => evname,
          :sender => sender,
          :blk => blk
        }
        @on_event
      end
      
      def task(*args, &blk)
        if args
          @task = args
        else
          @task = blk if blk
        end
      end
    end


    module RakeHelper
      def default_rakefile(rakefile)
        @manifest.helpers[:default_rakefile] = rakefile
      end
    end
    

    
    
  end
  
end
