require 'digest'
require 'set'
require 'time'
require 'json'
require 'timeout'
require 'aws-sdk-s3'
require 'aws-sdk-elasticbeanstalk'
require 'aws-sdk-cloudformation'
require 'optparse'
require 'erb'
require 'fileutils'

require 'eb_deployer/version'
require 'eb_deployer/utils'
require 'eb_deployer/aws_driver'
require 'eb_deployer/deployment_strategy'
require 'eb_deployer/cloud_formation_provisioner'
require 'eb_deployer/application'
require 'eb_deployer/resource_stacks'
require 'eb_deployer/throttling_handling'
require 'eb_deployer/eb_environment'
require 'eb_deployer/environment'
require 'eb_deployer/default_component'
require 'eb_deployer/component'
require 'eb_deployer/eb_event_source'
require 'eb_deployer/cf_event_source'
require 'eb_deployer/event_poller'
require 'eb_deployer/package'
require 'eb_deployer/config_loader'
require 'eb_deployer/default_config'
require 'eb_deployer/smoke_test'
require 'eb_deployer/version_cleaner'

module EbDeployer

  #
  # Query ouput value of the cloud formation stack
  #
  # @param [String] key CloudFormation output key
  # @param [Hash] opts
  # @option opts [Symbol] :application application name
  # @option opts [Symbol] :environment environment name (e.g. staging, production)
  # @option opts [Symbol] :region AWS Region (e.g. "us-west-2", "us-east-1")
  #
  def self.query_resource_output(key, opts)
    if region = opts[:region]
      Aws.config.update({
        region: region
      })
    end
    app = opts[:application]
    env_name = opts[:environment]
    cf = opts[:cf_driver] || AWSDriver::CloudFormationDriver.new
    stack_name = opts[:stack_name] || "#{app}-#{env_name}"
    provisioner = CloudFormationProvisioner.new(stack_name, cf)
    provisioner.output(key)
  end


  #
  # Deploy a package to specified environments on elastic beanstalk
  #
  # @param [Hash] opts
  #
  # @option opts [Symbol] :application *required* Application name, this
  #   used for isolate packages and contribute to your elastic beanstalk cname
  #   for environments
  #
  # @option opts [Symbol] :environment *required* Environment for same
  #   application, e.g. testing, staging, production. This will map to 2 elastic
  #   beanstalk environments (env-a-xxx, env-b-xxx) if blue-green deployment
  #   strategy specified
  #
  # @option opts [Symbol] :package *required* package for the application
  #   which should be suitable for elastic beanstalk deploying. For example, a
  #   war file should be provided for java solution stacks and a ZIP file
  #   should be provided for Rails or Sinatra stack.
  #
  # @option opts [Symbol] :option_settings  (optional) Elastic Beanstalk
  #   settings that will apply to the environments you deploying. Value should be
  #   array of hash with format such as:
  #
  #     [{
  #        :namespace => 'aws:autoscaling:launchconfiguration',
  #        :option_name => 'InstanceType',
  #        :value => 'm1.small' }]
  #
  #   When there are many, using an external yaml file to hold those
  #   configuration is recommended. Such as:
  #
  #     YAML.load(File.read("my_settings_file.yml"))
  #
  #   For all available options take a look at
  #   http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/command-options.html
  #
  # @option opts [Symbol] :accepted_healthy_states (['Green']) If :accepted_healthy_states
  #   is specified, EBDeployer will accept provided values when checking
  #   health of an environment instead of default value 'Green'. You can use it
  #   to specify additional healthy states, for example: ['Green', "Yellow"]
  #
  # @option opts [Symbol] :phoenix_mode (false) If phoenix mode is turn on, it
  #   will terminate the old elastic beanstalk environment and recreate on
  #   deploy. For blue-green deployment it terminate the inactive environment
  #   first then recreate it. This is useful to avoiding configuration drift and
  #   accumulating state on the EC2 instances. Also it has the benefit of keeping
  #   your EC2 instance system package upto date, because every time EC2 instance
  #   boot up from AMI it does a system update.
  #
  #
  # @option opts [Symbol] :region set the region for application deployment
  #   (e.g. "us-west-2", "us-east-1"). See available zones at
  #   http://aws.amazon.com/elasticbeanstalk/faqs/#regions
  #
  # @option opts [Symbol] :resources If :resources specified, EBDeployer will
  #   use the CloudFormation template you provide to create a default
  #   CloudFormation stack with name <application_name>-<env-name> for the
  #   environment current deploying.  Value of resources need to be hash with
  #   following keys:
  #
  #     :template => CloudFormation template file with JSON format
  #     :policy => CloudFormation policy file with JSON format
  #     :override_policy => (false) If override_policy is true and a policy file is provided then the
  #   policy will temporarily override any existing policy on the resource stack during this update,
  #   otherwise the provided policy will replace any existing policy on the resource stack
  #     :parameters (or :inputs) => A Hash, input values for the CloudFormation template
  #     :transforms => A Hash with key map to your CloudFormation
  #   template outputs and value as lambda that return a single or array of
  #   elastic beanstalk settings.
  #
  #     :capabilities => An array. You need set it to ['CAPABILITY_IAM']
  #
  #   if you want to provision IAM Instance Profile.
  #
  # @option opts [Symbol] :settings See `option_settings`
  #
  # @option opts [Symbol] :package_bucket Name of s3 bucket where uploaded application
  # packages will be stored. Note that the string ".packages" will be added as
  # a suffix to your bucket. So, if "thoughtworks.simple" is passed as the bucket name,
  # the actual s3 bucket name will be thoughtworks.simple.packages.
  #
  # @option opts [Symbol] :smoke_test Value should be a proc or a lambda which
  #   accept single argument that will passed in as environment DNS name. Smoke
  #   test proc or lambda will be called at the end of the deployment for
  #   inplace-update deployment strategy. For blue-green deployment it will run
  #   after inactive environment update finish and before switching.  Defining a
  #   smoke test is high recommended for serious usage. The simplest one could
  #   just be checking the server is up using curl, e.g.
  #
  #     :smoke_test => lambda { |host|
  #       curl_http_code = "curl -k -s -o /dev/null -w \"%{http_code}\" https://#{host}"
  #       Timeout.timeout(600) do
  #         while `#{curl_http_code}`.strip != '200'
  #           sleep 5
  #         end
  #       end
  #     }
  #
  # @option opts [Symbol] :strategy (:blue-green) There are two options:
  #   blue-green or inplace-update. Blue green keep two elastic beanstalk
  #   environments and always deploy to inactive one, to achieve zero downtime.
  #   inplace-update strategy will only keep one environment, and update the
  #   version inplace on deploy. this will save resources but will have downtime.
  #
  # @option opts [Symbol] :solution_stack_name ("64bit Amazon Linux 2013.09 running Tomcat 7 Java 7")
  #   The elastic beanstalk solution stack you want to deploy on top of.
  #
  # @option opts [Symbol] :tier ("WebServer")
  #   The environment tier. Either "WebServer" or "Worker"
  #
  # @option opts [Symbol] :version_label *required*. Version label give the
  #   package uploaded a unique identifier.  Should use something related to
  #   pipeline counter if you have build pipeline setup to build the installer.
  #   For the convenience of dev we recommend use md5 digest of the installer so
  #   that every time you upload new installer it forms a new version. e.g.
  #
  #      :version_label => ENV['MY_PIPELINE_COUNTER']
  #                       || "dev-" + Digest::MD5.file(my_package).hexdigest
  #
  # @options opts [Symbol] :version_prefix. Specifies a prefix to prepend to the
  #   version label. This can be useful if you want to use different binaries for
  #   different environments.
  #
  # @option opts [Symbol] :keep_latest. Specifies the maximum number of versions to
  #   keep.  Older versions are removed and deleted from the S3 source bucket as well.
  #   If specified as zero or not specified, all versions will be kept.  If a
  #   version_prefix is given, only removes version starting with the prefix.
  #
  # @option opts [Symbol] :template_name. Specifies the environement template you wish
  #   to use to build your environment.
  def self.deploy(opts)
    if region = opts[:region]
      Aws.config.update(:region => region)
    end

    bs = opts[:bs_driver] || AWSDriver::Beanstalk.new
    bs = ThrottlingHandling.new(bs, Aws::ElasticBeanstalk::Errors::Throttling)
    s3 = opts[:s3_driver] || AWSDriver::S3Driver.new
    cf = opts[:cf_driver] || AWSDriver::CloudFormationDriver.new

    app_name = opts[:application]
    env_name = opts[:environment]
    version_prefix = opts[:version_prefix].to_s.strip
    version_label = "#{version_prefix}#{opts[:version_label].to_s.strip}"

    application = Application.new(app_name, bs, s3, opts[:package_bucket])
    resource_stacks = ResourceStacks.new(opts[:resources],
                                         cf,
                                         !!opts[:skip_resource_stack_update],
                                         opts[:tags])

    stack_name = opts[:stack_name] || "#{app_name}-#{env_name}"

    environment = Environment.new(application, env_name, stack_name, bs) do |env|
      env.resource_stacks = resource_stacks
      env.settings = opts[:option_settings] || opts[:settings] || []
      env.inactive_settings = opts[:inactive_settings] || []
      env.creation_opts = {
        :template_name => opts[:template_name],
        :solution_stack => opts[:solution_stack_name],
        :cname_prefix =>  opts[:cname_prefix],
        :smoke_test => opts[:smoke_test],
        :phoenix_mode => opts[:phoenix_mode],
        :accepted_healthy_states => opts[:accepted_healthy_states],
        :blue_green_terminate_inactive => opts[:blue_green_terminate_inactive] || false,
        :blue_green_terminate_inactive_wait => opts[:blue_green_terminate_inactive_wait] || 600,
        :blue_green_terminate_inactive_sleep => opts[:blue_green_terminate_inactive_sleep] || 15,
        :tags => opts[:tags],
        :tier => opts[:tier]
      }
      env.strategy_name = opts[:strategy] || :blue_green
      env.components = opts[:components]
      env.component_under_deploy = opts[:component]
    end

    application.create_version(version_label, opts[:package])
    environment.deploy(version_label)
    application.clean_versions(version_prefix, opts[:keep_latest].to_i || 0)
  end

  def self.destroy(opts)
    if region = opts[:region]
      Aws.config.update(:region => region)
    end

    app = opts[:application]
    bs = opts[:bs_driver] || AWSDriver::Beanstalk.new
    s3 = opts[:s3_driver] || AWSDriver::S3Driver.new

    Application.new(app, bs, s3).delete(opts[:environment])
  end

  def self.cli
    options = {
      :action => :deploy,
      :environment => 'dev',
      :config_file => 'config/eb_deployer.yml'
    }

    parser = cli_parser(options)
    parser.parse!
    action = options.delete(:action)

    if File.exist?(options[:config_file])
      puts "Found configuration at #{options[:config_file]}."
    else
      puts "Generated default configuration at #{options[:config_file]}."
      DefaultConfig.new(File.basename(Dir.pwd)).write_to(options[:config_file])
      exit(2)
    end

    if !options[:package] && action == :deploy
      puts "Missing options: -p (--package)"
      puts "'eb_deploy --help' for details"
      puts parser
      exit(-1)
    end

    self.send(action, ConfigLoader.new.load(options))
  end

  private

  def self.cli_parser(options)
    OptionParser.new do |opts|
      opts.banner = "Usage: eb_deployer [options]"
      opts.on("-p", "--package [FILE/S3_OBJECT]", "Package to deploy, can be a war file for java application, or yaml specification for package location on S3, or a S3 object & bucket name separated by colon, e.g. bucket_name:key_name") do |v|
        options[:package] = v
      end

      opts.on("-e", "--environment [ENV_NAME]", "(Defaults to 'dev') Environment on which to operate (e.g. dev, staging, production). This must be defined in 'environments' section of the config file") do |v|
        options[:environment] = v
      end

      opts.on("-c", "--config-file [FILE]", "eb_deployer config file. Default location is config/eb_deployer.yml") do |v|
        options[:config_file] = v
      end

      opts.on("-d", "--destroy", "Destroy all Elasticbeanstalk environments under the application which have specified environment as name prefix") do |v|
        options[:action] = :destroy
      end

      opts.on("-s", "--stack-name [STACK_NAME]", "CloudFormation stack name to use. If not specified, defaults to {app}-{env_name}") do |v|
        options[:stack_name] = v
      end

      opts.on("--skip-resource-stack-update", "Skip cloud-formation stack update. (only for extreme situation like hitting a cloudformation bug)") do |v|
        options[:skip_resource_stack_update] = true
      end

      opts.on("--component [COMPONENT]", "Specify which component to deploy") do |v|
        options[:component] = v
      end

      opts.on("-v", "--version", "Print current version") do |v|
        puts "eb_deployer v#{VERSION}"
        exit(0)
      end

      opts.on("--debug", "Output AWS debug log") do |d|
        require 'logger'
        logger = Logger.new($stdout)
        logger.level = Logger::DEBUG
        Aws.config.update(:logger => logger)
      end

      opts.on("-h", "--help", "help")  do
        puts opts
        puts ""
        puts "S3 object package format: s3_bucket_name:s3_object_key"
        puts "YAML package file format:"
        puts "s3_bucket: <bucket_name>"
        puts "s3_key: <object_path>"
        exit(0)
      end
    end
  end


end
