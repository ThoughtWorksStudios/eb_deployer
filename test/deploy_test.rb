require 'eb_deployer'
require 'aws_driver_stubs'
require 'minitest/autorun'

class DeployTest < Minitest::Test
  def setup
    @eb_driver = EBStub.new
    @s3_driver = S3Stub.new
    @sample_package = '/tmp/app-package.war'
    File.open(@sample_package, 'w') { |f| f << 's' * 100 }
  end

  def deploy(opts)
    EbDeployer.deploy({:package => @sample_package,
                        :bs_driver => @eb_driver,
                        :s3_driver => @s3_driver,
                        :version_label => 1}.merge(opts))
  end


  def test_first_deployment_create_environment
    assert !@eb_driver.environment_exists?('simple', 'simple-production')
    deploy(:application => 'simple', :environment => "production")
    assert @eb_driver.environment_exists?('simple', 'simple-production')
  end


  def test_update_environment_with_new_version_should_change_version_that_deployed
    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 1)
    assert_equal '1', @eb_driver.environment_verion_label('simple', 'simple-production')

    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 2)

    assert_equal '2', @eb_driver.environment_verion_label('simple', 'simple-production')
  end

  def test_default_cname_that_deployed_should_app_env_name
    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 42)
    assert_equal "simple-production", @eb_driver.environment_cname_prefix('simple', 'simple-production')
  end

  def test_cname_prefix_can_be_override
    deploy(:application => 'simple',
           :environment => "production",
           :cname_prefix => 'sports123',
           :version_label => 42)
    assert_equal "sports123", @eb_driver.environment_cname_prefix('simple', 'simple-production')
  end


  def test_smoke_test_should_be_run_after_env_created_or_update
    host_for_smoke_test = nil
    deploy(:application => 'simple',
           :environment => "production",
           :cname_prefix => 'foobar',
           :smoke_test => lambda { |host| host_for_smoke_test = host },
           :version_label => 42)
    assert_equal 'foobar.elasticbeanstalk.com', host_for_smoke_test

    host_for_smoke_test = nil
    deploy(:application => 'simple',
           :environment => "production",
           :cname_prefix => 'foobar',
           :smoke_test => lambda { |host| host_for_smoke_test = host },
           :version_label => 43)

    assert_equal 'foobar.elasticbeanstalk.com', host_for_smoke_test
  end



  def test_blue_green_deployment_strategy_should_create_blue_env_on_first_deployment
    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue_green',
           :version_label => 42)

    assert @eb_driver.environment_exists?('simple', 'simple-production-blue')
    assert_equal 'simple-production',  @eb_driver.environment_cname_prefix('simple', 'simple-production-blue')
  end


  def test_blue_green_deployment_should_create_green_env_if_blue_exists
    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue_green',
           :version_label => 42)

    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue_green',
           :version_label => 43)

    assert @eb_driver.environment_exists?('simple', 'simple-production-blue')
    assert @eb_driver.environment_exists?('simple', 'simple-production-green')
  end


  def test_blue_green_deployment_should_swap_cname_to_make_active_most_recent_updated_env
    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue_green',
           :version_label => 42)

    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue_green',
           :version_label => 43)

    assert_match(/simple-production-inactive/,  @eb_driver.environment_cname_prefix('simple', 'simple-production-blue'))

    assert_equal 'simple-production',  @eb_driver.environment_cname_prefix('simple', 'simple-production-green')


    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue_green',
           :version_label => 44)

    assert_match(/simple-production-inactive/,  @eb_driver.environment_cname_prefix('simple', 'simple-production-green'))

    assert_equal 'simple-production',  @eb_driver.environment_cname_prefix('simple', 'simple-production-blue')
  end


  def test_blue_green_deploy_should_run_smoke_test_before_cname_switch
    smoked_host = []
    smoke_test = lambda { |host| smoked_host << host }
    [42, 43, 44].each do |version_label|
      deploy(:application => 'simple',
             :environment => "production",
             :strategy => 'blue_green',
             :smoke_test => smoke_test,
             :version_label => version_label)
    end

    assert_equal ['simple-production.elasticbeanstalk.com',
                  'simple-production-inactive.elasticbeanstalk.com',
                  'simple-production-inactive.elasticbeanstalk.com'], smoked_host
  end
end
