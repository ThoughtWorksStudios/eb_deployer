# EbDeployer

Low friction deployments should be a breeze. Elastic Beanstalk provides a great foundation for performing Blue-Green deployments, and EbDeployer add a missing top to automate the whole flow out of box.


## Installation

Add this line to your application's Gemfile:

    gem 'eb_deployer'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install eb_deployer

## Usage

### Step One: AWS Account Setup

Create an AWS IAM user for deploy and give it privilege to operate Elastic Beanstalk. Download the access keys for executing the deployment tasks later.

### Step Two: Packaging

You need package your application for Elastic Beanstalk stack first. For Java app an warball is appropriate. For Ruby on Rails app a tar.gz file is good. You can also package a Rails/Sinatra app as war ball using warbler and deploy to Java stack.


### Step Three: Define the task
Add a deploy task for deployment in your Rakefile

    require 'digest'

    desc "deploy our beloved app to elastic beanstalk"
    task :deploy, [:package] do |t, args|
      EbDeployer.deploy(:application => "MYAPP",
                        :environment => "production",
                        :solution_stack_name => <SOLUTION_STACK_NAME>
                        :package => args[:package],
                        :version_label => "dev-" + Digest::MD5.file(args[:package]).hexdigest)
    end

### Step Four: Fasten your seat belt
run deploy task:

    rake deploy[<package built>] AWS_ACCESS_KEY_ID=<deployers_aws_key> AWS_SECRET_ACCESS_KEY=<secret>
Then open aws console for Elastic Beanstalk to see what happened.

Later tutorials coming soon will cover
* blue green switch and how it works
* how to add smoke test which will run between blue green switch
* how to setup multiple environment suites: production, staging, and how to manage configurations for them
* how to setup RDS or other AWS resource and share them between blue green environments

Take a look at code if you can not wait for the documentation.


## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
