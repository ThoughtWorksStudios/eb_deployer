require 'deploy_test'

class InplaceUpdateDeployTest < DeployTest
  def test_first_deployment_create_eb_application
    assert !@eb.application_exists?('simple')
    deploy(:application => 'simple', :environment => "production")
    assert @eb.application_exists?('simple')
  end

  def test_set_option_settings_on_deployment
    redudant = [{:namespace => 'aws:autoscaling:launchconfiguration',
                  :option_name => 'MinSize',
                  :value => '2' }]
    deploy(:application => 'simple', :environment => "production",
           :option_settings => [redudant])

    assert_equal [redudant], @eb.environment_settings('simple', t('production', 'simple'))

  end

  def test_first_deployment_create_environment
    assert !@eb.environment_exists?('simple', t('production', 'simple'))
    deploy(:application => 'simple', :environment => "production")
    assert @eb.environment_exists?('simple', t('production', 'simple'))
  end

  def test_support_very_very_long_app_name
    deploy(:application => 'ver-very-simple-application', :environment => "production")
    assert @eb.environment_exists?('ver-very-simple-application', t('production', 'ver-very-simple-application'))
  end

  def test_should_raise_error_when_env_name_is_too_long
    assert_raises(RuntimeError) { deploy(:application => 'simple', :environment => "p" * 24) }
  end

  def test_update_environment_with_new_version_should_change_version_that_deployed
    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 1)
    assert_equal '1', @eb.environment_verion_label('simple', t('production', 'simple'))

    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 2)

    assert_equal '2', @eb.environment_verion_label('simple', t('production', 'simple'))
  end

  def test_smoke_test_should_be_run_after_env_created_or_update
    host_for_smoke_test = nil
    deploy(:application => 'simple',
           :environment => "production",
           :cname_prefix => 'foobar',
           :smoke_test => lambda { |host| host_for_smoke_test = host },
           :version_label => 42)
    assert_equal 'foobar.us-west-1.elasticbeanstalk.com', host_for_smoke_test

    host_for_smoke_test = nil
    deploy(:application => 'simple',
           :environment => "production",
           :cname_prefix => 'foobar',
           :smoke_test => lambda { |host| host_for_smoke_test = host },
           :version_label => 43)

    assert_equal 'foobar.us-west-1.elasticbeanstalk.com', host_for_smoke_test
  end

  def test_should_terminate_old_environment_if_phoenix_mode_is_enabled
    deploy(:application => 'simple', :environment => "production", :phoenix_mode => true)
    assert @eb.environment_exists?('simple', t('production', 'simple'))
    deploy(:application => 'simple', :environment => "production", :phoenix_mode => true)
    assert @eb.environments_been_deleted('simple').include?(t('production', 'simple'))
    assert @eb.environment_exists?('simple', t('production', 'simple'))
  end

  def test_destroy_should_clean_up_env
    deploy(:application => 'simple', :environment => "production")
    destroy(:application => 'simple', :environment => 'production')
    assert !@eb.environment_exists?('simple', t('production', 'simple'))
  end

  def test_deploy_should_raise_error_when_constantly_hitting_throttling_error
    throttling_error = Aws::ElasticBeanstalk::Errors::Throttling.new(nil, "bang!")
    @eb.set_error(:fetch_events, throttling_error)
    assert_raises(Aws::ElasticBeanstalk::Errors::Throttling) do
      deploy(:application => 'simple', :environment => "production")
    end
  end

  def test_deploy_should_retry_on_temporary_throttling_error_from_fetch_events
    throttling_error = Aws::ElasticBeanstalk::Errors::Throttling.new(nil, "bang!")
    error_seq = [throttling_error] * 5
    @eb.set_error_generator(:fetch_events) do
      error_seq.pop
    end
    deploy(:application => 'simple', :environment => "production")
    assert @eb.environment_exists?('simple', t('production', 'simple'))
  end

  def test_deploy_should_retry_on_temporary_throttling_error_from_create_env
    throttling_error = Aws::ElasticBeanstalk::Errors::Throttling.new(nil, "bang!")
    error_seq = [throttling_error] * 5
    @eb.set_error_generator(:create_environment) do
      error_seq.pop
    end
    deploy(:application => 'simple', :environment => "production")
    assert @eb.environment_exists?('simple', t('production', 'simple'))
  end

end
