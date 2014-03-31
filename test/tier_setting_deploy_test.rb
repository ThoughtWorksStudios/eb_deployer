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
end
