require File.expand_path('../spec_helper', __FILE__)

require 'isono'


describe "ThreadPool Test" do

  it "create a thread pool" do
    a = Isono::ThreadPool.new
    #a.should Isono::ThreadPool
  end

  it "call pass() with single thread" do
    a = Isono::ThreadPool.new
    t = 0
    a.pass { t = 1 }
    
    t.should eql(1)
  end

  it "call barrier() with single thread" do
    a = Isono::ThreadPool.new
    t = 0 
    a.barrier { t = 1 }
    
    t.should eql(1)
  end

  it "catch exception from barrier()" do
    a = Isono::ThreadPool.new
    lambda {
      a.barrier { raise "Error" }
    }.should raise_error(RuntimeError, "Error")
  end
end
