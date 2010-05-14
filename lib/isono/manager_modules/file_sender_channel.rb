# -*- coding: utf-8 -*-

require 'statemachine'

module Isono
  module ManagerModules
    class FileSenderChannel < Base
      include Logger
      include EventObservable

      attr_reader :sender_thread
      
      def on_init(args)
        initialize_event_observable
        agent.amq.direct('file')
        agent.amq.direct('file-pull-req')

        @repositories  = {}
        @sender_thread = ThreadPool.new(2, self.class.to_s)
      end

      def on_terminate
        @sender_thread.shutdown
      end

      def add_pull_repository(basedir, repos_id=agent.agent_id)
        @repositories[repos_id] = basedir
        agent.amq.queue("filerepos.#{repos_id}", {:exclusive=>true}).bind('file-pull-req', {:key=>"filerepos.#{repos_id}"}).subscribe { |data|
          data = Marshal.load(data)
          real_path = File.expand_path('./' + data[:path], @repositories[repos_id])

          logger.info("pull request: #{data.inspect}")
          send(data[:receiver], real_path, data[:path], {:ticket=>data[:ticket]})
        }
        logger.info("pull repository: repos_id=#{repos_id}, dir=#{basedir}")
      end

      
      def send(receiver, src_path, dst_path=nil, opts={})
        c = create_sender(receiver, src_path, dst_path, opts)

        c.start_streaming
        c
      end

      def create_sender(receiver, src_path, dst_path=nil, opts={})
        c = SendContext.new(receiver, src_path, dst_path, opts, self)
      end

      class SendContext
        include Logger
        include EventObservable
        attr_reader :receiver, :src_path, :dst_path, :ticket
        
        def initialize(receiver, src_path, dst_path, opts, channel)
          set_instance_logger
          initialize_event_observable
          @receiver = receiver
          @src_path = src_path
          @dst_path = dst_path || src_path
          @channel  = channel
          @opts = {:read_size=>1024*16}.merge(opts)
          @ticket = @opts[:ticket] || Util.gen_id("#{@receiver}+#{@src_path}+#{@dst_path}")

          @size = File.size(@src_path)
          
          @st = Statemachine.build {
            startstate :init
            trans :init,   :on_bof,  :open
            trans :open,   :on_read,  :middle, :on_read
            trans :middle, :on_read, :middle, :on_read
            trans :open,   :on_eof,  :eof
            trans :middle, :on_eof,  :eof
            trans :open,   :on_fail, :fail
            trans :middle, :on_fail, :fail

            on_entry_of :open, :on_bof
            on_entry_of :eof,  :on_eof
            on_entry_of :fail, :on_fail
          }
          @st.context = self

        end

        def state
          @st.state
        end

        def start_streaming
          raise "already started the streaming: current state=#{@st.state}" if @st.state != :init
          unless @channel.sender_thread.member_thread?
            return @channel.sender_thread.pass { start_streaming }
          end

          @st.process_event(:on_bof)
        end

        def on_bof
          begin
            @io = File.open(@src_path, 'r')
          rescue SystemCallError => e
            logger.error("#{ticket}: failed to open file: #{@src_path}, #{e.class}")
            @st.process_event(:on_fail, e)
            return
          end

          bofdata = {:dst_path=>@dst_path, :size=>@size}

          if @opts[:checksum]
            bofdata[:checksum] = `md5sum -b '#{@src_path}'`.split.first
          end
          
          logger.debug("#{ticket}: start streaming: #{@src_path} to #{@receiver}:#{@dst_path}")
          
          send_packet(:bof, bofdata)
          fire_event(:on_bof, bofdata)

          # chain the first read
          @channel.sender_thread.pass(false) {
            @st.process_event(:on_read)
          }
        rescue => e
          @st.process_event(:on_fail, e)
        end
        
        def on_read
          if @size <= @io.pos
            @st.process_event(:on_eof)
            return
          else
            begin
              offset = @io.pos
              buf = @io.read(@opts[:read_size])

              # send chunk packet
              send_packet(:chunk, {:chunk=>buf, :offset=>offset})
              fire_event(:on_read, {:chunk=>buf, :offset=>offset})

              # chain the next read
              @channel.sender_thread.pass(false) {
                @st.process_event(:on_read)
              }
            rescue EOFError
              @st.process_event(:on_eof)
            rescue => e
              # catch runtime error
              @st.process_event(:on_fail, e)
            end
          end
        end

        def on_eof
          @io.close

          # send eof packet
          send_packet(:eof)
          fire_event(:on_eof)
          logger.debug("#{ticket}: end streaming: #{src_path} to #{receiver}:#{dst_path}")
        end

        def on_fail(err)
          @io.close if @io

          # send fail packet
          send_packet(:fail, {:msg=>err.to_s})
          fire_event(:on_fail, err)
          logger.error("#{ticket}: failed to stream: #{src_path} to #{receiver}:#{dst_path}")
        end

        private
        def send_packet(type, opts={})
          msg = {:type=>type, :ticket=>@ticket}.merge(opts)
          #logger.debug(msg.merge(:chunk=>(msg[:chunk].nil? ? 'nil' : 'some data')))
          EventMachine.schedule {
            @channel.agent.amq.direct('file').publish(Marshal.dump(msg), {:key=>"filerecv.#{receiver}"})
          }
        end
        
      end
      
    end
  end
end
