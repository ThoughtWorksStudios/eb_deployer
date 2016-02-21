require 'test_helper'

class EbEnvironmentTest < Test::Unit::TestCase
  def setup
    @eb_driver = EBStub.new
    @eb_driver.create_application("myapp")
  end

  def test_deploy_should_create_corresponding_eb_env
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver, :cname_prefix => 'myapp-production')
    env.deploy("version1")
    assert @eb_driver.environment_exists?('myapp', t('production', 'myapp'))
  end

  def test_deploy_again_should_update_environment
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver, :cname_prefix => 'myapp-production')
    env.deploy("version1")
    env.deploy("version2")
    assert @eb_driver.environment_exists?('myapp', t('production', 'myapp'))
    assert_equal 'version2', @eb_driver.environment_verion_label('myapp', t('production', 'myapp'))
  end

  def test_option_setttings_get_set_on_eb_env
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver, :cname_prefix => 'myapp-production')
    env.deploy("version1", {s1: 'v1'})
    assert_equal({s1: 'v1' },  @eb_driver.environment_settings('myapp', t('production', 'myapp')))
  end

  def test_deploy_should_include_tags
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver, :cname_prefix => 'myapp-production', :tags => {:my_tag => 'my_value', :tag2 => 'value2'})
    env.deploy("version1")
    assert_equal [{:key => :my_tag, :value => 'my_value'}, {:key => :tag2, :value => 'value2'}], @eb_driver.environment_tags('myapp', t('production', 'myapp'))
  end

  def test_should_run_smoke_test_after_deploy
    smoked_host = nil
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver, :smoke_test => Proc.new { |host| smoked_host = host }, :cname_prefix => 'myapp-production')
    env.deploy("version1")

    assert !smoked_host.nil?
    assert_match( /myapp.*\.elasticbeanstalk\.com/, smoked_host)
  end

  def test_should_raise_runtime_error_when_deploy_failed
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver, :cname_prefix => 'myapp-production')
    @eb_driver.set_events("myapp", t("production", 'myapp'),
                          [],
                          ["start deploying", "Failed to deploy application"])
    assert_raises(RuntimeError) { env.deploy("version 1") }
  end

  def test_should_raise_runtime_error_when_eb_extension_execution_failed
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver, :cname_prefix => 'myapp-production')
    @eb_driver.set_events("myapp", t("production", 'myapp'),
                          [],
                          ["start deploying",
                           "create environment",
                           "Command failed on instance. Return code: 1 Output: Error occurred during build: Command hooks failed",
                           "Successfully launched environment"])

    assert_raises(RuntimeError) { env.deploy("version 1") }
  end

  def test_should_raise_runtime_error_when_issues_during_launch
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver, :cname_prefix => 'myapp-production')
    @eb_driver.set_events("myapp", t("production", 'myapp'),
                          [],
                          ["start deploying",
                           "create environment",
                           "Launched environment: dev-a-1234567. However, there were issues during launch. See event log for details."])

    assert_raises(RuntimeError) { env.deploy("version 1") }
  end

  def test_terminate_should_delete_environment
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver, :cname_prefix => 'myapp-production')
    env.deploy("version1")
    env.terminate
    assert !@eb_driver.environment_exists?('myapp', t('production', 'myapp'))
  end

  def test_should_raise_runtime_error_when_solution_stack_is_not_valid
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver, {
                                          :cname_prefix => 'myapp-production',
                                          :solution_stack => "python"
                                        })
    @eb_driver.set_solution_stacks(["java", "ruby"])
    assert_raises(RuntimeError) { env.deploy("version 1") }
  end

  def test_should_no_set_cname_prefix_for_create_unless_for_web_tier
    env = EbDeployer::EbEnvironment.new("myapp",
                                        "production",
                                        @eb_driver,
                                        :tier => "Worker",
                                        :cname_prefix => 'myapp-production')
    env.deploy("version1")
    assert @eb_driver.environment_exists?('myapp', t('production', 'myapp'))
    assert_nil @eb_driver.environment_cname_prefix('myapp', t('production', 'myapp'))
  end

  def test_should_be_possible_to_accept_yellow_health_state
    env = EbDeployer::EbEnvironment.new("myapp", "production", @eb_driver, :accepted_healthy_states => ["Green", "Yellow"])
    @eb_driver.mark_env_health_state_as("myapp", env.name, "Yellow")
    env.deploy("version1")
    assert @eb_driver.environment_exists?('myapp', t('production', 'myapp'))
  end

end
