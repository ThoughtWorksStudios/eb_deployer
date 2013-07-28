# EbDeployer

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'eb_deployer'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install eb_deployer

## Usage

Elastic Beanstalk currently allows you do deploy applications to its predefined set of solution stacks. You will be able to use eb_deployer to deploy to any of those predefined stacks.

Pick the application that fits those stacks. We have a jruby application that we are going to use for this example.

Once you have selected that application in the home folder install the eb_deployer gem. You could add it to your Gemfile under :development group as well and re-run 'bundle install'. 

You can then copy the rake task we have in the samples/simple/Rakefile with the prerequisites.

Once you have copied the rake task and renamed it appropriately so that it is available when you run rake, ensure that you have set the correct options.
The options you would want to change are :application, :environment, :solution_stack (if it is different from the default). 
Before you run the rake task you will need to create a deployable package of your application. Both tar.gz and war versions work. We will use the war version.

To create a war package of your application, run 'gem install warbler' and then run 'warble'. You should have a your_app.war.
(Ensure keys are set correctly in the environment before you call this rake task.)
Now you are ready to deploy using eb_deployer. 

Run 'rake eb:deploy' and in a few minutes your application should show up in your ElasticBeanstalk console. You will notice that it shows up as (a). 

Now deploy this again. You will notice that it shows up as (b). These are the two EB instances used to do blue-green deployment.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
