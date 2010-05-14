require File.expand_path('../spec_helper', __FILE__)

require 'isono'

MM = Isono::ManagerModules

describe "ResourceLoader Test" do

  it "loads manifest block" do
    rm = Isono::ResourceManifest.new('./')

    Isono::ResourceManifest::Loader.new(rm).instance_eval {
      state_monitor 'Hva::XenInstanceStore::XenMonitor'
      #monitor Hva::XenCapacityMonitor

      description "resource1"
      
      statemachine {
        trans :init,  :on_load, :ready
        trans :ready, :on_start, :starting
        trans :starting, :on_online, :running
        trans :running, :on_attach_volume, :attaching_volume
        trans :attaching_volume, :on_back_to_run, :running
        trans :running, :on_stop, :shuttingdown
        trans :shuttingdown, :on_offline, :terminated
      }

      #entry_state(:running) do
      #  resource_graph.find(:connected, my_resource_uuid).each { |res_uuid|
      #    on_event :stopped, res_uuid do
      #      #do something
      #    end
      #  }
      #end

      entry_state(:running) do
        on_event :stop_vm, 'mgr-master' do
          process_event(:on_stop)
        end
        
        on_event(:attach_volume, 'storage_node') {
          process_event(:on_attach_volume)
        }

        task {
        }
      end
      
      entry_state(:ready) do
        task do
          # immediatry change the state
          state_monitor.start
          process_event(:on_start)
        end
      end
      
      entry_state(:starting) {
        task :rake, 'start_vm'
      }
      
      entry_state(:shuttingdown) {
        task :rake, 'stop_vm'
      }
      
      entry_state(:attaching_volume) {
        task :rake, 'attach_file_vol'
      }
      
      entry_state(:terminated) {
        task do
          state_monitor.stop
        end
      }
      
    }

    rm.stm.should.is_a? Statemachine::Statemachine

  end



  it "resource instance process" do

    rm = Isono::ResourceManifest.new('./')

    Isono::ResourceManifest::Loader.new(rm).instance_eval {
      state_monitor 'Hva::XenInstanceStore::XenMonitor'
      #monitor Hva::XenCapacityMonitor

      description "resource1"
      
      statemachine {
        trans :init,  :on_load, :ready
        trans :ready, :on_start, :starting
        trans :starting, :on_online, :running
        trans :running, :on_attach_volume, :attaching_volume
        trans :attaching_volume, :on_back_to_run, :running
        trans :running, :on_stop, :shuttingdown
        trans :shuttingdown, :on_offline, :terminated
      }
    }

    EM.run {
      Isono::ResourceInstance.start('testuuid', rm, {:amqp_server_uri => URI.parse('amqp://guest:guest@localhost/'),
                                    })
      EM.add_timer(1) {
        Isono::ResourceInstance.stop
        EM.stop
      }
    }
  end
end
