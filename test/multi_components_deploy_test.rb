require 'deploy_test'

class MultiComponentsDeployTest < DeployTest
  def test_deploy_with_components
    do_deploy
    assert @eb.environment_exists?('simple', t('prod-web', 'simple'))
    assert @eb.environment_exists?('simple', t('prod-bg', 'simple'))
    assert @eb.environment_exists?('simple', t('prod-api', 'simple'))
    assert !@eb.environment_exists?('simple', t('prod', 'simple'))
  end

  def test_deploy_with_components_with_blue_green
    do_bg_deploy
    assert @eb.environment_exists?('simple', t('prod-web-a', 'simple'))
    assert @eb.environment_exists?('simple', t('prod-bg-a', 'simple'))
    assert @eb.environment_exists?('simple', t('prod-api-a', 'simple'))
    do_bg_deploy
    assert @eb.environment_exists?('simple', t('prod-web-b', 'simple'))
    assert @eb.environment_exists?('simple', t('prod-bg-b', 'simple'))
    assert @eb.environment_exists?('simple', t('prod-api-b', 'simple'))
  end

  def test_cname_include_component_name
    do_deploy
    assert_equal 'simple-prod-web', @eb.environment_cname_prefix('simple', t('prod-web', 'simple'))
    assert_equal 'simple-prod-api', @eb.environment_cname_prefix('simple', t('prod-api', 'simple'))
  end

  def test_cname_include_component_name_in_blue_green
    do_bg_deploy
    assert_equal 'simple-prod-web', @eb.environment_cname_prefix('simple', t('prod-web-a', 'simple'))

    do_bg_deploy
    assert_equal 'simple-prod-web', @eb.environment_cname_prefix('simple', t('prod-web-b', 'simple'))
    assert_equal 'simple-prod-web-inactive', @eb.environment_cname_prefix('simple', t('prod-web-a', 'simple'))
  end

  def test_components_inheritate_creation_options_from_environment
    do_deploy
    assert_equal 'WebServer', @eb.environment_tier('simple', t('prod-web', 'simple'))
  end

  def test_components_can_override_creation_opts
    do_deploy(:tier => 'WebServer',
              :components => [{'name' => 'web'}, {'name' => 'bg', 'tier' => "Worker"}])
    assert_equal 'WebServer', @eb.environment_tier('simple', t('prod-web', 'simple'))
    assert_equal 'Worker', @eb.environment_tier('simple', t('prod-bg', 'simple'))
  end

  def test_components_specific_eb_settings_will_override_env_eb_settings
    minsize_3 = {:namespace => 'aws:autoscaling:launchconfiguration',
      :option_name => 'MinSize',
      :value => '3' }
    minsize_2 = {:namespace => 'aws:autoscaling:launchconfiguration',
      :option_name => 'MinSize',
      :value => '2' }

    do_deploy(:option_settings => [minsize_3],
              :components => [{'name' => 'web'},
                              {'name' => 'api',
                                'option_settings' => [minsize_2]}])
    assert_equal [minsize_3], @eb.environment_settings('simple', t('prod-web', 'simple'))
    assert_equal [minsize_3, minsize_2], @eb.environment_settings('simple', t('prod-api', 'simple'))
  end

  def test_override_deployment_strategy
    do_deploy(:components => [{'name' => 'web',
                                'strategy' => 'blue-green' },
                              {'name' => 'bg',
                                'strategy' => 'inplace-update'}])

    assert @eb.environment_exists?('simple', t('prod-web-a', 'simple'))
    assert @eb.environment_exists?('simple', t('prod-bg', 'simple'))
  end

  def test_can_deploy_single_component
    do_deploy(:component => "bg")
    assert !@eb.environment_exists?('simple', t('prod-web', 'simple'))
    assert !@eb.environment_exists?('simple', t('prod-api', 'simple'))
    assert @eb.environment_exists?('simple', t('prod-bg', 'simple'))
  end

  def test_should_raise_exception_when_try_to_deploy_a_none_exists_component
    assert_raises(RuntimeError) do
      do_deploy(:component => "foo")
    end
  end


  def test_can_have_inactive_settings_which_will_be_applied_to_inactive_env
    settings = {:inactive_settings =>
      [{:namespace => 'aws:autoscaling:launchconfiguration',
         :option_name => 'MinSize',
         :value => 1}],
      :components =>
      [{:name => 'web',
         :option_settings =>
         [{:namespace => 'aws:autoscaling:launchconfiguration',
            :option_name => 'MinSize',
            :value => 10}]}]}

    do_bg_deploy(settings)
    assert_equal 10, @eb.environment_settings('simple', t('prod-web-a', 'simple')).last[:value]

    do_bg_deploy(settings)
    assert_equal 1, @eb.environment_settings('simple', t('prod-web-a', 'simple')).last[:value]
    assert_equal 10, @eb.environment_settings('simple', t('prod-web-b', 'simple')).last[:value]

    do_bg_deploy(settings)
    assert_equal 10, @eb.environment_settings('simple', t('prod-web-a', 'simple')).last[:value]
    assert_equal 1, @eb.environment_settings('simple', t('prod-web-b', 'simple')).last[:value]
  end

  def test_can_provide_inactive_settings_at_component_level
    settings = {:option_settings =>
      [{:namespace => 'aws:autoscaling:launchconfiguration',
         :option_name => 'MinSize',
         :value => 10}],
      :components =>
      [{:name => 'web',
         :inactive_settings =>
         [{:namespace => 'aws:autoscaling:launchconfiguration',
            :option_name => 'MinSize',
            :value => 2}]},
       {:name => 'api',
         :inactive_settings =>
         [{:namespace => 'aws:autoscaling:launchconfiguration',
            :option_name => 'MinSize',
            :value => 1}]}]}

    do_bg_deploy(settings)
    assert_equal 10, @eb.environment_settings('simple', t('prod-web-a', 'simple')).last[:value]
    assert_equal 10, @eb.environment_settings('simple', t('prod-api-a', 'simple')).last[:value]

    do_bg_deploy(settings)
    assert_equal 2, @eb.environment_settings('simple', t('prod-web-a', 'simple')).last[:value]
    assert_equal 1, @eb.environment_settings('simple', t('prod-api-a', 'simple')).last[:value]
  end

  def test_should_raise_error_when_deploy_work_tier_component_with_blue_green
    assert_raises(RuntimeError) do
      deploy(:application => 'simple',
             :environment => 'prod',
             :strategy => 'blue-green',
             :components => [{ 'name' => 'web' },
                             { 'name' => 'bg', 'tier' => 'worker' }])
    end
  end

  private
  def do_deploy(options={})
    deploy({:application => 'simple',
             :environment => 'prod',
             :components => [{ 'name' => 'web' },
                             { 'name' => 'bg' },
                             { 'name' => 'api' }]
           }.merge(options))
  end

  def do_bg_deploy(options={})
    do_deploy(options.merge(:strategy => 'blue-green'))
  end

end
