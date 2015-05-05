lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rails-perfmon/version'

Gem::Specification.new do |spec|
  spec.name          = "rails-perfmon"
  spec.version       = RailsPerfmon::VERSION
  spec.authors       = ["Yan-hoose"]
  spec.email         = ["jaanus@jjvarad.eu"]
  spec.summary       = 'Performance monitoring for your Rails apps.'
  spec.description   = 'This gem, coupled with the monitoring app, will give you performance insights into your Rails app.'
  spec.homepage      = "https://github.com/yan-hoose/rails-perfmon"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", "~> 4.0"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.2"
  spec.add_development_dependency "timecop", "~> 0.7.3"
end
