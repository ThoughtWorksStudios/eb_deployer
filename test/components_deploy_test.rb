require 'deploy_test'

class ComponentsDeployTest < DeployTest
  def test_deploy_with_components
    deploy(:application => 'simple',
           :environment => 'production',
           :components => [{ :name => 'web' },
                           { :name => 'bg' },
                           { :name => 'api' }
                          ])

    assert @eb.environment_exists?('simple', t('production-web', 'simple'))
    assert @eb.environment_exists?('simple', t('production-bg', 'simple'))
    assert @eb.environment_exists?('simple', t('production-api', 'simple'))
    assert !@eb.environment_exists?('simple', t('production', 'simple'))
  end
end
