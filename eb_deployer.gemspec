# -*- encoding: utf-8 -*-
require File.expand_path('../lib/eb_deployer/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["wpc", "betarelease", "xli"]
  gem.email         = ["alex.hal9000@gmail.com", "sudhindra.r.rao@gmail.com", 'swing1979@gmail.com']
  gem.description   = %q{For automating Blue-Green deployment flows on Elastic Beanstalk.}
  gem.summary       = %q{Low friction deployments should be a breeze. Elastic Beanstalk provides a great foundation for performing Blue-Green deployments, and EbDeployer add a missing top to automate the whole flow out of the box.}
  gem.homepage      = "https://github.com/ThoughtWorksStudios/eb_deployer"
  gem.license       = 'MIT'

  gem.add_runtime_dependency 'aws-sdk', '~> 2',  '>= 2.0.0'

  gem.files         = `git ls-files`.split($\).reject {|f| f =~ /^samples\// }
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "eb_deployer"
  gem.require_paths = ["lib"]
  gem.version       = EbDeployer::VERSION
end
