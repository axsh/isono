require File.expand_path('../spec_helper', __FILE__)

require 'isono'

class LoggerA
  include Isono::Logger

  class LoggerA1
    include Isono::Logger
  end
end

class LoggerB  < LoggerA
  include Isono::Logger
end

describe "Logger Test" do

  it "call logger method" do
    a = LoggerA.new
    a.logger.should_not nil
  end

  it "call logger instance methods" do
    l = LoggerA.new
    l.logger.debug("DEBUG")
    l.logger.warn("WARN")
    l.logger.info("INFO")

    l1 = LoggerA::LoggerA1.new
    l1.logger.debug("DEBUG")

    l1.logger.should.not l.logger
  end

  it "call logger inherited instance methods" do
    l = LoggerB.new
    l.logger.debug("DEBUG")
    l.logger.warn("WARN")
    l.logger.info("INFO")

    l.logger.should
  end

end
