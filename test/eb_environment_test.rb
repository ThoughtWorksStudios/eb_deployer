require 'test_helper'

class EbEnvironmentTest < MiniTest::Unit::TestCase
  class PollerStub
    class Deadloop < StandardError; end

    def initialize(messages)
      start_time = Time.now.utc
      @events = messages.map do |message|
        start_time += 1
        {:event_date => start_time, :message => message}
      end
    end


    def poll(start_time = Time.now, &block)
      @events.each(&block)
      raise Deadloop.new('poll will never terminate if you do not set a break in the block')
    end
  end

  def setup
    @eb_driver = EBStub.new
    @eb_driver.create_application("myapp")
  end

  def test_deploy_should_create_corresponding_eb_env
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver)
    env.deploy("version1")
    assert @eb_driver.environment_exists?('myapp', 'production')
  end

  def test_deploy_again_should_update_environment
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver)
    env.deploy("version1")
    env.deploy("version2")
    assert @eb_driver.environment_exists?('myapp', 'production')
    assert_equal 'version2', @eb_driver.environment_verion_label('myapp', 'production')
  end

  def test_option_setttings_get_set_on_eb_env
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver)
    env.deploy("version1", {s1: 'v1'})
    assert_equal({s1: 'v1' },  @eb_driver.environment_settings('myapp', 'production'))
  end

  def test_should_run_smoke_test_after_deploy
    smoked_host = nil
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver, :smoke_test => Proc.new { |host| smoked_host = host })
    env.deploy("version1")

    assert !smoked_host.nil?
    assert_match( /myapp.*\.elasticbeanstalk\.com/, smoked_host)
  end

  def test_should_raise_runtime_error_when_deploy_failed
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver)
    env.event_poller = PollerStub.new(["start deploying", "Failed to deploy application"])
    assert_raises(RuntimeError) { env.deploy("version 1") }
  end

  def test_should_raise_runtime_error_when_eb_extension_execution_failed
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver)

    env.event_poller = PollerStub.new(["start deploying",
                                       "create environment",
                                       "Command failed on instance. Return code: 1 Output: Error occurred during build: Command hooks failed",
                                       "Successfully launched environment"])

    assert_raises(RuntimeError) { env.deploy("version 1") }
  end


  def test_terminate_should_delete_environment
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver)
    env.deploy("version1")
    env.terminate
    assert !@eb_driver.environment_exists?('myapp', 'production')
  end

  def test_should_terminate_legacy_env_upon_deployment
    legacy_env_name = EbDeployer::EbEnvironment.legacy_ebenv_name("myapp", "production")
    @eb_driver.create_environment("myapp", legacy_env_name, 'solution-stack', 'simple-production', 'foo', 'web' ,{})
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver)
    env.deploy("version1")
    assert !@eb_driver.environment_exists?("myapp", legacy_env_name)
    assert @eb_driver.environment_exists?("myapp", "production")
  end

  def test_can_find_cname_if_legacy_env_exists
    legacy_env_name = EbDeployer::EbEnvironment.legacy_ebenv_name("myapp", "production")
    @eb_driver.create_environment("myapp", legacy_env_name, 'solution-stack', 'myapp-production', 'foo', 'web' ,{})
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver)
    assert_equal 'myapp-production', env.cname_prefix
  end

  def test_terminate_legacy_env
    legacy_env_name = create_legacy_env("myapp", "production", "myapp-production")
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver)
    env.terminate
    assert !@eb_driver.environment_exists?("myapp", legacy_env_name)
  end

  def test_swap_legacy_env_with_non_legacy_env
    create_legacy_env("myapp", "production-a", "myapp-production")
    env_a = EbDeployer::EbEnvironment.new("myapp", "production-a", @eb_driver)
    env_b = EbDeployer::EbEnvironment.new("myapp", "production-b", @eb_driver, :cname_prefix => 'myapp-production-inactive')
    env_b.deploy('version1')

    env_a.swap_cname_with(env_b)

    assert_equal "myapp-production-inactive", env_a.cname_prefix
    assert_equal "myapp-production", env_b.cname_prefix
  end

  def test_swap_no_legacy_env_with_legacy_env
    create_legacy_env("myapp", "production-a", "myapp-production")
    env_a = EbDeployer::EbEnvironment.new("myapp", "production-a", @eb_driver)
    env_b = EbDeployer::EbEnvironment.new("myapp", "production-b", @eb_driver, :cname_prefix => 'myapp-production-inactive')
    env_b.deploy('version1')

    env_b.swap_cname_with(env_a)

    assert_equal "myapp-production-inactive", env_a.cname_prefix
    assert_equal "myapp-production", env_b.cname_prefix
  end



  def create_legacy_env(app_name, env_name, cname_prefix)
    legacy_env_name = EbDeployer::EbEnvironment.legacy_ebenv_name(app_name, env_name)
    @eb_driver.create_environment(app_name, legacy_env_name, 'solution-stack', cname_prefix, 'foo', 'web' ,{})
    legacy_env_name
  end



end
