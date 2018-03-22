# -*- coding: utf-8 -*-

module Isono
  require 'isono/version'
  require 'isono/logger'
  
  autoload :Node, 'isono/node'
  autoload :AmqpClient, 'isono/amqp_client'
  autoload :Daemonize, 'isono/daemonize'
  autoload :Util, 'isono/util'
  autoload :ThreadPool, 'isono/thread_pool'
  autoload :Manifest, 'isono/manifest'
  autoload :Serializer, 'isono/serializer'
  autoload :EventObservable, 'isono/event_observable'
  autoload :EventDelegateContext, 'isono/event_delegate_context'
  autoload :ResourceManifest, 'isono/resource_manifest'
  autoload :MessagingClient, 'isono/messaging_client'
  module NodeModules
    autoload :Base, 'isono/node_modules/base'
    autoload :DataStore, 'isono/node_modules/data_store'
    autoload :EventChannel, 'isono/node_modules/event_channel'
    autoload :DirectChannel, 'isono/node_modules/direct_channel'
    autoload :RpcChannel, 'isono/node_modules/rpc_channel'
    autoload :NodeHeartbeat, 'isono/node_modules/node_heartbeat'
    autoload :NodeCollector, 'isono/node_modules/node_collector'
    autoload :EventLogger, 'isono/node_modules/event_logger'
    autoload :JobWorker, 'isono/node_modules/job_worker'
    autoload :JobChannel, 'isono/node_modules/job_channel'
    autoload :JobCollector, 'isono/node_modules/job_collector'
  end  
  module Runner
    autoload :Base, 'isono/runner/base'
    autoload :CLI, 'isono/runner/cli'
    autoload :RpcServer, 'isono/runner/rpc_server'
  end
  module Rack
    require 'isono/rack'
    autoload :Builder, 'isono/rack/builder'
    autoload :ObjectMethod, 'isono/rack/object_method'
    autoload :Proc, 'isono/rack/proc'
    autoload :ThreadPass, 'isono/rack/thread_pass'
    autoload :Job, 'isono/rack/job'
    autoload :DataStore, 'isono/rack/data_store'
    autoload :Map, 'isono/rack/map'
    autoload :Sequel, 'isono/rack/sequel'
  end

  module Models
    autoload :NodeState, 'isono/models/node_state'
    autoload :ResourceInstance, 'isono/models/resource_instance'
    autoload :EventLog, 'isono/models/event_log'
    autoload :JobState, 'isono/models/job_state'
  end

  class << self
    def home
      if Kernel.const_defined?(:Gem) && (gemspec = Gem.loaded_specs['isono'])
        gemspec.full_gem_path
      else
        File.expand_path('../../', __FILE__)
      end
    end

    def at_disconnected(&blk)
      @disconnected ||= []
      if blk.is_a?(Proc)
        @disconnected << blk
      end
      @disconnected
    end
  end
end
