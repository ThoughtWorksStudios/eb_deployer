require 'deploy_test'

class TierSettingDeployTest < DeployTest
  def test_sets_default_tier_as_webserver
    deploy(:application => 'simple', :environment => "production")
    assert_equal EbDeployer.environment_tier('WebServer'), @eb.environment_tier('simple', t('production', 'simple'))
  end

  def test_can_change_tier
    deploy(:application => 'simple', :environment => "production", :tier => 'Worker')
    assert_equal EbDeployer.environment_tier('Worker'), @eb.environment_tier('simple', t('production', 'simple'))
  end

  def test_should_raise_error_when_tier_setting_is_not_recognized
    assert_raises(RuntimeError) do
      deploy(:application => 'simple', :environment => "production", :tier => 'Gum')
    end
  end
end
