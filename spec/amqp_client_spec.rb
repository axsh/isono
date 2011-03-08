
require File.expand_path('../spec_helper', __FILE__)

require 'isono'

class A
  include Isono::AmqpClient
end

describe Isono::AmqpClient do

  em "connects with default args" do
    a = A.new
    a.connect('amqp://localhost/') {
      a.connected?.should.be.true?
      a.amqp_client.should.not.nil?
      EM.next_tick {
      puts "here"
        a.close {
          1.should.equal 1
          EM.stop
        }
      }
    }
  end

  em 'run with hook methods' do
    a = A.new
    a.instance_eval {
      @checklist = []
      def before_connect
        connected?.should.be.false?
        checklist << :before_connect
      end

      def after_connect
        connected?.should.be.true?
        checklist << :after_connect
      end

      def before_close
        connected?.should.be.true?
        checklist << :before_close
      end

      def after_close
        connected?.should.be.true?
        checklist << :after_close
      end

      def checklist
        @checklist
      end
    }
    a.connect('amqp://localhost/') {
      EM.next_tick {
        a.close {
          a.checklist.member?(:before_connect).should.be.true?
          a.checklist.member?(:after_connect).should.be.true?
          a.checklist.member?(:before_close).should.be.true?
          a.checklist.member?(:after_close).should.be.true?
          EM.stop
        }
      }
    }
    
    a.amqp_client.should.not.nil?
    a.amqp_client.instance_variable_get(:@connection_status).should.is_a?(Proc)
  end

end
