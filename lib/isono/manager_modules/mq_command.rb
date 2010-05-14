
module Isono
  module ManagerModules
    class MqCommand < Base

      def on_init(args)
        #agent.identity_queue('command-provider', args[:])
        
        agent.amq.fanout('command')

        CommandTable.instance.namespaces.keys.each { |ns|
          register(ns)
        }

        CommandTable.instance.add_observer(:registered) { |data|
          register(data[:namespace])
        }
      end

      def on_terminate
        CommandTable.instance.namespaces.keys.each { |ns|
          agent.amq.queue('command-provider.#{ns}').delete
        }
      end

      def register(namespace)
        queue = begin
                  agent.amq.queue("command-provider.#{namespace}", {:exclusive=>true}).bind('command')
                rescue MQ::Error => e
                  logger.error("the namespace of command provider is already acting: #{namespace}")
                  raise e
                end
        
        queue.subscribe { |data|
          data = Serializer.instance.unmarshal(data)
          keytable = CommandTable.instance.namespaces[data[:namespace]]
          next unless keytable

          keytable.dispatch(data[:key], data[:args])
        }
      end

      def send(namespace, command, args={})
        msg = {:namespace=>namespace, :key=>command, :args=>args}
        agent.amq.fanout('command').publish(Serializer.instance.marshal(msg))
      end

    end
  end
end
