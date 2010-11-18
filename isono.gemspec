# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{isono}
  s.version = "0.1.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["axsh Ltd.", "Masahiro Fujiwara"]
  s.date = %q{2010-11-18}
  s.default_executable = %q{cli}
  s.email = ["dev@axsh.net", "m-fujiwara@axsh.net"]
  s.executables = ["cli"]
  s.files = ["bin/cli", "lib/ext/shellwords.rb", "lib/isono.rb", "lib/isono/rack/object_method.rb", "lib/isono/rack/proc.rb", "lib/isono/rack/data_store.rb", "lib/isono/rack/map.rb", "lib/isono/rack/job.rb", "lib/isono/rack/builder.rb", "lib/isono/rack/thread_pass.rb", "lib/isono/logger.rb", "lib/isono/rack.rb", "lib/isono/messaging_client.rb", "lib/isono/resource_manifest.rb", "lib/isono/node.rb", "lib/isono/manifest.rb", "lib/isono/event_delegate_context.rb", "lib/isono/amqp_client.rb", "lib/isono/node_modules/job_channel.rb", "lib/isono/node_modules/base.rb", "lib/isono/node_modules/event_logger.rb", "lib/isono/node_modules/event_channel.rb", "lib/isono/node_modules/node_heartbeat.rb", "lib/isono/node_modules/node_collector.rb", "lib/isono/node_modules/data_store.rb", "lib/isono/node_modules/job_collector.rb", "lib/isono/node_modules/rpc_channel.rb", "lib/isono/node_modules/job_worker.rb", "lib/isono/serializer.rb", "lib/isono/models/node_state.rb", "lib/isono/models/resource_instance.rb", "lib/isono/models/event_log.rb", "lib/isono/models/job_state.rb", "lib/isono/daemonize.rb", "lib/isono/util.rb", "lib/isono/thread_pool.rb", "lib/isono/runner/rpc_server.rb", "lib/isono/runner/agent.rb", "lib/isono/event_observable.rb", "isono.gemspec", "LICENSE", "NOTICE"]
  s.homepage = %q{http://github.com/axsh/isono}
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.7")
  s.rubygems_version = %q{1.3.6}
  s.summary = %q{Messageing and agent fabric}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<amqp>, [">= 0.6.7"])
      s.add_runtime_dependency(%q<eventmachine>, [">= 0.12.10"])
      s.add_runtime_dependency(%q<statemachine>, [">= 1.0.0"])
      s.add_runtime_dependency(%q<log4r>, [">= 0"])
      s.add_development_dependency(%q<bacon>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
    else
      s.add_dependency(%q<amqp>, [">= 0.6.7"])
      s.add_dependency(%q<eventmachine>, [">= 0.12.10"])
      s.add_dependency(%q<statemachine>, [">= 1.0.0"])
      s.add_dependency(%q<log4r>, [">= 0"])
      s.add_dependency(%q<bacon>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
    end
  else
    s.add_dependency(%q<amqp>, [">= 0.6.7"])
    s.add_dependency(%q<eventmachine>, [">= 0.12.10"])
    s.add_dependency(%q<statemachine>, [">= 1.0.0"])
    s.add_dependency(%q<log4r>, [">= 0"])
    s.add_dependency(%q<bacon>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
  end
end
