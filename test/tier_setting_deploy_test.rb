require 'deploy_test'

class TierSettingDeployTest < DeployTest
  def test_sets_default_tier_as_webserver
    deploy(:application => 'simple', :environment => "production")
    assert_equal 'WebServer', @eb.environment_tier('simple', t('production', 'simple'))
  end

  def test_can_change_tier
    deploy(:application => 'simple', :environment => "production", :tier => 'Worker')
    assert_equal 'Worker', @eb.environment_tier('simple', t('production', 'simple'))
  end

  def test_should_worker_tier_should_not_have_cname_prefix
    deploy(:application => 'simple', :environment => "production", :tier => 'Worker')
    assert_nil @eb.environment_cname_prefix('simple', t('production', 'simple'))
  end

  def test_should_raise_error_when_deploy_worker_tier_with_blue_green
    assert_raises(RuntimeError) do
      deploy(:application => 'simple', :environment => "production", :tier => 'Worker', :strategy => 'blue-green')
    end
  end
end
