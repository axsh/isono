# -*- coding: utf-8 -*-

require 'log4r'

module Isono
  # Injects +logger+ method to the included class.
  # The output message from the logger methods starts the module name trailing message body.
  module Logger
    @rootlogger = Log4r::Logger.new('Isono')

    def self.initialize(l4r_output=Log4r::StdoutOutputter.new('stdout'))
      # Isono top level logger
      formatter = Log4r::PatternFormatter.new(:depth => 9999, # stack trace depth
                                              :pattern => "%d %c [%l]: %M",
                                              :date_format => "%Y/%m/%d %H:%M:%S"
                                              )
      l4r_output.formatter = formatter
      @rootlogger.outputters = l4r_output
    end

    def self.included(klass)
      klass.class_eval {

        @class_logger = Log4r::Logger.new(klass.to_s)

        def self.logger
          @class_logger
        end

        def logger
          @instance_logger || self.class.logger
        end
        
        def self.logger_name
          @class_logger.path
        end

        #def self.logger_name=(name)
        #  @logger_name = name
        #end

        def set_instance_logger(suffix=nil)
          suffix ||= self.__id__.abs.to_s(16)
          @instance_logger = Log4r::Logger.new("#{self.class} for #{suffix}")
        end
      }
    end

  end

  # Set STDOUT as the default log output.
  # To replace another log device, put the line below at the top of
  # your code:
  #  Isono::Logger.initialize(Log4r::SyslogOutputter.new('mysyslog'))
  # To disable any of log output:
  #  Isono::Logger.initialize(Log4r::Outputter.new('null'))
  Logger.initialize
end
