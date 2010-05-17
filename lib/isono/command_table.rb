# -*- coding: utf-8 -*-

require 'singleton'

module Isono
  class CommandTable
    include Logger
    include EventObservable

    attr_reader :namespaces
    
    def initialize
      initialize_event_observable
      @namespaces = {}
    end
    
    def register(namespace, caller_obj=nil, &blk)
      raise "the namespace is already reserved: #{namespace}" if @namespaces.has_key?(namespace)
      
      k = KeyTable.new(namespace, caller_obj)
      NamespaceBuilder.new(k).instance_eval &blk
      @namespaces[namespace] = k
      fire_event(:registered, {:namespace=>namespace, :keytable=>k})
    end

    class KeyTable
      include Logger
      attr_reader :table, :namespace

      def initialize(namespace, caller_obj=nil)
        @table = {}
        @namespace = namespace
        @caller_obj = caller_obj
      end

      def dispatch(key, args={})
        d = table[key]
        raise "Unknown command: #{key} in #{namespace}" if d.nil?

        req = OpenStruct.new(:namespace=>namespace, :key=>key, :params=>args)
        logger.debug("executing command: #{namespace}/#{key}")
        d[:action].call(req)
      end
      
    end
    
    class NamespaceBuilder
      def initialize(keytable)
        @keytable = keytable
      end


      def desc(description)
        @desc = description
      end

      def command(key, &blk)
        @keytable.table[key] = {:action=>blk}
        @keytable.table[key][:description] = @desc if @desc
        @desc = nil
      end

    end
  end
end
