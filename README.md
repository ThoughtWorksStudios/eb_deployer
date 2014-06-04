# EbDeployer [![Build Status](https://travis-ci.org/ThoughtWorksStudios/eb_deployer.png?branch=master)](https://travis-ci.org/ThoughtWorksStudios/eb_deployer)
[From Thoughtworks Mingle Team](http://getmingle.io)

Low friction deployments should be a breeze. Elastic Beanstalk provides a great foundation for performing Blue-Green deployments, and EbDeployer add a missing link to automate the whole flow out of box.

EbDeployer thus allows you to do continuous delivery on AWS.

## Installation

    $ gem install eb_deployer

## Usage

### Step One: AWS Account Setup

Create an AWS IAM user for deploy and give it privilege to operate Elastic Beanstalk. Download the access keys for executing the deployment tasks later. Ensure your command line is primed with appropriate access_keys using one of techniques mentioned on [aws blog](http://ruby.awsblog.com/blog/tag/config). For example using environment variable:

    $ export AWS_ACCESS_KEY_ID=xxx
    $ export AWS_SECRET_ACCESS_KEY=xxx


### Step Two: Packaging

You need to package your application for Elastic Beanstalk stack first. For Java app a warball is appropriate. For Ruby on Rails app a tar.gz file is good. You can also package a Rails/Sinatra app as a war ball using warbler and deploy to Java stack. (Please remember to run rake assets:precompile first for a rails app.)

If you were deploying to Elastic Beanstalk Ruby stack, simply zip your codebase is good enough, for example:

		$ git ls-files | zip your-app-name.zip -@

### Step Three: Generate configuration and Configure deployment process

    $ eb_deploy

This will generate a default configuration at location 'config/eb_deployer.yml'. It is almost empty but working one. And it will generate settings for two environments 'development' and 'production'. Some options can be tweaked. The yml files includes documentation on how you can best suit it to your purpose.


### Step Four: Fasten your seat belt
run deploy

    $ eb_deploy -p <package built> -e <environment>

Then open aws console for Elastic Beanstalk to see the result of this deployment.


### Conifgure Smoke Testing your stack

EB_Deployer allows you to automate your deployment and then some. You can also add smoke tests to your deployment - thus ensuring that the app you deployed is also working correctly.
Adding a smoke test suite is also simple. Check "smoke_test" section in your eb_deployer.yml. We show a simple curl based smoke test that helps you test if your app is up and responding to http.

    smoke_test: |
      curl_http_code = "curl -s -o /dev/null -w \"%{http_code}\" http://#{host_name}"
      Timeout.timeout(600) do
        until ['200', '302'].include?(`#{curl_http_code}`.strip)
          sleep 5
        end
      end


Any rakeable test suite can be run as part of the smoke test(selenium, cucumber, capybara, and so on.)
You can add more smoke tests by calling arbitrary rake tasks (Please make sure check return status):

    smoke_test: |
      `rake test:smoke HOST_NAME=#{host_name}`
      raise("Smoke failed!") unless $?.success?

Smoke testing gets you one step closer to continuous delivery.

### Blue-Green deployment
Since every deployment now runs smoke test, you now have a better safety net around your deployments. This allows us to trigger automatic blue-green deployments.

To do this you need not do anything special. So far we have deployed the application only once. Let's call this the 'green' stack. Any subsequent calls to deployment will deployment a copy of this application to a new stack - the 'blue' stack. Smoke tests will be run on it and once everything passes the 'blue'(new) stack will be switched to the 'green' stack. Thus your new code will now be on the active stack and the user will experience no downtime.

Once this new stack is stable or has run for a while you can choose to delete the old stack. Or if you are doing continuous delivery you may be ready to another 'blue' deployment. You could just trigger another deployment and repeat this every hour/day/week... you get the idea.



### Destroying a stack
So you are done with this environment, you can destroy it easily as well.

    # destroy one environment
    $ eb_deployer -d -e <environment>


and you are done!

Later tutorials coming soon will cover
* how to setup RDS or other AWS resource and share them between blue green environments

Take a look at code if you can not wait for the documentation.

## Rails 3+ support

EbDeployer ships with a Rails 3+ generator since version 0.4.5.

### Install

Add eb_deployer to your Gemfile

		gem 'eb_deployer'

Setup AWS credentials:

    $ export AWS_ACCESS_KEY_ID=xxx
    $ export AWS_SECRET_ACCESS_KEY=xxx

### Initial configurations and rake tasks

Run Rails generator to generate configurations and rake file:

		rails generate eb_deployer:install

It will setup AWS Elastic Beanstalk blue-green deployment configuration with a Postgres RDS instance as your Rails' backend database.
The followings are details:

* Add file "lib/tasks/eb_deployer.rake", please run "rake -T eb" for tasks description. These tasks are simple and designed for you to customize.
* Add file "config/eb_deployer.yml", it includes basic blue-green configurations with a Postgres RDS instance resource.
* Add file "config/rds.json", it is a CloudFormation template file which provisions the Postgres RDS instance. A separated CloudFormation stack maintains all resources that are shared between different Elastic Beanstalk environments in blue-green deployment. Notice: each eb_deployer environment will create one.
* Add "gem 'pg'" to your Gemfile, as this initial configuration is hooking up with a Postgres RDS instance, we need postgres driver.
* Add file ".ebextenstions/01_postgres_packages.config", which installs Postgres dev packages on EC2 instances, so that we can build gem "pg" on your EC2 machine after deployed.
* Add a new production database configuration into "config/database.yml" file. Your original production configuration will be commented out.

### Deploy

Add all files that need to be deployed into your Git repository, because we will simply use "git ls-files" to find all files need to be packaged.

Deploy a dev environment for testing your application deployment:

		rake eb:deploy

Then, when you're ready to deploy a production environment:

		EB_DEPLOYER_ENV=production rake eb:deploy

## EbDeployer environment

There are so many things called environment:

* Rails environment: development, test, production
* Elastic Beanstalk environment
* Development environment
* Staging environment
* Production environment

An EbDeployer environment is your application running environment (= your running application + infrastructure), e.g. staging environment, production environment.
All EbDeployer environments including dev environment are deployed as Rails production environment.

What is different between EbDeployer environment and Elastic Beanstalk environment?

* There are 2 level concepts in Elastic Beanstalk: Application and Environment
* EbDeployer environment sits between Elastic Beanstalk Application and Elastic Beanstalk Environment:
	* One Elastic Beanstalk Application has many EbDeployer environments: dev, staging, production, or whatever names you like.
	* Depending on deployment strategy, one EbDeployer environment has one or more Elastic Beanstalk environments
		* For 'inplace-update' deployment strategy, it's one Elastic Beanstalk environment.
		* For 'blue-green' deployment strategy, it's two Elastic Beanstalk environments.
* You should consider an Elastic Beanstalk environment is designed to be replacable (by another Elastic Beanstalk environment).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
