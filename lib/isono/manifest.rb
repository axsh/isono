# -*- coding: utf-8 -*-

require 'ostruct'
require 'pathname'

module Isono
  # Deals with .isono manifest file and its data.
  class Manifest
    # Loads .isono manifest file
    # @param [String] path to which you want to load.
    # @return [Isono::Manifest] new manifest object
    def self.load_file(path)
      buf = File.read(path)
      # use the parent directory as the application root.
      app_root = File.dirname(path)
      m = eval("#{self.to_s}.new('#{app_root}') {\n" + buf + "\n}", TOPLEVEL_BINDING, path)

      # use the manifest filename as the node name if not set.
      m.node_name(File.basename(path, '.isono')) if m.node_name.nil?

      m
    end

    attr_reader :managers, :app_root, :command
    
    # @param [String] app_root Application root folder
    # @param [block]
    def initialize(app_root, &blk)
      @managers = []
      resolve_abs_app_root(app_root)
      @config = ConfigStruct.new
      @config.app_root = app_root

      @command = CommandTable.new
      instance_eval(&blk) if blk
      load_config
    end

    # Register manager module class
    def manager(manager_class, *args)
      unless manager_class.is_a?(Class) && manager_class < Isono::ManagerModules::Base
        raise ArgumentError, ""
      end

      sec_builder = manager_class.instance_variable_get(:@config_section_builder)
      if sec_builder.is_a? Proc
        sec_name = manager_class.instance_variable_get(:@config_section_name)
        #sec_builder.call(ConfigStructBuilder.new(@config.add_section(sec_name)))
        ConfigStructBuilder.new(@config.add_section(sec_name)).instance_eval &sec_builder
      end
      ns = manager_class.instance_variable_get(:@command_namespace)
      if ns 
        command.register(ns[:namespace], &ns[:block])
      end
      @managers << [manager_class.instance, *args]
    end

    def node_name(name=nil)
      @node_name = name.to_s if name
      @node_name
    end

    def node_id(node_id=nil)
      @node_id = node_id.to_s if node_id
      @node_id
    end

    def agent_id
      "#{@node_name}-#{@node_id}"
    end

    def config_path(path=nil)
      @config_path = path if path
      @config_path
    end

    def config(&blk)
      if blk
        @config.instance_eval &blk
      end
      @config
    end

    
    private
    # load config file and merge up with the config tree.
    # it will not work when the config_path is nil or the file is missed
    def load_config
      if @config_path && File.exist?(@config_path)
        buf = File.read(@config_path) 
        eval("#{buf}", binding, @config_path)
      end
    end

    def resolve_abs_app_root(app_root_path)
      pt = Pathname.new(app_root_path)
      if pt.absolute?
        @app_root = app_root_path
      else
        @app_root = pt.realpath
      end
    end


    class ConfigStruct < OpenStruct
      attr_reader :desc
      
      def initialize()
        super
        @desc = {}
      end
      
      # create sub config tree
      def add_section(name)
        newsec = self.class.new
        self.instance_eval %Q"
          def #{name}(&blk)
            blk.call(self) if blk
            @table[:#{name}]
          end
        "
        @table[name.to_sym] = newsec
      end

      def inspect
        @table.keys.map { |k|
          "#{k}=#{@table[k]}"
        }.join(', ')
      end

    end


    class ConfigStructBuilder
      def initialize(config)
        @cur_desc=nil
        @config = config
      end

      def add_config(name, default_val=nil)
        @config.send("#{name}=".to_sym, default_val)
        @config.desc[name.to_sym] = @cur_desc
        
        @cur_desc = nil
      end

      def desc(desc)
        @cur_desc = desc
      end

      def method_missing(name, *args)
        return if name.to_sym == :add_config
        if name.to_s =~ /=$/
          add_config(name.to_s.sub(/=$/,''), args[0])
        else
          add_config(name, *args)
        end
      end
    end
    
  end
end
