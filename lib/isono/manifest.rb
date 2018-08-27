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

    attr_reader :node_modules, :app_root
    
    # @param [String] app_root Application root folder
    # @param [block]
    def initialize(app_root='.', &blk)
      @node_modules = []
      resolve_abs_app_root(app_root)
      @config = ConfigStruct.new
      @config.app_root = app_root

      instance_eval(&blk) if blk
      
      load_config(@config_path) if @config_path
    end

    # Regist a node module class to be initialized/terminated.
    # @param [Class] mod_class
    def load_module(mod_class, *args)
      unless mod_class.is_a?(Class) && mod_class < Isono::NodeModules::Base
        raise ArgumentError, ""
      end

      return if @node_modules.find{|i| i[0] == mod_class }

      sec_builder = mod_class.instance_variable_get(:@config_section_builder)
      if sec_builder.is_a? Proc
        sec_name = mod_class.instance_variable_get(:@config_section_name)
        #sec_builder.call(ConfigStructBuilder.new(@config.add_section(sec_name)))
        ConfigStructBuilder.new(@config.add_section(sec_name)).instance_eval &sec_builder
      end
      @node_modules << [mod_class, *args]
    end
    alias manager load_module

    def node_name(name=nil)
      @node_name = name.to_s if name
      @node_name
    end

    def node_instance_id(instance_id=nil)
      @node_instance_id = instance_id.to_s if instance_id
      @node_instance_id
    end

    def node_id
      "#{@node_name}.#{@node_instance_id}"
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
    
    # load config file and merge up with the config tree.
    # it will not work when the config_path is nil or the file is missed
    def load_config(path)
      return unless File.exist?(path)
      buf = File.read(path) 
      eval("#{buf}", binding, path)
    end

    def load_config_foreach(path)
      File.foreach(path) do |f|
        if f.match(/^config/)
          m = f.match(/^config.(\w+)/)
          eval("#{f}", binding, path) if config.respond_to?(m[1].to_sym)
        end
      end
    end

    private
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
