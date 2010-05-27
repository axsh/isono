# -*- coding: utf-8 -*-

module Isono
  class EventRouter
    Channel = ManagerModules::EventChannel

    def self.emit(evname, sender=nil, args={})
      return unless Channel.instance.initialized?
      Channel.instance.publish(evname, sender, args)
    end

    def self.subscribe(evname, sender=nil, &blk)
      return unless Channel.instance.initialized?
      Channel.instance.subscribe(evname, sender, &blk)
    end

    def self.unsubscribe(ticket)
      return unless Channel.instance.initialized?
      #Channel.instance.unsubscribe(*args)
    end
  end
end
