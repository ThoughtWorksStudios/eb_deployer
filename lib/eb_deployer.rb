require "eb_deployer/version"
require "eb_deployer/deployment_strategy"
require "eb_deployer/beanstalk"
require "eb_deployer/cloud_formation_provisioner"
require 'eb_deployer/application'
require "eb_deployer/environment"
require "eb_deployer/event_poller"
require "eb_deployer/package"
require 'eb_deployer/s3_driver'
require 'eb_deployer/cloud_formation_driver'
require 'digest'
require 'set'
require 'time'
require 'json'
require 'timeout'
require 'aws-sdk'

module EbDeployer

  ##
  # Query ouput value of the cloud formation stack
  # arguments:
  #  key:    CloudFormation ouput key
  #  options: a hash
  #     :application     application name
  #     :environment     environment name (e.g. staging, production)
  #

  def self.query_resource_output(key, opts)
    # AWS.config(:logger => Logger.new($stdout))
    if region = opts[:region]
      AWS.config(:region => region)
    end
    app = opts[:application]
    env_name = opts[:environment]
    cf = opts[:cf_driver] || CloudFormationDriver.new
    provisioner = CloudFormationProvisioner.new("#{app}-#{env_name}", cf)
    provisioner.output(key)
  end


  #
  # Options available:
  #
  # :application (required)
  # Application name, this used for isolate packages and contribute
  # to your elastic beanstalk cname for environments
  #
  # :environment (required)
  # Environment for same application, e.g. testing, staging,
  # production. This will map to 2 elastic beanstalk environments
  # (env-a-xxx, env-b-xxx) if blue-green deployment strategy specified
  #
  # :package (required)        package for the application which should be
  # suitable for elastic beanstalk deploying. For example, a war file
  # should be provided for java solution stacks and a tar gz file
  # should be provided for rails stack.
  #
  # :version_label (required)
  # Version label give the package uploaded a unique identifier.
  # Should use something related to pipeline counter if you have build
  # pipeline setup to build the installer. For the convient of dev we
  # recommend use md5 digest of the installer so that everytime you
  # upload new installer it forms a new version. e.g.
  #
  #     :version_label => ENV['MY_PIPELINE_COUNTER']
  #                      || "dev-" + Digest::MD5.file(my_package).hexdigest
  #
  # :solution_stack_name (optional default "64bit Amazon Linux running Tomcat 7")
  # The elastic beanstalk solution stack you want to deploy on top of.
  # Current possible values include:
  #
  # :settings  (optional)
  # Elastic Beanstalk settings that will apply to the environments you
  # deploying. Value should be array of hash with format such as:
  #     [{
  #        :namespace => 'aws:autoscaling:launchconfiguration',
  #        :option_name => 'InstanceType',
  #        :value => 'm1.small' }]
  # When there are many, Using an external yaml file to hold those
  # configuration is recommended. Such as:
  #     YAML.load(File.read("my_settings_file.yml"))
  # For all available options take a look at
  # http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/command-options.html
  #
  # :resources (optional)
  # If :resources specified, EBDeployer will use the CloudFormation
  # template you provide to create a default CloudFormation stack with
  # name <application_name>-<env-name> for the environment current
  # deploying.  Value of resources need to be hash with following
  # keys:
  #    :template => CloudFormation template file with JSON format
  #    :parameters => A Hash, input values for the CloudFormation
  # template
  #    :transforms => A Hash with key map to your CloudFormation
  # template outputs and value as lambda that return a single or array of
  # elastic beanstalk settings.
  #    :capabilities => An array. You need set it to ['CAPABILITY_IAM']
  # if you want to provision IAM Instance Profile.
  #
  # :strategy (optional default :blue-green)
  # There are two options: blue-green or inplace-update. Blue green
  # keep two elastic beanstalk environments and always deploy to
  # inactive one, to achive zero downtime. inplace-update strategy
  # will only keep one environment, and update the version inplace on
  # deploy. this will save resources but will have downtime.
  #
  # :phoenix_mode (optional default false)
  # If phoenix mode is turn on, it will terminate the old elastic
  # beanstalk environment and recreate on deploy. For blue-green
  # deployment it terminate the inactive environment first then
  # recreate it. This is useful to avoiding configuration drift and
  # accumulating state on the ec2 instances. Also it has the benifit of
  # keeping your ec2 instance system package upto date, because everytime ec2
  # instance boot up from AMI it does a system update.
  #
  # :smoke_test (optional)
  # Value should be a proc or a lambda which accept single argument that will
  # passed in as environment DNS name. Smoke test proc or lambda will be
  # called at the end of the deployment for inplace-update deployment
  # strategy. For blue-green deployment it will run after inactive
  # environment update finish and before switching.
  # Defining a smoke test is high recommended for serious usage. The
  # simplest one could just be checking the server is up using curl, e.g.
  #
  #  :smoke_test => lambda { |host|
  #    curl_http_code = "curl -k -s -o /dev/null -w \"%{http_code}\" https://#{host}"
  #    Timeout.timeout(600) do
  #      while `#{curl_http_code}`.strip != '200'
  #        sleep 5
  #      end
  #    end
  #  }
  #
  #
  # deploy a package to specfied environments on elastic beanstalk
  #

  def self.deploy(opts)
    # AWS.config(:logger => Logger.new($stdout))
    if region = opts[:region]
      AWS.config(:region => region)
    end

    bs = opts[:bs_driver] || Beanstalk.new
    s3 = opts[:s3_driver] || S3Driver.new
    cf = opts[:cf_driver] || CloudFormationDriver.new
    stack_name = opts[:solution_stack_name] || "64bit Amazon Linux running Tomcat 7"
    app = opts[:application]
    env_name = opts[:environment]
    version_label = opts[:version_label].to_s.strip
    cname = opts[:cname]
    env_settings = opts[:settings] || []
    strategy_name = opts[:strategy] || :blue_green
    cname_prefix = opts[:cname_prefix] || [app, env_name].join('-')
    smoke_test = opts[:smoke_test] || Proc.new {}
    phoenix_mode = opts[:phoenix_mode]

    application = Application.new(app, bs, s3)

    cf = CloudFormationProvisioner.new("#{app}-#{env_name}", cf)

    strategy = DeploymentStrategy.create(strategy_name, app, env_name, bs,
                                         :solution_stack => stack_name,
                                         :cname_prefix => cname_prefix,
                                         :smoke_test => smoke_test,
                                         :phoenix_mode => phoenix_mode)

    if resources = opts[:resources]
      env_settings += cf.provision(resources)
    end

    application.create_version(version_label, opts[:package])
    strategy.deploy(version_label, env_settings)
  end

  ##
  # WARNING: USE extreme caution, this will destroy *all* Elastic Beanstalk
  #  environments and the Elastic Beanstalk application itself.
  #  i.e. do not issue a destroy when you have other environments
  #   under the same :application that you wish to keep running.
  #
  #  options: a hash
  #     :application     application name
  #

  def self.destroy(opts)
    if region = opts[:region]
      AWS.config(:region => region)
    end

    app = opts[:application]
    bs = opts[:bs_driver] || Beanstalk.new
    s3 = opts[:s3_driver] || S3Driver.new
    cf = opts[:cf_driver] || CloudFormationDriver.new
    Application.new(app, bs, s3).destroy
  end

end
