

require File.expand_path('../spec_helper', __FILE__)

require 'isono'

class A
  include Isono::AmqpClient


  define_exchange 'ex_a'
  define_exchange 'ex_b'
  define_exchange 'ex_c'

  define_queue ''
end

describe "AmqpClient Test" do

  it "connects with default args" do
    EM.run {
      a = A.new
      a.connect
      EM.next_tick {
        a.close
      }
    }
  end

  it "connects with default args" do
    EM.run {
      a = A.new
      a.connect
    }
  end

  it "class defined exchanges and queues" do
    A.
  end

end
