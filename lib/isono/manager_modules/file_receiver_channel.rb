# -*- coding: utf-8 -*-

require 'statemachine'
require 'tempfile'
require 'fileutils'

module Isono
  module ManagerModules
    class FileReceiverChannel < Base
      include Logger
      include EventObservable
      attr_reader :receiver_thread, :inprogress


      config_section do |config|
        config.buffer_dir ''
        config.complete_dir ''
      end
      
      def on_init(args)
        initialize_event_observable
        agent.amq.direct('file')
        agent.amq.direct('file-pull-req')
        
        @receiver_thread = ThreadPool.new(1, self.class.to_s)

        @inprogress = {}
        
        FileUtils.mkpath(config_section.buffer_dir) unless File.directory?(config_section.buffer_dir)
        FileUtils.mkpath(config_section.complete_dir) unless File.directory?(config_section.complete_dir)

        agent.amq.queue("filerecv.#{agent.agent_id}", {:exclusive=>true}).bind('file', {:key=>"filerecv.#{agent.agent_id}"}).subscribe { |data|
          data = Marshal.load(data)

          @receiver_thread.pass {
            #logger.debug("#{data[:type]}, #{data[:ticket]}, #{@inprogress.keys.inspect}")
            rc = @inprogress[data[:ticket]]

            case data[:type]
            when :chunk
              raise "" if rc.nil?
              rc.process_event(:on_chunk, data[:chunk])
            when :bof
              # the context object is already made if it is pull request.
              if rc.nil?
                rc = create_recv_context(data[:ticket])
              end

              rc.process_event(:on_bof, data)
            when :eof
              raise "" if rc.nil?
              rc.process_event(:on_eof) #rescue puts "error :on_eof"
                
            when :fail
              raise "" if rc.nil?
              rc.process_event(:on_fail)
            else
              logger.error("Unknown state: #{data[:type]}:  #{data.inspect}")
            end

            clean_inprogress_list
          }

        }

      end

      def on_terminate
        @receiver_thread.shutdown
      end

      def pull(remote_path, repos_id=nil, opts={}, &blk)
        if repos_id.nil?
          repos_id, remote_path = remote_path.split(':', 2)
        end

        raise "repos_id is not set" unless repos_id && remote_path

        ticket = Util.gen_id(agent.agent_id + repos_id + remote_path)
        rc = create_recv_context(ticket)

        blk.call(rc) if blk

        msg = {:ticket=>ticket, :path=>remote_path, :receiver=>agent.agent_id}
        EventMachine.schedule {
          agent.amq.direct('file-pull-req').publish(Marshal.dump(msg), {:key=>"filerepos.#{repos_id}"})
          logger.debug("send pull request to the repository \"#{repos_id}\": #{msg.inspect}")
        }
        rc
      end

      private
      # clean @inprogress list
      def clean_inprogress_list
        @inprogress.delete_if { |k, v|
          if v.state == :close
            fire_event(:on_destroy_receive_context, v)
            true
          end
        }
      end


      def create_recv_context(ticket)
        rc = @inprogress[ticket] = ReceiveContext.new(ticket, self)
        fire_event(:on_create_receive_context, rc)
        rc
      end

      class ReceiveContext
        include Logger
        include EventObservable
        attr_reader :ticket, :size, :checksum
        
        def initialize(ticket, receiver)
          set_instance_logger
          initialize_event_observable
          @ticket = ticket
          @receiver = receiver

          @st = Statemachine.build {
            startstate :open
            trans :open,   :on_bof,  :middle, :on_bof
            trans :middle, :on_chunk, :middle, :on_chunk
            trans :open,   :on_eof,  :close, :on_eof
            trans :middle, :on_eof,  :close, :on_eof
            trans :middle, :on_fail, :close, :on_fail
            trans :open,   :on_fail, :close, :on_fail
          }
          @st.context = self
        end

        def state
          @st.state
        end

        def process_event(ev, *args)
          @st.process_event(ev, *args)
        end

        def tmp_file_path
          @io.path
        end

        private
        def on_bof(bof)
          @size     = bof[:size].to_i
          @checksum = bof[:checksum]

          @io = Tempfile.new(@ticket, @receiver.config_section.buffer_dir)
          
          logger.debug("#{@ticket}: start receiving: #{@size} bytes")
          fire_event(:on_bof, self)
        rescue => e
          logger.error(e)
          @st.process_event(:on_fail)
        end

        def on_chunk(buf)
          @io.write(buf)
          fire_event(:on_chunk, self)
        end

        def on_eof
          @io.flush

          unless File.size(@io.path) == @size
            raise "file size is wrong: #{self}"
          end

          if @checksum
            localsum = `md5sum -b '#{@io.path}'`.split.first
            unless localsum == @checksum
              raise "checksum is wrong: src=#{@checksum}, local=#{localsum}"
            end
          end

          fire_event(:on_eof, self)

          @io.close(true)
          logger.debug("#{@ticket}: file uploaded successfully")
        end

        def on_fail
          @io.close if @io
          logger.error("#{@ticket}: failed to receive")
          fire_event(:on_fail, self)
        end


        private
        def copy_tmpfile_to_dir(path)
          # rename to @dst_path
          real_dst_path = File.expand_path(path, @receiver.config_section.complete_dir)
          basedir = File.dirname(real_dst_path)
          FileUtils.mkpath(basedir) unless File.directory?(basedir)
          
          
          #File.rename(@io.path, real_dst_path)
          FileUtils.copy_file(@io.path, real_dst_path)
          FileUtils.chmod(0644, real_dst_path)
        end
      end
      
    end
  end
end
