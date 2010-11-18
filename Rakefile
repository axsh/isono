# -*- coding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'isono'


task :gem do
  require 'rubygems'
  require 'rake/gempackagetask'
  
  spec = Gem::Specification.new do |s|
    s.platform = Gem::Platform::RUBY
    s.version = Isono::VERSION
    s.authors = ['axsh Ltd.', 'Masahiro Fujiwara']
    s.email = ['dev@axsh.net', 'm-fujiwara@axsh.net']
    s.homepage = 'http://github.com/axsh/isono'
    s.summary = 'Messageing and agent fabric'
    s.name = 'isono'
    s.require_path = 'lib'
    s.required_ruby_version = '>= 1.8.7'
    
    s.files = Dir['{bin/*,lib/**/*.rb}'] +
      %w(isono.gemspec LICENSE NOTICE)
    
    s.bindir='bin'
    s.executables = %w(cli)
    
    s.add_dependency "amqp", ">= 0.6.7"
    s.add_dependency "eventmachine", ">= 0.12.10"
    s.add_dependency "statemachine", ">= 1.0.0"
    s.add_dependency "log4r"

    s.add_development_dependency 'bacon'
    s.add_development_dependency 'rake'
  end

  File.open('isono.gemspec', 'w'){|f| f.write(spec.to_ruby) }
  sh "gem build isono.gemspec"
end
