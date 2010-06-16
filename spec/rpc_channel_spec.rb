
require File.expand_path('../spec_helper', __FILE__)

require 'isono'

MM = Isono::ManagerModules
include Isono


def create_command_provider
  manifest = Manifest.new(File.expand_path('../', __FILE__)) {
    node_name :cmd_provider
    node_id   :xxx
    
    manager MM::EventChannel
    manager MM::RpcChannel
    
  }
  manifest.command.register('test') {
    command('test1') { |req|
      {:code=>1}
    }
  }
  command = Agent.new(manifest)
end

def client_connect(main_cb, pre_cb=nil, post_cb=nil)
  em_fork(proc {
            c = MessagingClient.new
            pre_cb.call if pre_cb
            c.connect('amqp://localhost/') {
              main_cb.call(c)
            }
          },post_cb)
end


def svr_connect(main_cb, pre_cb=nil, post_cb=nil)
  em_fork(proc {
            c = create_command_provider
            pre_cb.call if pre_cb
            c.connect('amqp://localhost/') {
              main_cb.call(c)
            }
          },post_cb)
end

describe "RpcChannel and MessagingClient" do
  
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
  
  it "send async_command" do
    svr_connect(proc{|c|
                  EventRouter.subscribe('mq_command/request_received', '*') { |m|
                    m[:namespace].should.equal 'test'
                    m[:command].should.equal 'test1'
                  }
                  EventRouter.subscribe('mq_command/response_sent', '*') { |m|
                    m[:type].should.equal :success
                    EM.next_tick { EM.stop }
                  }
                }, proc{
                })

    client_connect(proc {|c|
                     EventRouter.subscribe('mq_command/request_sent', '*') { |m|
                       m[:state].should.equal :waiting
                     }

                     req0 = c.async_command('test', 'test1') { |req|
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


  it "command timeout" do
    client_connect(proc {|c|
                     c.async_command('test', 'test1') { |req|
                       req.timeout_sec = 0.1
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

end
