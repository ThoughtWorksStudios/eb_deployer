== README
This is a demo app for eb_deployer to demo how to use warbler(with jruby_rack) and eb_deployer to deploy a rails 4.0 app on elasticbeanstalk.

# Gems installed:

    gem 'warbler'
    gem 'eb_deployer'
    gem 'rubyzip', '< 1.0.0' # to make warbler work

# Configuration added:

## RDS database
    config/my_rds.json  is a CloudFormation template for mysql RDS instance. Take a look at resources section of config/eb_deployer.yml to see how inputs and outputs of the template is handled.
    Also config/database.yml is changed to configure the production database connection.


# Deploy process:

    $ rake assets:precompile
    $ warble
    $ export AWS_ACCESS_KEY_ID=xxx
    $ export AWS_SECRET_ACCESS_KEY=xxx
    $ export DBPASSWORD=<rds db password> # required in eb_deployer.yml
    $ eb_deploy -p jruby_rails4.war #(add '-e production' for deploy to production)

# How to ran database migration

## Do your first deploy
## Locate your RDS security group in AWS console. It is named as "<application-name>-<environment>-rdsdbsecuritygroup-xxxx. Open your RDS database remote access temporarily
## In AWS ElasticBeanstalk console, find your environment, copy out the value of "databaseConfig" under Configuration ->  Software Configuration -> Environment Properties
## Run database migration

    $ RAILS_ENV=production JAVA_OPTS='-DdatabaseConfig=<value>' rake db:migrate

## Change your RDS security group to shutdown remote access.
