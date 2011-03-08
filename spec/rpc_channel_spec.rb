
require File.expand_path('../spec_helper', __FILE__)

require 'isono'

MM = Isono::NodeModules
include Isono

def client_connect(main_cb, pre_cb=nil, post_cb=nil)
  manifest = Manifest.new(File.expand_path('../', __FILE__)) {
    node_name :cli
    node_instance_id   :xxx
    
    load_module MM::EventChannel
    load_module MM::RpcChannel
  }
  c = Node.new(manifest)
  pre_cb.call if pre_cb
  c.connect('amqp://localhost/') {
    main_cb.call(c)
  }
end


def svr_connect(main_cb, pre_cb=nil, post_cb=nil)
  manifest = Manifest.new(File.expand_path('../', __FILE__)) {
    node_name :endpoint
    node_instance_id   :xxx
    
    load_module MM::EventChannel
    load_module MM::RpcChannel
  }
  c = Node.new(manifest)
  pre_cb.call if pre_cb
  c.connect('amqp://localhost/') {
    main_cb.call(c)
  }
end


describe Isono::NodeModules::RpcChannel do
  em "creates connection" do
    done = []
    svr_connect(proc{ |c|
                  c.close {
                    done << 1
                  }
                })
    
    client_connect(proc {|c|
                     c.close {
                       done << 1
                     }
                   })
    
    EM.tick_loop {
      #done.should.equal [1, 1]
      EM.stop if done == [1, 1]
    }
  end
  
  em "send async request" do
    svr_connect(proc{|c|
                  rpc = MM::RpcChannel.new(c)
                  rpc.register_endpoint('endpoint1', Isono::Rack::Map.build { |t|
                                          t.map('kill') {
                                            request.args[0].should.equal 'arg1'
                                            request.args[1].should.equal 'arg2'
                                            request.args[2].should.equal 'arg3'
                                            
                                            EM.next_tick { EM.stop }
                                            response.response({:code=>1})
                                          }
                                        })
                })
    client_connect(proc {|c|
                     rpc = MM::RpcChannel.new(c)
                     req0 = rpc.request('endpoint1', 'kill', 'arg1', "arg2", "arg3") { |req|
                       req.on_success { |res|
                         req0.ticket.should.equal req.ticket
                         res[:code].should.equal 1
                         c.close
                       }
                     }
                   }
                   )
    
  end


  em "request timeout" do
    client_connect(proc {|c|
                     rpc = MM::RpcChannel.new(c)
                     rpc.request('test', 'test1') { |req|
                       req.timeout_sec = 0.2
                       req.on_error { |e|
                         e.should.equal :timeout
                         c.close { EM.stop }
                       }
                     }
                   })
  end


  em "use Isono::Rack dispatcher" do
    func1_count = 0
    svr_connect(proc{|c|
                  rpc = MM::RpcChannel.new(c)
                  endpoint1 = Isono::Rack::Map.build { |t|
                    t.map('kill') {
                      func1_count.should.equal 10
                      EM.next_tick { EM.stop }
                    }
                    t.map('func1') {
                      request.args[0].should.equal 'arg1'
                      func1_count += 1
                      response.response({:code=>1})
                    }
                  }

                  rpc.register_endpoint('endpoint1', Isono::Rack::ThreadPass.new(endpoint1))
                })
    client_connect(proc {|c|
                     rpc = MM::RpcChannel.new(c)
                     10.times { |no|
                       req0 = rpc.request('endpoint1', 'func1', 'arg1') { |req|
                         req.on_success { |res|
                           req0.ticket.should.equal req.ticket
                           req0.complete_status.should.equal :success
                           #((req0.completed_at - req0.sent_at) > 1.5).should.be.true
                           res[:code].should.equal 1
                           #puts "#{no} elapesed: #{req0.elapsed_time}"
                           if no == 9
                             rpc.request('endpoint1', 'kill') do |req|
                               req.on_success { |res|
                                 res[:code].should.equal 1
                               }
                             end
                           end
                         }
                       }
                     }
                   })
    
  end

  em "catch remote exception" do
    svr_connect(proc{|c|
                  rpc = MM::RpcChannel.new(c)
                  rpc.register_endpoint('endpoint1', Isono::Rack::Map.build { |t|
                                          t.map('kill') {
                                            raise StandardError, "message"
                                            response.response({:code=>1})
                                          }
                                        })
                }, proc{
                })
    client_connect(proc {|c|
                     rpc = MM::RpcChannel.new(c)
                     rpc.request('endpoint1', 'kill') { |req|
                       req.on_error { |e|
                         e.should.equal({:error_type=>'StandardError', :message=>'message'})
                         EM.stop
                       }
                     }
                   })    

  end
  
end
