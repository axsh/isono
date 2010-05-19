# -*- coding: utf-8 -*-

require 'singleton'
require 'extlib/string'

module Isono
  module ManagerModules
    # Base class for manager module. All the manager modules have to be
    # derived from this class. The derived class will have the codes in
    # each  since this is mostly an abstruct class.
    class Base
      include EventObservable

      def self.dependency(depmgrclass)
        raise ArgumentError unless depmgrclass < Isono::ManagerModules::Base
        @dependencies ||= []
        @dependencies << depmgrclass
      end

      def self.config_section(name=nil, &blk)
        @config_section_name = name unless name.nil? 
        @config_section_builder = blk
      end

      def self.command_namespace(namespace, &blk)
        @command_namespace = {:namespace=>namespace, :block => blk}
      end

      def self.inherited(klass)
        klass.class_eval {
          include Singleton
          # set the default config section name from its class name.
          # can be overwritten later.
          @config_section_name = self.to_s.split('::').last.snake_case

          # force to kill the singleton object.
          # mainly used in the test cases.
          def self.reset_instance
            @singleton__instance__ = nil
          end
        }
      end

      attr_accessor :agent, :initialized
      alias :initialized? :initialized

      # this is the singleton class. the initialize() can not take any
      # args.
      def initialize
        initialize_event_observable
      end
      
      def config_section
        agent.manifest.config.send(self.class.instance_variable_get(:@config_section_name))
      end
      
      # called when the manager class is loaded at first time.
      # @params [Array] args Initialization arguments given in manifest.
      # @return none
      def on_init(args); end

      # called when the program is just before shutdown.
      # @return none
      def on_terminate; end


      protected
      def subscribe_event(event_type, sender, &blk)
        raise "EventChannel has to be loaded" unless EventChannel.instance.initialized?
        EventChannel.instance.subscribe(event_type, sender, &blk)
      end

      def unsubscribe_event(event_type)
        raise "EventChannel has to be loaded" unless EventChannel.instance.initialized?
        EventChannel.instance.unsubscribe(event_type)
      end
    end
  end
end
