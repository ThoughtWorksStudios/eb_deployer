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
    do_deploy(:components => [:name => 'web'])
    assert_equal 'WebServer', @eb.environment_tier('simple', t('prod-web', 'simple'))
  end

  def test_components_can_override_creation_opts
    do_deploy(:tier => 'WebServer',
              :components => [{:name => 'web'}, {:name => 'bg', :tier => "Worker"}])
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
              :components => [{:name => 'web'},
                              {:name => 'api',
                                :option_settings => [minsize_2]}])
    assert_equal [minsize_3], @eb.environment_settings('simple', t('prod-web', 'simple'))
    assert_equal [minsize_3, minsize_2], @eb.environment_settings('simple', t('prod-api', 'simple'))

  end


  private
  def do_deploy(options={})
    deploy({:application => 'simple',
             :environment => 'prod',
             :components => [{ :name => 'web' },
                             { :name => 'bg' },
                             { :name => 'api' }]
           }.merge(options))

  end

  def do_bg_deploy
    do_deploy(:strategy => 'blue-green')
  end

end
