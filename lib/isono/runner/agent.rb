# -*- coding: utf-8 -*-

require 'optparse'
require 'amqp'
require 'digest/sha1'

require 'isono/agent'

module Isono
  module Runner
    class Agent
      include Daemonize
      
      def initialize(argv)
        @argv = argv.dup
        
        @options = {
          :amqp_server_uri => URI.parse('amqp://guest:guest@localhost/'),
          :log_file => '/var/log/wakame-agent.log',
          :pid_file => '/var/run/wakame/wakame-agent.pid',
          :daemonize => true
        }
        
        parser.parse! @argv
      end
      
      
      def parser
        @parser ||= OptionParser.new do |opts|
          opts.banner = "Usage: agent [options]"
          
          opts.separator ""
          opts.separator "Agent options:"
          opts.on( "-i", "--id ID", "Manually specify the Agent ID" ) {|str| @options[:agent_id] = str }
          opts.on( "-p", "--pid PIDFILE", "pid file path" ) {|str| @options[:pid_file] = str }
          opts.on( "-s", "--server AMQP_URI", "amqp broker server to connect" ) {|str|
            begin
              @options[:amqp_server_uri] = URI.parse(str)
            rescue URI::InvalidURIError => e
              abort "#{e}"
            end
          }
          opts.on("-X", "Run in foreground" ) { @options[:daemonize] = false }
        end
      end

      
      def run(manifest_path=nil)
        #%w(QUIT INT TERM).each { |i|
        %w(EXIT).each { |i|
          Signal.trap(i) { Isono::Agent.stop{ remove_pidfile if @options[:daemonize]} }
        }

        if @options[:daemonize]
          daemonize(@options[:log_file])
        end

        #Initializer.run(:process_agent)

        # load manifest file
        manifest = Manifest.load_file(manifest_path.nil? ? @options[:manifest_path] : manifest_path)

        if @options[:node_id]
          # force overwrite node_id if the command line arg was given.
          manifest.node_id(@options[:node_id])
        elsif manifest.node_id.nil?
          # nobody specified the node_id then set the ID in the
          # default manner. 
          manifest.node_id(default_node_id)
        end
        
        #EM.epoll if Wakame.config.eventmachine_use_epoll
        EventMachine.epoll
        EventMachine.run {
          Isono::Agent.start(manifest, @options)
        }
      end

      private
      def default_node_id
        # use the ip address for the default routeas key value
        Digest::SHA1.hexdigest(`/sbin/ip route get 8.8.8.8`.split("\n")[0].split.last)[0, 10]
      end

    end

  end
end
