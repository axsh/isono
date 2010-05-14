
module Isono
  # AMQP message serializer
  class Serializer
    def self.instance
      YamlSerializer.new
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
end
