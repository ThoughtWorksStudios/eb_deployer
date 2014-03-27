require 'deploy_test'
class LegacyEnvMigrateDeployTest < DeployTest

  def setup
    super
    @eb_driver.create_application("simple")
  end

  def test_should_clean_up_legacy_environment_in_inplace_update_deployment
    legacy_env_name = EbDeployer::EbEnvironment.legacy_ebenv_name("simple", "production")
    @eb_driver.create_environment("simple", legacy_env_name, 'solution-stack', 'simple-production', 'foo', 'web' ,{})
    deploy(:application => 'simple',
           :environment => 'production',
           :version_label => 1)
    assert @eb_driver.environment_exists?("simple", "production")
    assert !@eb_driver.environment_exists?("simple", legacy_env_name)
  end

  def test_should_clean_up_legacy_environment_in_blue_green_deployment
    legacy_a_env_name = EbDeployer::EbEnvironment.legacy_ebenv_name("simple", "production-a")
    legacy_b_env_name = EbDeployer::EbEnvironment.legacy_ebenv_name("simple", "production-b")

    @eb_driver.create_environment("simple", legacy_a_env_name, 'solution-stack', 'simple-production', 'foo', 'web' ,{})
    @eb_driver.create_environment("simple", legacy_b_env_name, 'solution-stack', 'simple-production-inactive', 'foo', 'web' ,{})

    deploy(:application => 'simple',
           :environment => 'production',
           :strategy => 'blue-green')


    assert !@eb_driver.environment_exists?("simple", legacy_b_env_name)
    assert @eb_driver.environment_exists?("simple", legacy_a_env_name)

    assert @eb_driver.environment_exists?("simple", "production-b")
    assert !@eb_driver.environment_exists?("simple", "production-a")

    assert_equal 'simple-production', @eb_driver.environment_cname_prefix('simple', 'production-b')
    assert_equal 'simple-production-inactive', @eb_driver.environment_cname_prefix('simple', legacy_a_env_name)

    deploy(:application => 'simple',
           :environment => 'production',
           :strategy => :blue_green)

    assert @eb_driver.environment_exists?("simple", "production-a")
    assert @eb_driver.environment_exists?("simple", "production-b")
    assert !@eb_driver.environment_exists?("simple", legacy_a_env_name)
    assert !@eb_driver.environment_exists?("simple", legacy_b_env_name)

    assert_equal 'simple-production', @eb_driver.environment_cname_prefix('simple', 'production-a')
    assert_equal 'simple-production-inactive', @eb_driver.environment_cname_prefix('simple', 'production-b')
  end

  def test_should_clean_up_legacy_environment_in_blue_green_deployment_when_only_active_en_is_there
    legacy_a_env_name = EbDeployer::EbEnvironment.legacy_ebenv_name("simple", "production-a")
    legacy_b_env_name = EbDeployer::EbEnvironment.legacy_ebenv_name("simple", "production-b")
    @eb_driver.create_environment("simple", legacy_a_env_name, 'solution-stack', 'simple-production', 'foo', 'web' ,{})

    deploy(:application => 'simple',
           :environment => 'production',
           :strategy => 'blue-green')


    assert @eb_driver.environment_exists?("simple", "production-b")
    assert !@eb_driver.environment_exists?("simple", "production-a")
    assert !@eb_driver.environment_exists?("simple", legacy_b_env_name)
    assert @eb_driver.environment_exists?("simple", legacy_a_env_name)

    assert_equal 'simple-production', @eb_driver.environment_cname_prefix('simple', 'production-b')
    assert_equal 'simple-production-inactive', @eb_driver.environment_cname_prefix('simple', legacy_a_env_name)

    deploy(:application => 'simple',
           :environment => 'production',
           :strategy => 'blue-green')

    assert @eb_driver.environment_exists?("simple", "production-a")
    assert @eb_driver.environment_exists?("simple", "production-b")
    assert !@eb_driver.environment_exists?("simple", legacy_a_env_name)
    assert !@eb_driver.environment_exists?("simple", legacy_b_env_name)

    assert_equal 'simple-production', @eb_driver.environment_cname_prefix('simple', 'production-a')
    assert_equal 'simple-production-inactive', @eb_driver.environment_cname_prefix('simple', 'production-b')

  end

  def test_terminate_legacy_environments
    legacy_a_env_name = EbDeployer::EbEnvironment.legacy_ebenv_name("simple", "production-a")
    legacy_b_env_name = EbDeployer::EbEnvironment.legacy_ebenv_name("simple", "production-b")
    @eb_driver.create_environment("simple", legacy_a_env_name, 'solution-stack', 'simple-production', 'foo', 'web' ,{})
    destroy(:application => 'simple')

    assert !@eb_driver.environment_exists?("simple", legacy_a_env_name)
    assert !@eb_driver.environment_exists?("simple", legacy_b_env_name)
  end
end
