
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'isono'


task :gem do
  require 'rubygems'
  require 'rake/gempackagetask'
  
  spec = Gem::Specification.new do |s|
    s.platform = Gem::Platform::RUBY
    s.version = Isono::VERSION
    s.summary = ""
    s.name = 'isono'
    s.require_path = 'lib'
    s.required_ruby_version = '>= 1.8.6'
    
    s.files = Dir['{bin/*,lib/**/*.rb}'] +
      %w(isono.gemspec)
    
    s.bindir='bin'
    s.executables = %w(agent cli resource_instance)
    
    s.add_dependency "amqp", ">= 0.6.7"
    s.add_dependency "eventmachine", ">= 0.12.10"
    s.add_dependency "statemachine", ">= 1.0.0"

    s.add_development_dependency 'bacon'
    s.add_development_dependency 'rake'
    
    s.description = <<-EOF
EOF
  end

  File.open('isono.gemspec', 'w'){|f| f.write(spec.to_ruby) }
  sh "gem build isono.gemspec"
end
