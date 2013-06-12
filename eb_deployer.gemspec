# -*- encoding: utf-8 -*-
require File.expand_path('../lib/eb_deployer/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["wpc", "betarelease"]
  gem.email         = ["alex.hal9000@gmail.com", "sudhindra.r.rao@gmail.com"]
  gem.description   = %q{Elastic Beanstalk Deployer with different deployment strategies.}
  gem.summary       = %q{Pick strategies like InplaceUpdate, Blue/Green.}
  gem.homepage      = "https://github.com/ThoughtWorksStudios/eb_deployer"

  gem.add_runtime_dependency 'aws-sdk'
  gem.add_development_dependency 'minitest'

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "eb_deployer"
  gem.require_paths = ["lib"]
  gem.version       = EbDeployer::VERSION
end
