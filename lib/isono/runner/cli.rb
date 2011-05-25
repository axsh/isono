# encoding: utf-8

require 'isono'

module Isono
  module Runner
    module CLI
      
      def run_cli(manifest=nil, &blk)
        Oneshot.new.run(manifest, &blk)
      end
      module_function :run_cli

      class Oneshot < Runner::Base
        include Logger
        
        def run_main(manifest, &blk)
          Isono::Node.new(manifest).connect(@options[:amqp_server_uri]) do |n|
            exit(1) unless n.connected?
            @node = n
            self.instance_eval &blk
          end
        end
      end
      
    end
  end
end
