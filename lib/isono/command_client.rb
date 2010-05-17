# -*- coding: utf-8 -*-

require 'isono'

module Isono
  class CommandClient < Agent

    def initialize
      m = Manifest.new(Dir.pwd) {
        node_name 'command'
        node_id Util.gen_id

        manager ManagerModules::EventChannel
        manager ManagerModules::MqCommand
      }
      super(m)
    end

    def send_event(event, data, sender=agent_id)
      EventMachine.schedule {
        ManagerModules::EventChannel.instance.publish(event, sender, data)
      }
    end

    def sync_command(namespace, command, args={})
      ManagerModules::MqCommand.instance.sync_request(namespace, command, args)
    end

    def async_command(namespace, command, args={}, &blk)
      EventMachine.schedule {
        ManagerModules::MqCommand.instance.async_request(namespace, command, args, &blk)
      }
    end
    
  end
end
