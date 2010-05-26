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
          DataStore.barrier {
            Models::ResourceInstance.dataset.all.map { |row|
              row.values
            }
          }
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

        EventRouter.subscribe("resource_loader/instance_fail", '*') { |data|
          logger.warn("ResourceInstance unexpectedly shutdown: #{data[:resource_uuid]}")
          DataStore.pass {
            ri = Models::ResourceInstance.find(:uuid=>data[:resource_uuid])
            ri.delete if ri
          }
        }
      end

      def on_terminate
        @deploy_thread.shutdown
      end

      def install(agent_id, resource_type, instance_data={})
        raise ArgumentError, "agent_id has to be specifed" if agent_id.nil? || agent_id == ''
        raise ArgumentError, "resource_type has to be specifed" if resource_type.nil? || resource_type == ''

        DataStore.barrier {
          raise "agent_id #{agent_id} can not be found." unless Models::AgentPool.find(:agent_id=>agent_id)
        }
        resfolder = File.expand_path(resource_type, config_section.resource_base_dir)
        raise "unable to find the resource folder: #{resfolder}" unless File.directory?(resfolder)
        
        @deploy_thread.pass {

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
        raise ArgumentError, "resource_uuid has to be specifed" if resource_uuid.nil? || resource_uuid == ''
        
        ri = DataStore.barrier {
          Models::ResourceInstance.find(:uuid=>resource_uuid)
        }

        raise "ResourceInstance #{resource_uuid} can not be found." if ri.nil?
        
        msg = {:command=>:uninstall, :resource_uuid=>resource_uuid}
        logger.info("#{ri.uuid}: #{ri.resource_type} being uninstalled from #{ri.agent_id}")
        EventMachine.schedule {
          agent.amq.direct('resource').publish(Marshal.dump(msg), {:key=>"resloader.#{ri.agent_id}"})
        }
      end

      def migrate(resource_uuid, agent_id)
      end
      
    end
  end
end
