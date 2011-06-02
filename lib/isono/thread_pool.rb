# -*- coding: utf-8 -*-
require 'thread'

module Isono
  class ThreadPool
    include Logger

    class WorkerTerminateError < StandardError; end
    class TimeoutError < StandardError; end

    attr_reader :queue, :name
    
    def initialize(worker_num=1, name=nil, opts={})
      @queue = ::Queue.new
      @name = name
      @opts = {:stucked_queue_num=>20}.merge(opts)
      @last_stuck_warn_at = Time.now
      
      @worker_threads = {}
      worker_num.times { |wid|
        t = Thread.new {
          # Log4r::PatternFormatter can refer thread name as %h.
          Thread.current[:name] = "#{name}[#{wid}/#{worker_num}]" if name
          begin
            while op = @queue.pop
              if @queue.size > @opts[:stucked_queue_num] && Time.now - @last_stuck_warn_at > 30.0
                logger.warn("too many stucked jobs: #{@queue.size}")
                @last_stuck_warn_at = Time.now
              end

              op_start_at = Time.now
              op.call
              op_elapsed = Time.now - op_start_at
              on_task_end(op_start_at, op_elapsed)
            end
          rescue WorkerTerminateError
            # someone indicated to terminate this thread
            # exit from the current loop
            break
          rescue ::Exception => e
            logger.error(e)
            # worker thread should never die except from the
            # termination using shutdown() method.
            # any errors thrown by op.call will be caught here and
            # back to @queue.pop.
            retry
          ensure
            tid = Thread.current.__id__
            tname = Thread.current[:name] || Thread.current.to_s
            EM.schedule {
              @worker_threads.delete(tid)
              logger.info("Thread #{tname} is being terminated")
            }
          end
          
        }
        @worker_threads[t.__id__] = t
      }
    end

    # Pass a block to a worker thread. The job is queued until the
    # worker thread found.
    # @param [Bool] immediage
    # @param [Proc] blk A block to be proccessed on a worker thread.
    def pass(immediate=true, &blk)
      if immediate && member_thread?
        return blk.call
      end
      
      @queue << blk
    end

    # Send a block to a worker thread similar with pass(). but this
    # get the caller thread waited until the block proceeded in a
    # worker thread.
    # @param [Bool] immediage
    # @param [Float] time_out 
    # @param [Proc] blk
    def barrier(immediate=true, time_out=nil, &blk)
      if immediate && member_thread?
        return blk.call
      end
      
      q = ::Queue.new
      time_start = ::Time.now
      
      self.pass {
        begin
          q << blk.call
        rescue Exception => e
          q << e
        end
      }

      em_sig = nil
      if time_out
        em_sig = EventMachine.add_timer(time_out) {
          q << TimeoutError.new
        }
      end
      
      res = q.shift
      EventMachine.cancel_timer(em_sig)
      time_elapsed = ::Time.now - time_start
      logger.debug("Elapsed time for #{blk}: #{time_elapsed} secs") if time_elapsed > 0.05
      if res.is_a?(Exception)
        raise res
      end
      res
      
    end

    def clear
      @queue.clear
    end

    # Immediatly shutdown all the worker threads
    def shutdown()
      @worker_threads.each {|id, t|
        t.__send__(:raise, WorkerTerminateError)
        Thread.pass
      }
    end

    def member_thread?(thread=Thread.current)
      @worker_threads.has_key?(thread.__id__)      
    end

    def shutdown_graceful(timeout)
      term_sig_q = ::Queue.new
      worker_num = @worker_threads.size
      # enqueue the terminate jobs.
      worker_num.times {
        @queue.push proc {
          term_sig_q.enq(1)
          raise WorkerTerminateError
        }
      }

      em_sig = nil
      if timeout > 0.0
        em_sig = EventMachine.add_timer(timeout) {
          worker_num.times {
            term_sig_q << TimeoutError.new
          }
        }
      end

      timeout_workers = 0
      while worker_num > 0
        if term_sig_q.deq.is_a?(TimeoutError)
          timeout_workers += 1
        end
        worker_num -= 1
      end

      logger.error("#{timeout_workers} of worker threads timed out during the cleanup") if timeout_workers > 0
    ensure
      shutdown
      EventMachine.cancel_timer(em_sig)
    end

    def graceful_shutdown2
      # make new jobs push to dummy queue.
      old_queue = @queue
      @queue = ::Queue.new
      # wait until @queue becomes empty
      if !old_queue.empty?
        logger.info("Waiting for #{old_queue.size} worker jobs in #{self}")
        while !old_queue.empty?
          sleep 1
        end
      end
    
      @worker_threads.each {|t|
        t.raise WorkerTerminateError
      }
    end

    
    private
    # This hook allows to log the task took too long time.
    # 
    # def on_task_end(op_start_at, op_elapsed)
    #   if op_elapsed > 10.0
    #     logger.warn("Task took 10sec")
    #   end
    # end
    def on_task_end(op_start_at, op_elapsed)
    end
     
  end
end
