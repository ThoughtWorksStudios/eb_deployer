require 'deploy_test'
class LegacyEnvMigrateDeployTest < DeployTest
  def test_should_clean_up_legacy_environment_in_inplace_update_deployment
    legacy_env_name = EbDeployer::EbEnvironment.legacy_ebenv_name("simple", "production")
    @eb_driver.create_application("simple")
    @eb_driver.create_environment("simple", legacy_env_name, 'solution-stack', 'simple-production', 'foo', 'web' ,{})
    deploy(:application => 'simple',
           :environment => 'production',
           :version_label => 1)
    assert @eb_driver.environment_exists?("simple", "production")
    assert !@eb_driver.environment_exists?("simple", legacy_env_name)
  end
end
