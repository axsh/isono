
require File.expand_path('../spec_helper', __FILE__)

require 'isono'
include Isono

class HookTest < Isono::NodeModules::Base
  before_connect_hook do
    $pass.shift.should.equal :before_connect
  end

  after_connect_hook do
    $pass.shift.should.equal :after_connect
  end

  before_close_hook do
    $pass.shift.should.equal :before_close
  end

  after_close_hook do
    $pass.shift.should.equal :after_close
  end
end

class MockNode < Isono::Node
  def initialize()
    super(Isono::Manifest.new do
          end)
  end
end

describe Isono::Node do

  em "connects to AMQP broker" do
    a = MockNode.new
    a.connect('amqp://localhost/') {
      a.amqp_client.should.not.nil?
      a.amqp_client.instance_variable_get(:@connection_status).should.is_a?(Proc)
      EM.next_tick {
        a.close {
          EM.stop
        }
      }
    }
  end
  
  em "call node_module hooks" do
    $pass = [:before_connect, :after_connect,
            :before_close, :after_close]
    a = Node.new(Isono::Manifest.new do
                   load_module HookTest
                 end)
    a.connect('amqp://localhost/') {
      EM.next_tick {
        a.close {
          $pass.size.should.equal 0
          EM.stop
        }
      }
    }
  end
  

end
