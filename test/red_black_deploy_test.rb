require 'deploy_test'

class RedBlackDeployTest < DeployTest
  def test_red_black_deployment_strategy_should_create_red_env_on_first_deployment
    do_deploy(42)
    assert @eb.environment_exists?('simple', t('production-a', 'simple'))
    assert_equal 'simple-production',  @eb.environment_cname_prefix('simple', t('production-a', 'simple'))
  end


  def test_red_black_deployment_should_create_black_env_if_red_exists
    do_deploy(42)
    do_deploy(43)
    assert !@eb.environment_exists?('simple', t('production-a', 'simple'))
    assert @eb.environment_exists?('simple', t('production-b', 'simple'))
  end

  def test_red_black_deployment_should_terminate_inactive_environment_on_successful_deploy
    do_deploy(42)
    do_deploy(43)
    inactive_env = t('production-a', 'simple')
    assert_equal [inactive_env], @eb.environments_been_deleted('simple')
    assert_equal 'simple-production',  @eb.environment_cname_prefix('simple', t('production-b', 'simple'))
    do_deploy(44)
    inactive_env2 = t('production-b', 'simple')
    assert_equal [inactive_env, inactive_env2], @eb.environments_been_deleted('simple')
    assert_equal 'simple-production',  @eb.environment_cname_prefix('simple', t('production-a', 'simple'))
  end

  def test_red_black_deployment_should_swap_cname_to_make_active_most_recent_updated_env
    do_deploy(42)
    do_deploy(43)
    assert_equal 'simple-production',  @eb.environment_cname_prefix('simple', t('production-b', 'simple'))
    do_deploy(44)
    assert_equal 'simple-production',  @eb.environment_cname_prefix('simple', t('production-a', 'simple'))
  end


  def test_red_black_deploy_should_run_smoke_test_before_cname_switch
    smoked_host = []
    smoke_test = lambda { |host| smoked_host << host }
    [42, 43, 44].each do |version_label|
      do_deploy(version_label, :smoke_test => smoke_test)
    end

    assert_equal ['simple-production.elasticbeanstalk.com',
                  'simple-production-inactive.elasticbeanstalk.com',
                  'simple-production-inactive.elasticbeanstalk.com'], smoked_host
  end

  def test_destroy_should_clean_up_env
    [42, 44].each do |version|
      do_deploy(version)
    end

    destroy(:application => 'simple', :environment => 'production')
    assert !@eb.environment_exists?('simple', t('production-a', 'simple'))
    assert !@eb.environment_exists?('simple', t('production-b', 'simple'))
  end

  private

  def do_deploy(version_label, options={})
    deploy( {:application => 'simple',
              :environment => "production",
              :strategy => 'red-black',
            }.merge(options).merge(:version_label => version_label))
  end

end
