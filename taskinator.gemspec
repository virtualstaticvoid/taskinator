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
  spec.add_dependency 'redis'                       , '>= 3.2.1'
  spec.add_dependency 'redis-namespace'             , '>= 1.5.2'
  spec.add_dependency 'connection_pool'             , '>= 2.2.0'
  spec.add_dependency 'json'                        , '>= 1.8.2'
  spec.add_dependency 'builder'                     , '>= 3.2.2'
  spec.add_dependency 'globalid'                    , '~> 0.3'
  spec.add_dependency 'statsd-ruby'                 , '~> 1.4.0'
  spec.add_dependency 'thwait'                      , '~> 0.2'

end
