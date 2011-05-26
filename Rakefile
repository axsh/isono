# -*- coding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'isono/version'


task :gem do
  require 'rubygems'
  require 'rake/gempackagetask'
  
  spec = Gem::Specification.new do |s|
    s.platform = Gem::Platform::RUBY
    s.version = Isono::VERSION
    s.authors = ['axsh Ltd.', 'Masahiro Fujiwara']
    s.email = ['dev@axsh.net', 'm-fujiwara@axsh.net']
    s.homepage = 'http://github.com/axsh/isono'
    s.summary = 'Messaging and agent fabric'
    s.name = 'isono'
    s.require_path = 'lib'
    s.required_ruby_version = '>= 1.8.7'
    s.rubyforge_project = 'isono'
    
    s.files = `git ls-files -c`.split("\n")
    
    s.bindir='bin'
    s.executables = %w(cli)
    
    s.add_dependency "amqp", "0.7.0"
    s.add_dependency "eventmachine", "1.0.0.beta.3"
    s.add_dependency "statemachine", ">= 1.0.0"
    s.add_dependency "log4r"

    s.add_development_dependency 'bacon'
    s.add_development_dependency 'rake'
  end

  File.open('isono.gemspec', 'w'){|f| f.write(spec.to_ruby) }
  sh "gem build isono.gemspec"
end
