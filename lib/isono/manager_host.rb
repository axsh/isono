# -*- coding: utf-8 -*-

require 'tsort'

module Isono
  module ManagerHost
    def load_managers
      managers.each { |mgr, args|
        mgr = mgr.instance if mgr.is_a? Class
        logger.info("Initializing #{mgr.class}...")
        mgr.agent = self
        mgr.on_init(*args)
        mgr.initialized = true
        #logger.debug("Initialized #{mgr.class}: config=#{mgr.config_section.inspect}")
      }
    end

    def unload_managers
      mgr_classes = []
      managers.reverse.each { |mgr, args|
        mgr = mgr.instance if mgr.is_a? Class
        logger.info("Terminating #{mgr.class}...")
        mgr.on_terminate
        mgr_classes << mgr.class
      }

      # release singleton manager objects.
      mgr_classes.uniq.each { |mgr_class|
        mgr_class.reset_instance
      }
    end
  end
end
