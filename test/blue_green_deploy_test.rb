require 'deploy_test'

class BlueGreenDeployTest < DeployTest
  def test_blue_green_deployment_strategy_should_create_blue_env_on_first_deployment
    do_deploy(42)
    assert @eb.environment_exists?('simple', t('production-a', 'simple'))
    assert_equal 'simple-production',  @eb.environment_cname_prefix('simple', t('production-a', 'simple'))
  end


  def test_blue_green_deployment_should_create_green_env_if_blue_exists
    do_deploy(42)
    do_deploy(43)
    assert @eb.environment_exists?('simple', t('production-a', 'simple'))
    assert @eb.environment_exists?('simple', t('production-b', 'simple'))
  end


  def test_blue_green_deployment_should_swap_cname_to_make_active_most_recent_updated_env
    do_deploy(42)
    do_deploy(43)
    assert_match(/simple-production-inactive/,  @eb.environment_cname_prefix('simple', t('production-a', 'simple')))
    assert_equal 'simple-production',  @eb.environment_cname_prefix('simple', t('production-b', 'simple'))
    do_deploy(44)
    assert_match(/simple-production-inactive/,  @eb.environment_cname_prefix('simple', t('production-b', 'simple')))
    assert_equal 'simple-production',  @eb.environment_cname_prefix('simple', t('production-a', 'simple'))
  end


  def test_blue_green_deploy_should_run_smoke_test_before_cname_switch
    smoked_host = []
    smoke_test = lambda { |host| smoked_host << host }
    [42, 43, 44].each do |version_label|
      do_deploy(version_label, :smoke_test => smoke_test)
    end

    assert_equal ['simple-production.us-west-1.elasticbeanstalk.com',
                  'simple-production-inactive.us-west-1.elasticbeanstalk.com',
                  'simple-production-inactive.us-west-1.elasticbeanstalk.com'], smoked_host
  end

  def test_blue_green_deploy_should_blue_green_terminate_inactive_env_if_blue_green_terminate_inactive_is_enabled
    do_deploy(42, :blue_green_terminate_inactive => true, :blue_green_terminate_inactive_wait => 1, :blue_green_terminate_inactive_sleep => 1)
    do_deploy(43, :blue_green_terminate_inactive => true, :blue_green_terminate_inactive_wait => 0, :blue_green_terminate_inactive_sleep => 0)

    inactive_env = t('production-a', 'simple')
    assert_equal [inactive_env], @eb.environments_been_deleted('simple')
  end

  def test_blue_green_deployment_should_delete_and_recreate_inactive_env_if_phoenix_mode_is_enabled
    do_deploy(42, :phoenix_mode => true)
    do_deploy(43, :phoenix_mode => true)
    assert_equal [],  @eb.environments_been_deleted('simple')

    inactive_env = t('production-a', 'simple')
    assert_match(/inactive/,  @eb.environment_cname_prefix('simple', inactive_env))

    do_deploy(44, :phoenix_mode => true)
    assert_equal [inactive_env], @eb.environments_been_deleted('simple')

    assert_equal 'simple-production',  @eb.environment_cname_prefix('simple', inactive_env)
  end

  def test_destroy_should_clean_up_env
    [42, 44].each do |version|
      do_deploy(version)
    end

    destroy(:application => 'simple', :environment => 'production')
    assert !@eb.environment_exists?('simple', t('production-a', 'simple'))
    assert !@eb.environment_exists?('simple', t('production-b', 'simple'))
  end

  def test_can_have_inactive_settings_which_will_be_applied_to_inactive_env
    settings = {:option_settings =>
      [{:namespace => 'aws:autoscaling:launchconfiguration',
         :option_name => 'MinSize',
         :value => 10}],
      :inactive_settings =>
      [{:namespace => 'aws:autoscaling:launchconfiguration',
         :option_name => 'MinSize',
         :value => 1}]}

    do_deploy(42, settings)
    assert_equal 10, @eb.environment_settings('simple', t('production-a', 'simple')).last[:value]
    assert_equal '42', @eb.environment_verion_label('simple', t('production-a', 'simple'))

    do_deploy(43, settings)
    assert_equal 1, @eb.environment_settings('simple', t('production-a', 'simple')).last[:value]
    assert_equal '42', @eb.environment_verion_label('simple', t('production-a', 'simple'))

    assert_equal 10, @eb.environment_settings('simple', t('production-b', 'simple')).last[:value]
    assert_equal '43', @eb.environment_verion_label('simple', t('production-b', 'simple'))


    do_deploy(44, settings)
    assert_equal 10, @eb.environment_settings('simple', t('production-a', 'simple')).last[:value]
    assert_equal '44', @eb.environment_verion_label('simple', t('production-a', 'simple'))

    assert_equal 1, @eb.environment_settings('simple', t('production-b', 'simple')).last[:value]
    assert_equal '43', @eb.environment_verion_label('simple', t('production-b', 'simple'))

  end

  private

  def do_deploy(version_label, options={})
    deploy( {:application => 'simple',
              :environment => "production",
              :strategy => 'blue-green',
            }.merge(options).merge(:version_label => version_label))
  end

end
