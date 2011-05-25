# -*- coding: utf-8 -*-

require 'optparse'
require 'digest/sha1'
require 'etc'

require 'isono'
require 'isono/amqp_client'

module Isono
  module Runner

    module Daemonize
      # Change privileges of the process
      # to the specified user and group.
      def self.change_privilege(user, group=user)
        logger.info("Changing process privilege to #{user}:#{group}")
        
        uid, gid = Process.euid, Process.egid
        target_uid = Etc.getpwnam(user).uid
        target_gid = Etc.getgrnam(group).gid
        
        if uid != target_uid || gid != target_gid
          # Change process ownership
          Process.initgroups(user, target_gid)
          Process::GID.change_privilege(target_gid)
          Process::UID.change_privilege(target_uid)
        end
      rescue Errno::EPERM => e
        logger.error("Couldn't change user and group to #{user}:#{group}: #{e}")
      end

      def self.daemonize(log_io=STDOUT)
        exit if fork
        srand
        trap 'SIGHUP', 'DEFAULT'
        
        STDIN.reopen('/dev/null')
        
        STDOUT.reopen(log_io)
        STDERR.reopen(log_io)
      end
    end
    
    class Base
      include Logger
      
      def initialize()
        @options = {
          :amqp_server_uri => URI.parse('amqp://guest:guest@localhost/'),
          :log_file => nil,
          :pid_file => nil,
          :daemonize => false,
          :config_path => nil,
          :manifest_path => nil,
        }
      end

      def optparse(args)
        optparse = OptionParser.new do |opts|
          opts.banner = "Usage: #{$0} [options]"
          
          opts.separator ""
          opts.separator "Options:"
          opts.on( "-i", "--id ID", "Manually specify the Agent ID" ) {|str| @options[:node_id] = str }
          opts.on( "-p", "--pid PIDFILE", "pid file path" ) {|str| @options[:pid_file] = str }
          opts.on( "--log LOGFILE", "log file path" ) {|str| @options[:log_file] = str }
          opts.on( "--config CONFFILE", "config file path" ) {|str| @options[:config_file] = str }
          opts.on( "-s", "--server AMQP_URI", "amqp broker server to connect" ) {|str|
            begin
              @options[:amqp_server_uri] = URI.parse(str)
            rescue URI::InvalidURIError => e
              abort "#{e}"
            end
          }
          opts.on("-b", "Run in background" ) { @options[:daemonize] = false }
        end

        optparse.parse!(args)
      end
      
      def run(manifest=nil, opts={}, &blk)
        @options = @options.merge(opts)
        optparse(ARGV.dup)
        
        if manifest.is_a?(String)
          # load manifest file
          manifest = Manifest.load_file(manifest)
        elsif manifest.nil? && @options[:manifest_path]
          manifest = Manifest.load_file(@options[:manifest_path])
        end

        if @options[:node_id]
          # force overwrite node_id if the command line arg was given.
          manifest.node_instance_id(@options[:node_id])
        elsif manifest.node_id.nil?
          # nobody specified the node_id then set the ID in the
          # default manner. 
          manifest.node_id(default_node_id)
        end

        @options[:log_file] ||= "/var/log/%s.log" % [manifest.node_name]
        @options[:pid_file] ||= "/var/run/%s.pid" % [manifest.node_name]

        if @options[:daemonize]
          if @options[:log_file]
            logio = File.open(@options[:log_file], "a")
          end
          Daemonize.daemonize(logio || STDOUT)
        end

        # EM's reactor is shutdown already when EXIT signal is
        # caught. so that set handler for TERM, INT
        %w(TERM INT).each { |i|
          Signal.trap(i) {
            if @node
              # force the block to push next loop.
              # EM.schedule gets the current thread stucked.
              EventMachine.next_tick {
                @node.close { EventMachine.stop }
                @node = nil
              }
            end
          }
        }
        Signal.trap(:EXIT) { remove_pidfile if @options[:daemonize] }

        EventMachine.epoll
        EventMachine.run {
          @node = run_main(manifest, &blk)
          raise "run_main() must return Isono::Node object: #{@node.class}" unless @node.is_a?(Isono::Node)
        }
      end

      protected
      def run_main(manifest, &blk)
        Isono::Node.new(manifest).connect(@options[:amqp_server_uri]) { |n| 
          @node = n
          self.instance_eval &blk
        }
      end
      
      def default_node_id
        raise NotImplementedError
      end

    end

  end
end
