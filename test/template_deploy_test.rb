require 'deploy_test'

class TemplateDeployTest < DeployTest
  def test_default_no_template
    deploy(:application => 'simple', :environment => "production")
    assert_equal nil, @eb.template_name('simple', t('production', 'simple'))
  end

  def test_can_set_a_template
    deploy(:application => 'simple', :environment => "production", :template_name => 'SomeTemplate')
    assert_equal 'SomeTemplate', @eb.template_name('simple', t('production', 'simple'))
  end
end
