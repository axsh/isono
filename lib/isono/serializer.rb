
module Isono
  # AMQP message serializer
  class Serializer
    def self.instance
      @serializer ||= RubySerializer.new
    end

    def marshal(buf)
      raise NotImplementedError
    end

    def unmarshal(buf)
      raise NotImplementedError
    end
  end


  class YamlSerializer < Serializer
    def initialize
      require 'yaml'
    end
    
    def marshal(buf)
      YAML.dump(buf)
    end

    def unmarshal(buf)
      YAML.load(buf)
    end
  end

  class RubySerializer < Serializer
    
    def marshal(buf)
      ::Marshal.dump(buf)
    end

    def unmarshal(buf)
      ::Marshal.load(buf)
    end
  end
end
