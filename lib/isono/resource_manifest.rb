# -*- coding: utf-8 -*-

require 'statemachine'
require 'pathname'
require 'yaml'

module Isono
  class ResourceManifest
    include Logger

    # DSL to define a new resource manifest.
    class Loader
      include Logger
      
      def initialize(m)
        @manifest = m
      end
      
      def description(desc)
        @manifest.description = desc
      end
      alias :desc :description

      def statemachine(&blk)
        @manifest.stm = Statemachine.build(&blk)
      end

      def load_path(path)
        @manifest.append_load_path(path)
      end

      def name(name)
        @manifest.name = name
      end
            
      def state_monitor(monitor_class, &blk)
        @manifest.state_monitor = self.monitor(monitor_class, &blk)
      end
      
      def monitor(monitor_class, &blk)
        raise ArgumentError unless monitor_class.is_a?(Class) && monitor_class < Isono::Monitors::Base
        raise "duplicate registration: #{monitor_class}" if @manifest.monitors.has_key?(monitor_class)
        
        m = monitor_class.new()
        m.instance_eval &blk if blk
        @manifest.monitors[monitor_class] = m
      end

      def entry_state(state, &blk)
        (@manifest.entry_state[state] ||= StateItem.new).instance_eval(&blk)
      end
      
      def exit_state(state, &blk)
        (@manifest.exit_state[state] ||= StateItem.new).instance_eval(&blk)
      end

      def plugin(klass)
        logger.debug("plugin: #{klass.to_s}")
        if klass.const_defined?(:ClassMethods) && klass.const_get(:ClassMethods).is_a?(Module)
          self.extend(klass.const_get(:ClassMethods))
        end

        #if klass.respond_to? :extend_task
        if klass.const_defined?(:TaskMethods) && klass.const_get(:TaskMethods).is_a?(Module)
          TaskBlock.class_eval {
            include klass.const_get(:TaskMethods)
          }
        end
      end

      def manifest
        @manifest
      end

      def config(&blk)
        Manifest::ConfigStructBuilder.new(@manifest.config).instance_eval &blk
      end
        
    end
    
    def self.load(path)
      root_path = File.dirname(path)
      manifest = new(root_path)

      # instance_data has to be loaded before manifest file
      # evaluation.
      if File.file?(manifest.instance_data_path)
        manifest.instance_data = YAML.load(File.read(manifest.instance_data_path)).freeze
      end

      logger.info("Loading resource.manifest: #{path}")
      buf = File.read(path)
      Loader.new(manifest).instance_eval(buf, path)
      manifest
    end

    attr_reader :resource_root_path, :monitors, :entry_state, :exit_state, :helpers, :load_path
    attr_reader :config
    attr_accessor :name, :description, :stm, :state_monitor, :instance_data
    
    def initialize(root_path)
      @resource_root_path = root_path
      @state_monitor = nil
      @monitors = {}
      @entry_state = {}
      @exit_state  = {}
      @helpers = {}
      @load_path = []
      @config = Manifest::ConfigStruct.new

      append_load_path('lib')
    end

    def instance_data_path
      File.expand_path('instance_data.yml', @resource_root_path)
    end
    
    def append_load_path(path)
      real_path = if Pathname.new(path).absolute?
                    path
                  else
                    File.expand_path(path, @resource_root_path)
                  end
      unless $LOAD_PATH.member? real_path
        load_path << path
        $LOAD_PATH.unshift real_path
      end
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
      
      def task(&blk)
        @task = TaskBlock.new(&blk)
      end
    end

    class TaskBlock
      def initialize(&blk)
        @blk = blk
      end

      def call(resource_instance)
        @ri = resource_instance

        instance_eval @blk
      end
      
      private
      def state_monitor
        @ri.state_monitor
      end
      
      def next_event(ev, *args)
        @ri.stm.process_event(ev, *args)
      end
      
    end
    
    module RakeHelper
      module ClassMethods
        def default_rakefile(rakefile)
          rakefile =
            if Pathname.new(rakefile).absolute?
              rakefile.dup
            else
              File.expand_path(rakefile, @manifest.resource_root_path)
            end
          raise "File does not exist: #{rakefile}" unless File.exist?(rakefile)
          @manifest.helpers[:default_rakefile] = rakefile
        end

        def rake_bin_path(path)
          @manifest.helpers[:rake_bin_path] = path
        end
      end

      module TaskMethods
        def rake(task, rakefile=nil, &blk)
          rake_path = manifest.helpers[:rake_bin_path] || Gem.bin_path('rake', 'rake')
          rakefile = if rakefile
                       rakefile
                     elsif manifest.helpers[:default_rakefile]
                       manifest.helpers[:default_rakefile]
                     else
                       raise "Rakefile is not specified."
                     end

          cmd = Util.quote_args("%s -I%s -f %s --rakelib %s RESOURCE_MANIFEST=%s %s",
                                [rake_path,
                                 File.join(Isono.home, 'lib'),
                                 rakefile,
                                 #File.join(Isono.home, 'tasks/load_resource_manifest.rake'),
                                 File.join(Isono.home, 'tasks'),
                                 File.expand_path('resource.manifest', manifest.resource_root_path),
                                 task
                                ])
          logger.debug(cmd)
          system(cmd)
        end
      end
    end
    
  end
end
