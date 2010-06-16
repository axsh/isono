# -*- coding: utf-8 -*-
require 'rubygems'

module Isono
  VERSION='0.0.1'

  autoload :Agent, 'isono/agent'
  autoload :AmqpClient, 'isono/amqp_client'
  autoload :Daemonize, 'isono/daemonize'
  autoload :Util, 'isono/util'
  autoload :ThreadPool, 'isono/thread_pool'
  autoload :Logger, 'isono/logger'
  autoload :Monitor, 'isono/monitor'
  autoload :Manifest, 'isono/manifest'
  autoload :Serializer, 'isono/serializer'
  autoload :EventRouter, 'isono/event_router'
  autoload :EventObservable, 'isono/event_observable'
  autoload :EventDelegateContext, 'isono/event_delegate_context'
  autoload :ResourceManifest, 'isono/resource_manifest'
  autoload :ManagerHost, 'isono/manager_host'
  autoload :MessagingClient, 'isono/messaging_client'
  autoload :CommandTable, 'isono/command_table'
  module ManagerModules
    autoload :Base, 'isono/manager_modules/base'
    autoload :AgentHeartbeat, 'isono/manager_modules/agent_heartbeat'
    autoload :AgentCollector, 'isono/manager_modules/agent_collector'
    autoload :DataStore, 'isono/manager_modules/data_store'
    autoload :EventChannel, 'isono/manager_modules/event_channel'
    autoload :FileSenderChannel, 'isono/manager_modules/file_sender_channel'
    autoload :FileReceiverChannel, 'isono/manager_modules/file_receiver_channel'
    autoload :ResourceLocator, 'isono/manager_modules/resource_locator'
    autoload :ResourceLoader, 'isono/manager_modules/resource_loader'
    autoload :RpcChannel, 'isono/manager_modules/rpc_channel'
    autoload :ResourceInstance, 'isono/manager_modules/resource_instance'
    autoload :EventLogger, 'isono/manager_modules/event_logger'
  end
  module Runner
    autoload :Agent, 'isono/runner/agent'
  end

  module Models
    autoload :AgentPool, 'isono/models/agent_pool'
    autoload :ResourceInstance, 'isono/models/resource_instance'
    autoload :EventLog, 'isono/models/event_log'
  end
  module Monitors
    autoload :Base, 'isono/monitors/base'
    autoload :PidFile, 'isono/monitors/pid_file'
  end


  class << self
    def home
      if Kernel.const_defined?(:Gem) && (gemspec = Gem.loaded_specs['isono'])
        gemspec.full_gem_path
      else
        File.expand_path('../../', __FILE__)
      end
    end
  end
end
