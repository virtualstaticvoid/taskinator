# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'taskinator/version'

Gem::Specification.new do |spec|
  spec.name          = 'taskinator'
  spec.version       = Taskinator::VERSION
  spec.authors       = ['Chris Stefano']
  spec.email         = ['virtualstaticvoid@gmail.com']
  spec.description   = %q{Simple process orchestration}
  spec.summary       = %q{A simple orchestration library for running complex processes or workflows in Ruby}
  spec.homepage      = 'https://github.com/virtualstaticvoid/taskinator'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.0.0'

  # core
  spec.add_dependency 'redis', '>= 3.0.6'
  spec.add_dependency 'redis-namespace', '>= 1.3.1'
  spec.add_dependency 'connection_pool', '>= 2.0.0'
  spec.add_dependency 'json', '>= 1.8.1'
  # spec.add_dependency 'workflow', '>= 1.1.0'  # gem currently out of date...

  # queues
  spec.add_development_dependency 'sidekiq', '>= 3.0.0'
  spec.add_development_dependency 'delayed_job', '>= 4.0.0'
  spec.add_development_dependency 'resque', '>= 1.25.2'
  spec.add_development_dependency 'resque_spec', '>= 0.16.0'

  # other
  spec.add_development_dependency 'bundler', '~> 1.6.0'
  spec.add_development_dependency 'rake', '~> 10.3.0'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'coveralls', '~> 0.7.0'
  spec.add_development_dependency 'pry', '~> 0.9.0'
  spec.add_development_dependency 'pry-byebug', '~> 1.3.0'
end
