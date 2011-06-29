# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{isono}
  s.version = "0.2.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["axsh Ltd.", "Masahiro Fujiwara"]
  s.date = %q{2011-06-29}
  s.default_executable = %q{cli}
  s.email = ["dev@axsh.net", "m-fujiwara@axsh.net"]
  s.executables = ["cli"]
  s.files = [".gitignore", "LICENSE", "NOTICE", "Rakefile", "bin/cli", "isono.gemspec", "lib/ext/shellwords.rb", "lib/isono.rb", "lib/isono/amqp_client.rb", "lib/isono/daemonize.rb", "lib/isono/event_delegate_context.rb", "lib/isono/event_observable.rb", "lib/isono/logger.rb", "lib/isono/manifest.rb", "lib/isono/messaging_client.rb", "lib/isono/models/event_log.rb", "lib/isono/models/job_state.rb", "lib/isono/models/node_state.rb", "lib/isono/models/resource_instance.rb", "lib/isono/node.rb", "lib/isono/node_modules/base.rb", "lib/isono/node_modules/data_store.rb", "lib/isono/node_modules/event_channel.rb", "lib/isono/node_modules/event_logger.rb", "lib/isono/node_modules/job_channel.rb", "lib/isono/node_modules/job_collector.rb", "lib/isono/node_modules/job_worker.rb", "lib/isono/node_modules/node_collector.rb", "lib/isono/node_modules/node_heartbeat.rb", "lib/isono/node_modules/rpc_channel.rb", "lib/isono/rack.rb", "lib/isono/rack/builder.rb", "lib/isono/rack/data_store.rb", "lib/isono/rack/job.rb", "lib/isono/rack/map.rb", "lib/isono/rack/object_method.rb", "lib/isono/rack/proc.rb", "lib/isono/rack/thread_pass.rb", "lib/isono/resource_manifest.rb", "lib/isono/runner/base.rb", "lib/isono/runner/cli.rb", "lib/isono/runner/rpc_server.rb", "lib/isono/serializer.rb", "lib/isono/thread_pool.rb", "lib/isono/util.rb", "lib/isono/version.rb", "spec/amqp_client_spec.rb", "spec/event_observable_spec.rb", "spec/file_channel_spec.rb", "spec/job_channel_spec.rb", "spec/logger_spec.rb", "spec/manifest_spec.rb", "spec/node_spec.rb", "spec/resource_loader_spec.rb", "spec/rpc_channel_spec.rb", "spec/spec_helper.rb", "spec/thread_pool_spec.rb", "spec/util_spec.rb", "tasks/load_resource_manifest.rake"]
  s.homepage = %q{http://github.com/axsh/isono}
  s.require_paths = ["lib"]
  s.required_ruby_version = Gem::Requirement.new(">= 1.8.7")
  s.rubyforge_project = %q{isono}
  s.rubygems_version = %q{1.3.7}
  s.summary = %q{Messaging and agent fabric}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<amqp>, ["= 0.7.0"])
      s.add_runtime_dependency(%q<eventmachine>, ["= 1.0.0.beta.3"])
      s.add_runtime_dependency(%q<statemachine>, [">= 1.0.0"])
      s.add_runtime_dependency(%q<log4r>, [">= 0"])
      s.add_development_dependency(%q<bacon>, [">= 0"])
      s.add_development_dependency(%q<rake>, [">= 0"])
    else
      s.add_dependency(%q<amqp>, ["= 0.7.0"])
      s.add_dependency(%q<eventmachine>, ["= 1.0.0.beta.3"])
      s.add_dependency(%q<statemachine>, [">= 1.0.0"])
      s.add_dependency(%q<log4r>, [">= 0"])
      s.add_dependency(%q<bacon>, [">= 0"])
      s.add_dependency(%q<rake>, [">= 0"])
    end
  else
    s.add_dependency(%q<amqp>, ["= 0.7.0"])
    s.add_dependency(%q<eventmachine>, ["= 1.0.0.beta.3"])
    s.add_dependency(%q<statemachine>, [">= 1.0.0"])
    s.add_dependency(%q<log4r>, [">= 0"])
    s.add_dependency(%q<bacon>, [">= 0"])
    s.add_dependency(%q<rake>, [">= 0"])
  end
end
