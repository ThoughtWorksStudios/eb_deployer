# EbDeployer

Low friction deployments should be a breeze. Elastic Beanstalk provides a great foundation for performing Blue-Green deployments, and EbDeployer add a missing top to automate the whole flow out of box.

ElasticBeanstalk Deployer thus allows you to do continuous delivery on AWS.

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


### Step Five: Smoke Testing your stack
EB_Deployer allows you to automate your deployment and then some. You can also add smoke tests to your deployment - thus ensuring that the app you deployed is also working correctly. 
Adding a smoke test suite is also simple. All that you need to do is edit your rake task as follows:

    desc "deploy our simple java app with one page"
    task :deploy, [:package] do |t, args|
      EbDeployer.deploy(:application => "MYAPP",
                        :environment => "production",
                        :solution_stack_name => <SOLUTION_STACK_NAME>
                        :package => args[:package],
                        :version_label => "dev-" + Digest::MD5.file(args[:package]).hexdigest)
                        :smoke_test => lambda { |host|
                          Timeout.timeout(600) do
                            until `curl http://#{host}`.include?('Hello, World')
                              sleep 5
                            end
                          end
                        })
    end                
You can add more smoke tests by calling arbitrary tasks from this rake task.
Smoke testing gets you one step closer to continuous delivery.
                      
### Step Six: Blue-Green deployment
Since every deployment now runs smoke test, you now have a better safety net around your deployments. This allows us to trigger automatic blue-green deployments. 

To do this you need not do anything special. So far we have deployed the application only once. Let's call this the 'green' stack. Any subsequent calls to deployment will deployment a copy of this application to a new stack - the 'blue' stack. Smoke tests will be run on it and once everything passes the 'blue'(new) stack will be switched to the 'green' stack. Thus your new code will now be on the active stack and the user will experience no downtime. 

Once this new stack is stable or has run for a while you can choose to delete the old stack. Or if you are doing continuous delivery you may be ready to another 'blue' deployment. You could just trigger another deployment and repeat this every hour/day/week... you get the idea.



### Destroying a stack
    desc "clean up everything"
    task :teardown do |t, args|
      EbDeployer.destroy(:application => "ebtest-simple")
    end
    
and you are done!

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
