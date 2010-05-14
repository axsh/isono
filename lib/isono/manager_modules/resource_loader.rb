# -*- coding: utf-8 -*-

module Isono
  module ManagerModules
    class ResourceLoader < Base
      include Logger

      config_section do |c|
        c.desc 'the root directory to save the resource archive'
        c.resource_save_dir ''
        c.ruby_bin_path nil
      end
      
      def on_init(args)
        @debug_event = true
        @thread_pool = ThreadPool.new(1, self.class.to_s)
        @running_child = {}
        raise "resource_save_dir does not exist: #{config_section.resource_save_dir}" unless File.directory?(config_section.resource_save_dir)

        
        agent.amq.direct('resource')

        agent.amq.queue("resloader.#{agent.agent_id}", {:exclusive=>true}
                        ).bind('resource', {:key=>"resloader.#{agent.agent_id}"}).subscribe { |data|
          data = Marshal.load(data)
          @thread_pool.pass {
            case data[:command]
            when :install
              install(data)
            when :uninstall
              uninstall(data)
            end
          }
        }
      end

      def on_terminate
        @thread_pool.shutdown
      end

      protected
      def on_event_fired(evtype, *args)
        EventChannel.instance.publish(evtype, agent.agent_id, args.first)
      end

      private
      def install(data)
        resource_uuid = data[:resource_uuid]
        
        if File.directory?(File.expand_path(resource_uuid, config_section.resource_save_dir))
          run_sandbox(resource_uuid)
        else
          remote_path = "resource_locator:#{resource_uuid}.tar"
          FileReceiverChannel.instance.pull(remote_path) { |rc|
            rc.add_observer(:on_eof) { |rc|
              extract_resource(rc)
              @thread_pool.pass {
                run_sandbox(resource_uuid)
              }
            }
          }
          logger.info("installing")
        end
      end

      def uninstall(data)
        tgt = @running_child.find { |pid, d|
          d[:resource_uuid] == data[:resource_uuid]
        }

        add_observer_once(:resource_process_exit, 10) { |d|
          if d.is_a? EventObservable::Timeout
            logger.error("timedout uninstall: #{tgt[:resource_uuid]}")
          else
            @thread_pool.pass {
              path = File.expand_path(tgt[:resource_uuid], config_section.resource_save_dir)
              FileUtil.rm_r(path)
              logger.debug("successfully uninstall: #{tgt[:resource_uuid]}")
            }
          end
        }
        
        Process.kill(:TERM, tgt[:pid])
      end

      def extract_resource(rc)
        puts "cd #{config_section.resource_save_dir};tar xf #{rc.tmp_file_path}"
        system("cd #{config_section.resource_save_dir};tar xf #{rc.tmp_file_path}")
      end

      def run_sandbox(resource_uuid)
        manifest_path = File.expand_path("#{resource_uuid}/resource.manifest", config_section.resource_save_dir)

        cmd = '%s -I%s %s -s "%s" "%s"' % [ruby_bin_path(), File.join(Isono.home, 'lib'), ri_bin_path, agent.amqp_server_uri, manifest_path]
        logger.debug("#{cmd}")
        popenobj = EM.popen(cmd, EmSystemCb, STDOUT, method(:catch_child_exit))
        pid = EventMachine.get_subprocess_pid(popenobj.signature)
        @running_child[pid] = {:resource_uuid=>resource_uuid, :pid=>pid}
        fire_event(:resource_process_start, @running_child[pid].dup)
      end


      def ruby_bin_path
        #config_section.ruby_bin_path || ENV['_'] =~ /ruby/ ||
        require 'rbconfig'
        config_section.ruby_bin_path || File.expand_path(Config::CONFIG['RUBY_INSTALL_NAME'], Config::CONFIG['bindir'])
      end

      # look for the real path of bin/resource_instance
      def ri_bin_path
        File.expand_path('bin/resource_instance', Isono.home)
      end

      def catch_child_exit(exit_stat)
        c = @running_child.delete(exit_stat.pid)
        if c
          if exit_stat.exitstatus != 0
            fire_event(:resource_process_fail, c.merge({:exit_code=>exit_stat.exitstatus}))
          else
            fire_event(:resource_process_exit, c.merge({:exit_code=>exit_stat.exitstatus}))
          end
        end
      end

      # lib/em/processes.rb provides class SystemCmd for the EM.popen
      # callback as the default. However, it stores all the data from
      # stdout to memory until the spawn process dies.
      # This class works similary with SystemCmd but it pass the data
      # through another IO object.
      class EmSystemCb < EventMachine::Connection
        def initialize(io, exit_cb)
          @io = io
          @exit_cb = exit_cb
        end

        def receive_data data
          @io.write(data)
        end
        
        def unbind()
          @exit_cb.call(get_status)
        end
      end


      
      
    end
  end
end
