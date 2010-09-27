
require File.expand_path('../spec_helper', __FILE__)

require 'isono'

class A
  include Isono::AmqpClient
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

end
