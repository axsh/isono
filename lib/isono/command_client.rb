# -*- coding: utf-8 -*-

require 'isono'

module Isono
  class CommandClient
    include AmqpClient
    include Logger
    include ManagerHost

    def initialize
      @uuid = Util.gen_id
    end

    def managers
      [ManagerModules::EventChannel, ManagerModules::MqCommand]
    end

    def agent_id
      'command-' + @uuid
    end

    def send_event(event, data, sender=agent_id)
      EventMachine.schedule {
        ManagerModules::EventChannel.instance.publish(event, sender, data)
      }
    end

    def send_command(namespace, command, args={})
      logger.debug("send_command(#{namespace}, #{command}, #{args.inspect})")
      EventMachine.schedule {
        ManagerModules::MqCommand.instance.send(namespace, command, args)
      }
    end

    def on_connect
      load_managers
    end

    def on_close
      unload_managers
    end
    
  end
end
