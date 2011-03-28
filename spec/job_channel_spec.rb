
require File.expand_path('../spec_helper', __FILE__)

require 'isono'
include Isono
MM=Isono::NodeModules

def new_node(inst_id, main_cb, pre_cb=nil, post_cb=nil)
  manifest = Manifest.new(File.expand_path('../', __FILE__)) {
    node_name 'jobtest'
    node_instance_id inst_id
    
    load_module MM::EventChannel
    load_module MM::RpcChannel
    load_module MM::JobWorker
    load_module MM::JobChannel
  }
  c = Node.new(manifest)
  pre_cb.call if pre_cb
  c.connect('amqp://localhost/') {
    main_cb.call(c)
  }
end


describe Isono::NodeModules::JobChannel do

  em "submit a job" do
    job_id = nil
    new_node("svr", proc {|c|
               job = MM::JobChannel.new(c)
               job.register_endpoint('endpoint1',proc { |req, res|
                                       req.command.should.equal 'job1'
                                       req.job.job_id.should.equal job_id
                                       sleep 1
                                       EM.stop
                                     })
             })
    new_node("cli", proc {|c|
               job = MM::JobChannel.new(c)
               job_id = job.submit('endpoint1', 'job1', 1)
               job_id.should.not.be.nil?
             })
    
  end

end
