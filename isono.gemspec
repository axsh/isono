# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{isono}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.date = %q{2010-08-11}
  s.description = %q{}
  s.executables = ["agent", "cli", "resource_instance"]
  s.files = ["bin/resource_instance", "bin/agent", "bin/cli", "lib/ext/shellwords.rb", "lib/isono.rb", "lib/isono/logger.rb", "lib/isono/messaging_client.rb", "lib/isono/resource_manifest.rb", "lib/isono/manager_host.rb", "lib/isono/manifest.rb", "lib/isono/event_delegate_context.rb", "lib/isono/manager_modules/file_receiver_channel.rb", "lib/isono/manager_modules/file_sender_channel.rb", "lib/isono/manager_modules/base.rb", "lib/isono/manager_modules/agent_heartbeat.rb", "lib/isono/manager_modules/resource_instance.rb", "lib/isono/manager_modules/resource_locator.rb", "lib/isono/manager_modules/event_logger.rb", "lib/isono/manager_modules/event_channel.rb", "lib/isono/manager_modules/data_store.rb", "lib/isono/manager_modules/rpc_channel.rb", "lib/isono/manager_modules/resource_loader.rb", "lib/isono/manager_modules/agent_collector.rb", "lib/isono/amqp_client.rb", "lib/isono/serializer.rb", "lib/isono/agent.rb", "lib/isono/event_router.rb", "lib/isono/models/agent_pool.rb", "lib/isono/models/resource_instance.rb", "lib/isono/models/event_log.rb", "lib/isono/daemonize.rb", "lib/isono/command_table.rb", "lib/isono/util.rb", "lib/isono/monitors/base.rb", "lib/isono/thread_pool.rb", "lib/isono/runner/agent.rb", "lib/isono/event_observable.rb", "isono.gemspec"]
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.6")
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<amqp>, [">= 0.6.7"])
      s.add_runtime_dependency(%q<eventmachine>, [">= 0.12.10"])
      s.add_runtime_dependency(%q<statemachine>, [">= 1.0.0"])
      s.add_development_dependency(%q<bacon>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
    else
      s.add_dependency(%q<amqp>, [">= 0.6.7"])
      s.add_dependency(%q<eventmachine>, [">= 0.12.10"])
      s.add_dependency(%q<statemachine>, [">= 1.0.0"])
      s.add_dependency(%q<bacon>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
    end
  else
    s.add_dependency(%q<amqp>, [">= 0.6.7"])
    s.add_dependency(%q<eventmachine>, [">= 0.12.10"])
    s.add_dependency(%q<statemachine>, [">= 1.0.0"])
    s.add_dependency(%q<bacon>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
  end
end
