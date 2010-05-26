# -*- coding: utf-8 -*-

module Isono
  class EventRouter
    Channel = ManagerModules::EventChannel

    def self.emit(evname, sender=nil, args={})
      Channel.instance.publish(evname, sender, args)
    end

    def self.subscribe(evname, sender=nil, &blk)
      Channel.instance.subscribe(evname, sender, &blk)
    end

    def self.unsubscribe(ticket)
      #Channel.instance.unsubscribe(*args)
    end
  end
end
