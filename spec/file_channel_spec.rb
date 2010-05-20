require File.expand_path('../spec_helper', __FILE__)

require 'isono'

require 'fileutils'
require 'tempfile'

MM = Isono::ManagerModules
include Isono


def create_sender
  manifest = Manifest.new(File.expand_path('../', __FILE__)) {
    node_name :test
    node_id   :id
    
    manager MM::EventChannel
    manager MM::FileSenderChannel
    
  }
  Agent.new(manifest)
end

def create_receiver
  manifest = Manifest.new(File.expand_path('../', __FILE__)) {
    node_name :receiver
    node_id   :xxx
    
    manager MM::EventChannel
    manager MM::FileReceiverChannel
    
    config do |c|
      c.file_receiver_channel.buffer_dir = '/tmp'
      c.file_receiver_channel.complete_dir = './complete'
    end
  }

  Agent.new(manifest)
end



# quick hack for the rspec process fork issue.
# each spec runs twice where fork() appers if it's not there.
#at_exit { exit! }

describe "file channel" do
  
  it "creates new instance" do
    em_fork(proc {
              c = create_sender
              c.connect('amqp://localhost/') {
                EM.stop
              }
            })
    em_fork(proc {
              c = create_receiver
              c.connect('amqp://localhost/') {
                EM.stop
              }
            })

    Process.waitall.all? { |s|
      s[1].exitstatus == 0
    }.should.equal true
  end

  
  def tmp_file_send(sender, to=:receiver, &blk)
    
    tmpf = Tempfile.open('filechannelspec')
    tmpf.flush
    `/usr/bin/shred -s 50K #{tmpf.path}`
    # manually handles the start_streaming
    sc = sender.create_sender(to, tmpf.path, File.basename(tmpf.path), :checksum=>true)
    
    sc.state.should.equal :init
    sc.src_path.should.equal tmpf.path
    sc.dst_path.should.equal File.basename(tmpf.path)

    sc.add_observer(:on_read) {
    }
    sc.add_observer(:on_eof) {
      blk.call if blk
    }
    
    EM.next_tick {
      sc.start_streaming
    }
    sc
  end
  
  it "sends a file" do
    em_fork(proc {
              c = create_sender
              c.connect('amqp://localhost/') {
                sc = tmp_file_send(MM::FileSenderChannel.instance) {
                  sc.state.should.be.equal :eof
                  EM.stop
                }
              }
            })

    Process.waitall.all? { |s|
      s[1].exitstatus == 0
    }.should.equal true
  end

  it "sends multiple files" do
    em_fork(proc {
              c = create_sender
              c.connect('amqp://localhost/') {
                sc_lst = []
                5.times {
                  sc_lst << tmp_file_send(MM::FileSenderChannel.instance)
                }
        
                EM.add_periodic_timer(0.5) {
                  EM.stop if sc_lst.all? { |sc| sc.state == :eof }
                }
              }
            })

    Process.waitall.all? { |s|
      s[1].exitstatus == 0
    }.should.equal true
  end


  it "send and receive" do
    em_fork(proc {
              c = create_receiver
              flags = {}
              c.connect('amqp://localhost/') {
                MM::FileReceiverChannel.instance.add_observer(:on_create_receive_context) { |rc|
                  rc.state.should.equal :open
                  
                  flags[:ticket] = rc.ticket
                  rc.add_observer(:on_bof) {
                    flags[:on_bof] = true
                  }
                  rc.add_observer(:on_chunk) {
                    flags[:on_chunk] = true
                  }
                  rc.add_observer(:on_eof) {
                    flags[:on_eof] = true
                  }
                  
                }
                MM::FileReceiverChannel.instance.add_observer(:on_destroy_receive_context) { |rc|
                  rc.ticket.should.equal flags[:ticket]
                  rc.state.should.equal :close
                  [:on_bof, :on_chunk, :on_eof].each { |k|
                    flags[k].should.true?
                  }
                  EM.stop
                }
                
              }
            })
    
    
    em_fork(proc {
              c = create_sender
              c.connect('amqp://localhost/') {
                sender = MM::FileSenderChannel.instance
                tmp_file_send(sender, 'receiver-xxx') {
                  EM.stop
                }
              }
            })
    
    Process.waitall.all? { |s|
      s[1].exitstatus == 0
    }.should.equal true
  end

  it "send multiple and receive them" do
    sender_pid = \
    em_fork(proc {
              Signal.trap(:TERM) { EM.stop }

              c = create_sender
              c.connect('amqp://localhost/') {
                sender = MM::FileSenderChannel.instance
                5.times {
                  tmp_file_send(sender, 'receiver-xxx')
                }
              }
            })
    
    em_fork(proc {
              c = create_receiver
              flags = {}
              c.connect('amqp://localhost/') {
                MM::FileReceiverChannel.instance.add_observer(:on_create_receive_context) { |rc|
                  rc.state.should.equal :open
                  
                  flags[rc.ticket] = rc
                }
                MM::FileReceiverChannel.instance.add_observer(:on_destroy_receive_context) { |rc|
                  rc.state.should.equal :close
                  flags.has_key?(rc.ticket).should.true?
                  
                  if flags.values.all? { |v| v.state == :close }
                    Process.kill(:TERM, sender_pid)
                    EM.stop
                  end
                }
              }
            })


    Process.waitall.all? { |s|
      s[1].exitstatus == 0
    }.should.equal true
  end


  it "pull a file" do
    tmpf = Tempfile.open('filechannelspec')
    tmpf.flush
    `/usr/bin/shred -s 50K #{tmpf.path}`

    sender_pid = \
    em_fork(proc {
              Signal.trap(:TERM) { EM.stop }
              
              c = create_sender
              c.connect('amqp://localhost/') {
                sender = MM::FileSenderChannel.instance
                sender.add_pull_repository('/tmp/', 'tmp_repos')
              }
            })
    
    em_fork(proc {
              c = create_receiver
              flags = {}
              c.connect('amqp://localhost/') {
                MM::FileReceiverChannel.instance.add_observer(:on_create_receive_context) { |rc|
                  rc.state.should.equal :open
                  
                  flags[rc.ticket] = rc
                }
                MM::FileReceiverChannel.instance.add_observer(:on_destroy_receive_context) { |rc|
                  rc.state.should.equal :close
                  flags.has_key?(rc.ticket).should.true?

                  if flags.values.all? { |v| v.state == :close }
                    Process.kill(:TERM, sender_pid)
                    EM.stop
                  end
                }
                MM::FileReceiverChannel.instance.pull("tmp_repos:#{File.basename(tmpf.path)}")
              }
            })
    
    Process.waitall.all? { |s|
      s[1].exitstatus == 0
    }.should.equal true
  end
  
end
