require 'deploy_test'

class BlueGreenDeployTest < DeployTest
  def test_blue_green_deployment_strategy_should_create_blue_env_on_first_deployment
    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 42)

    assert @eb.environment_exists?('simple', t('production-a', 'simple'))
    assert_equal 'simple-production',  @eb.environment_cname_prefix('simple', t('production-a', 'simple'))
  end


  def test_blue_green_deployment_should_create_green_env_if_blue_exists
    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 42)

    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 43)

    assert @eb.environment_exists?('simple', t('production-a', 'simple'))
    assert @eb.environment_exists?('simple', t('production-b', 'simple'))
  end


  def test_blue_green_deployment_should_swap_cname_to_make_active_most_recent_updated_env
    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 42)

    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 43)

    assert_match(/simple-production-inactive/,  @eb.environment_cname_prefix('simple', t('production-a', 'simple')))

    assert_equal 'simple-production',  @eb.environment_cname_prefix('simple', t('production-b', 'simple'))


    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 44)

    assert_match(/simple-production-inactive/,  @eb.environment_cname_prefix('simple', t('production-b', 'simple')))

    assert_equal 'simple-production',  @eb.environment_cname_prefix('simple', t('production-a', 'simple'))
  end


  def test_blue_green_deploy_should_run_smoke_test_before_cname_switch
    smoked_host = []
    smoke_test = lambda { |host| smoked_host << host }
    [42, 43, 44].each do |version_label|
      deploy(:application => 'simple',
             :environment => "production",
             :strategy => 'blue-green',
             :smoke_test => smoke_test,
             :version_label => version_label)
    end

    assert_equal ['simple-production.elasticbeanstalk.com',
                  'simple-production-inactive.elasticbeanstalk.com',
                  'simple-production-inactive.elasticbeanstalk.com'], smoked_host
  end


  def test_blue_green_deployment_should_delete_and_recreate_inactive_env_if_phoenix_mode_is_enabled
    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 42,
           :phoenix_mode => true)

    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 43,
           :phoenix_mode => true)

    assert_equal [],  @eb.environments_been_deleted('simple')

    inactive_env = t('production-a', 'simple')
    assert_match(/inactive/,  @eb.environment_cname_prefix('simple', inactive_env))


    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 44,
           :phoenix_mode => true)

    assert_equal [inactive_env], @eb.environments_been_deleted('simple')

    assert_equal 'simple-production',  @eb.environment_cname_prefix('simple', inactive_env)
  end

  def test_destroy_should_clean_up_env
    2.times do
      deploy(:application => 'simple',
             :environment => "production",
             :strategy => 'blue-green',
             :version_label => 44,
             :phoenix_mode => true)
    end

    destroy(:application => 'simple', :environment => 'production')
    assert !@eb.environment_exists?('simple', t('production-a', 'simple'))
    assert !@eb.environment_exists?('simple', t('production-b', 'simple'))
  end



end
