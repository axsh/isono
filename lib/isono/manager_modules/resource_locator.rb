# -*- coding: utf-8 -*-

require 'fileutils'
require 'tmpdir'

module Isono
  module ManagerModules
    class ResourceLocator < Base
      include Logger

      config_section do |config|
        config.resource_base_dir = ''
        config.resource_tmp_dir = Dir.tmpdir
      end

      command_namespace('resource_locator') do
        desc "show live resource instances"

        command('list_instances') { |req|
          lst = []
          DataStore.barrier {
            Models::ResourceInstance.dataset.each { |row|
              lst << row.hash
            }
          }
          lst
        }

        command('install') { |req|
          ResourceLocator.instance.install(req.params[:agent_id],
                                           req.params[:resource_name])
        }
        
        command('uninstall') { |req|
          ResourceLocator.instance.uninstall(req.args[:resource_uuid])
        }
      end
      
      
      def on_init(args)
        agent.amq.direct('resource')
        FileSenderChannel.instance.add_pull_repository(config_section.resource_tmp_dir, 'resource_locator')

        # setup tmp path
        FileUtils.mkpath(config_section.resource_tmp_dir) unless File.directory?(config_section.resource_tmp_dir)
        
        @deploy_thread = ThreadPool.new()

        #AgentMonitor.instance.add_observer(:agent_monitored) { |agent|
        #  install(agent.agent_id, 'xen-instance-store')
        #}

        subscribe_event(:resource_process_fail, '*') { |data|
          DataStore.pass {
            ri = Models::ResourceInstance.find(:uuid=>data[:message][:resource_uuid])
            ri.delete if ri
          }
        }
      end

      def on_terminate
        @deploy_thread.shutdown
      end

      def install(agent_id, resource_type)
        @deploy_thread.pass {
          resfolder = File.expand_path(resource_type, config_section.resource_base_dir)
          raise "unable to find the resource folder: #{resfolder}" unless File.directory?(resfolder)

          uuid = Util.gen_id
          # make tmp archive to the tmp folder
          tmp_archive_dir = File.expand_path(uuid, config_section.resource_tmp_dir)
          logger.debug("recursive copying the resource folder: #{resfolder} -> #{tmp_archive_dir}")
          FileUtils.cp_r(resfolder, tmp_archive_dir)
          logger.debug("cd #{config_section.resource_tmp_dir}; tar cf '#{uuid}.tar' '#{uuid}'")
          system("cd #{config_section.resource_tmp_dir}; tar cf '#{uuid}.tar' '#{uuid}'")
          FileUtils.rm_r(tmp_archive_dir)

          ri = Models::ResourceInstance.new
          ri.uuid = uuid
          ri.agent_id = agent_id
          ri.resource_type = resource_type
          DataStore.barrier {
            ri.save
          }

          msg = {:command=>:install, :resource_type=>resource_type, :resource_uuid=>ri.uuid}
          logger.info("#{ri.uuid}: #{ri.resource_type} being installed onto #{agent_id}")

          EventMachine.schedule {
            agent.amq.direct('resource').publish(Marshal.dump(msg), {:key=>"resloader.#{agent_id}"})
          }
          #EventChannel.instance.publish(:load_resource, 'resource_locator', {:resource_type=>resource_type})
        }
      end

      def uninstall(resource_uuid)
        ri = DataStore.barrier {
          Models::ResourceInstance.find(:uuid=>resource_uuid)
        }

        if ri.nil?
          return
        end
        
        msg = {:command=>:uninstall, :resource_uuid=>resource_uuid}
        logger.info("#{ri.uuid}: #{ri.resource_type} being installed onto #{agent_id}")
        EventMachine.schedule {
          agent.amq.direct('resource').publish(Marshal.dump(msg), {:key=>"resloader.#{agent_id}"})
        }
      end

      def migrate(resource_uuid, agent_id)
      end
      
    end
  end
end
