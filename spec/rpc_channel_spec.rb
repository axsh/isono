
require File.expand_path('../spec_helper', __FILE__)

require 'isono'

MM = Isono::NodeModules
include Isono


def client_connect(main_cb, pre_cb=nil, post_cb=nil)
  em_fork(proc {
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
          },post_cb)
end


def svr_connect(main_cb, pre_cb=nil, post_cb=nil)
  em_fork(proc {
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
          },post_cb)
end

describe "RpcChannel: client and server" do
  
  it "creates connection" do
    done = false

    svr_connect(proc{ |c|
                  c.close {
                    done = true
                    EM.stop
                  }
                }, nil, proc{
                  done.should.equal true
                })

    client_connect(proc {|c|
                     c.close {
                       done = true
                       EM.stop
                     }
                   }, nil, proc {
                     done.should.equal true
                   })

    Process.waitall.all? { |s|
      s[1].exitstatus == 0
    }.should.equal true
  end
  
  it "send async request" do
    svr_connect(proc{|c|
                  rpc = MM::RpcChannel.new(c)
                  rpc.register_endpoint('endpoint1', Rack::Proc.build(:extract_args=>true) { |t|
                                          t.command('kill') { |arg1, arg2, arg3|
                                            arg1.should.equal 'arg1'
                                            arg2.should.equal 'arg2'
                                            arg3.should.equal 'arg3'
                                            
                                            EM.next_tick { EM.stop }
                                            {:code=>1}
                                          }
                                        })
                }, proc{
                })
    sleep 1
    client_connect(proc {|c|
                     rpc = MM::RpcChannel.new(c)
                     req0 = rpc.request('endpoint1', 'kill', 'arg1', "arg2", "arg3") { |req|
                       req.on_success { |res|
                         req0.ticket.should.equal req.ticket
                         res[:code].should.equal 1
                         c.close { EM.stop }
                       }
                     }
                   },proc {
                   })
    
    Process.waitall.all? { |s|
      s[1].exitstatus == 0
    }.should.equal true
  end


  it "request timeout" do
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
    
    Process.waitall.all? { |s|
      s[1].exitstatus == 0
    }.should.equal true
  end


  it "decorated dispatcher" do
    svr_connect(proc{|c|
                  rpc = MM::RpcChannel.new(c)
                  endpoint1 = Rack::Proc.build(:extract_args=>true) { |t|
                    t.command('kill') {
                      EM.add_timer(0.5) { EM.stop }
                    }
                    t.command('func1') { |arg1|
                      arg1.should.equal 'arg1'
                      sleep 2
                      {:code=>1}
                    }
                  }

                  rpc.register_endpoint('endpoint1', Rack::ThreadPass.new(endpoint1))
                }, proc{
                })
    sleep 1
    client_connect(proc {|c|
                     rpc = MM::RpcChannel.new(c)
                     10.times { |no|
                       req0 = rpc.request('endpoint1', 'func1', 'arg1') { |req|
                         req.on_success { |res|
                           req0.ticket.should.equal req.ticket
                           req0.complete_status.should.equal :success
                           #((req0.completed_at - req0.sent_at) > 1.5).should.be.true
                           res[:code].should.equal 1
                           puts "#{no} elapesed: #{req0.elapsed_time}"
                           if no == 9
                             rpc.request('endpoint1', 'kill') do |req|
                               #req.oneshot = true
                               req.on_success {
                                 EM.next_tick { EM.stop }
                               }
                             end
                           end
                         }
                       }
                     }
                   },proc {
                   })
    
    Process.waitall.all? { |s|
      s[1].exitstatus == 0
    }.should.equal true
  end
  
end
