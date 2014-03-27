require 'deploy_test'

class InplaceUpdateDeployTest < DeployTest
  def test_first_deployment_create_eb_application
    assert !@eb_driver.application_exists?('simple')
    deploy(:application => 'simple', :environment => "production")
    assert @eb_driver.application_exists?('simple')
  end

  def test_set_option_settings_on_deployment
    redudant = [{:namespace => 'aws:autoscaling:launchconfiguration',
                  :option_name => 'MinSize',
                  :value => '2' }]
    deploy(:application => 'simple', :environment => "production",
           :option_settings => [redudant])

    assert_equal [redudant], @eb_driver.environment_settings('simple', 'production')

  end

  def test_destroy_should_clean_up_eb_application_and_env
    deploy(:application => 'simple', :environment => "production")
    destroy(:application => 'simple')
    assert !@eb_driver.application_exists?('simple')
    assert !@eb_driver.environment_exists?('simple', 'production')
  end

  def test_first_deployment_create_environment
    assert !@eb_driver.environment_exists?('simple', 'production')
    deploy(:application => 'simple', :environment => "production")
    assert @eb_driver.environment_exists?('simple', 'production')
  end

  def test_support_very_very_long_app_name
    deploy(:application => 'ver-very-simple-application', :environment => "production")
    assert @eb_driver.environment_exists?('ver-very-simple-application', 'production')
  end

  def test_should_raise_error_when_env_name_is_too_long
    assert_raises(RuntimeError) { deploy(:application => 'simple', :environment => "p" * 24) }
  end

  def test_update_environment_with_new_version_should_change_version_that_deployed
    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 1)
    assert_equal '1', @eb_driver.environment_verion_label('simple', 'production')

    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 2)

    assert_equal '2', @eb_driver.environment_verion_label('simple', 'production')
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

  def test_should_terminate_old_environment_if_phoenix_mode_is_enabled
    deploy(:application => 'simple', :environment => "production", :phoenix_mode => true)
    assert @eb_driver.environment_exists?('simple', 'production')
    deploy(:application => 'simple', :environment => "production", :phoenix_mode => true)
    assert @eb_driver.environments_been_deleted('simple').include?('production')
    assert @eb_driver.environment_exists?('simple', 'production')
  end



end
