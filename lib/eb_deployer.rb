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

    application = Application.new(app, bs, s3)

    cf = CloudFormationProvisioner.new("#{app}-#{env_name}", cf)

    strategy = DeploymentStrategy.create(strategy_name, app, env_name, bs,
                                         :solution_stack => stack_name,
                                         :cname_prefix => cname_prefix,
                                         :smoke_test => smoke_test)

    if resources = opts[:resources]
      env_settings += cf.provision(resources)
    end

    application.create_version(version_label, opts[:package])
    strategy.deploy(version_label, env_settings)
  end

  def self.destroy(opts)
    if region = opts[:region]
      AWS.config(:region => region)
    end

    app = opts[:application]
    bs = opts[:bs_driver] || Beanstalk.new
    s3 = opts[:s3_driver] || S3Driver.new
    cf = opts[:cf_driver] || CloudFormationDriver.new
    Application.new(app, bs, s3).delete
  end

end
