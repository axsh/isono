
require 'rubygems'

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'bacon'
#require 'spec'
require 'isono'

class AmqpStub < Isono::Agent
  include Isono::Logger


  def fork_and_connect(broker_uri='amqp://localhost/', *args, &blk)
    EM.fork_reactor {
      connect(broker_uri, *args, &blk)
    }
  end

  def connect(broker_uri='amqp://localhost/', *args, &blk)
    super
  end

  def on_connect
    manifest.managers.each { |a|
      a[0].class.reset_instance
    }

    super
  end

  #def on_close
  #end


  def mm_instance(mgr_class, *args)
    raise ArgumentError unless mgr_class < Isono::ManagerModules::Base

    m = mgr_class.instance
    m.agent = self
    m.on_init(args)
    m
  end
end
