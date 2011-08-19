# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{isono}
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = [%q{axsh Ltd.}, %q{Masahiro Fujiwara}]
  s.date = %q{2011-08-12}
  s.email = [%q{dev@axsh.net}, %q{m-fujiwara@axsh.net}]
  s.executables = [%q{cli}]
  s.files = [%q{.gitignore}, %q{LICENSE}, %q{NOTICE}, %q{Rakefile}, %q{bin/cli}, %q{isono.gemspec}, %q{lib/ext/shellwords.rb}, %q{lib/isono.rb}, %q{lib/isono/amqp_client.rb}, %q{lib/isono/daemonize.rb}, %q{lib/isono/event_delegate_context.rb}, %q{lib/isono/event_observable.rb}, %q{lib/isono/logger.rb}, %q{lib/isono/manifest.rb}, %q{lib/isono/messaging_client.rb}, %q{lib/isono/models/event_log.rb}, %q{lib/isono/models/job_state.rb}, %q{lib/isono/models/node_state.rb}, %q{lib/isono/models/resource_instance.rb}, %q{lib/isono/node.rb}, %q{lib/isono/node_modules/base.rb}, %q{lib/isono/node_modules/data_store.rb}, %q{lib/isono/node_modules/event_channel.rb}, %q{lib/isono/node_modules/event_logger.rb}, %q{lib/isono/node_modules/job_channel.rb}, %q{lib/isono/node_modules/job_collector.rb}, %q{lib/isono/node_modules/job_worker.rb}, %q{lib/isono/node_modules/node_collector.rb}, %q{lib/isono/node_modules/node_heartbeat.rb}, %q{lib/isono/node_modules/rpc_channel.rb}, %q{lib/isono/rack.rb}, %q{lib/isono/rack/builder.rb}, %q{lib/isono/rack/data_store.rb}, %q{lib/isono/rack/job.rb}, %q{lib/isono/rack/map.rb}, %q{lib/isono/rack/object_method.rb}, %q{lib/isono/rack/proc.rb}, %q{lib/isono/rack/thread_pass.rb}, %q{lib/isono/resource_manifest.rb}, %q{lib/isono/runner/base.rb}, %q{lib/isono/runner/cli.rb}, %q{lib/isono/runner/rpc_server.rb}, %q{lib/isono/serializer.rb}, %q{lib/isono/thread_pool.rb}, %q{lib/isono/util.rb}, %q{lib/isono/version.rb}, %q{spec/amqp_client_spec.rb}, %q{spec/event_observable_spec.rb}, %q{spec/file_channel_spec.rb}, %q{spec/job_channel_spec.rb}, %q{spec/logger_spec.rb}, %q{spec/manifest_spec.rb}, %q{spec/node_spec.rb}, %q{spec/resource_loader_spec.rb}, %q{spec/rpc_channel_spec.rb}, %q{spec/spec_helper.rb}, %q{spec/thread_pool_spec.rb}, %q{spec/util_spec.rb}, %q{tasks/load_resource_manifest.rake}]
  s.homepage = %q{http://github.com/axsh/isono}
  s.require_paths = [%q{lib}]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.7")
  s.rubyforge_project = %q{isono}
  s.rubygems_version = %q{1.8.6}
  s.summary = %q{Messaging and agent fabric}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<amqp>, ["= 0.7.4"])
      s.add_runtime_dependency(%q<eventmachine>, ["= 1.0.0.beta.3"])
      s.add_runtime_dependency(%q<statemachine>, [">= 1.0.0"])
      s.add_runtime_dependency(%q<log4r>, [">= 0"])
      s.add_development_dependency(%q<bacon>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
    else
      s.add_dependency(%q<amqp>, ["= 0.7.4"])
      s.add_dependency(%q<eventmachine>, ["= 1.0.0.beta.3"])
      s.add_dependency(%q<statemachine>, [">= 1.0.0"])
      s.add_dependency(%q<log4r>, [">= 0"])
      s.add_dependency(%q<bacon>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
    end
  else
    s.add_dependency(%q<amqp>, ["= 0.7.4"])
    s.add_dependency(%q<eventmachine>, ["= 1.0.0.beta.3"])
    s.add_dependency(%q<statemachine>, [">= 1.0.0"])
    s.add_dependency(%q<log4r>, [">= 0"])
    s.add_dependency(%q<bacon>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
  end
end
