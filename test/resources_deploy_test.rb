require 'deploy_test'

class ResourcesDeployTest < DeployTest

  def test_deploy_with_resources_declared_will_create_a_cf_stack_for_env
    cf_template = temp_file(JSON.dump({'Resources' => {'R1' => {}}}))
    deploy(:application => 'simple', :environment => "production",
           :resources => {
             :template => cf_template
           })
    assert @cf_driver.stack_exists?('simple-production')
    assert_equal({},  @cf_driver.stack_config('simple-production')[:parameters])
    assert_equal([],  @cf_driver.stack_config('simple-production')[:capabilities])
    assert_nil(@cf_driver.stack_config('simple-production')[:stack_policy_body])
  end

  def test_deploy_with_resources_declared_will_create_a_cf_stack_for_env_with_policy
    cf_template = temp_file(JSON.dump({'Resources' => {'R1' => {}}}))
    cf_policy = sample_file("sample_policy.json", JSON.dump({'Policy' => {'P1' => {}}}))
    deploy(:application => 'simple', :environment => "production",
           :resources => {
               :template => cf_template,
               :policy => cf_policy
           })
    assert @cf_driver.stack_exists?('simple-production')
    assert_equal({},  @cf_driver.stack_config('simple-production')[:parameters])
    assert_equal([],  @cf_driver.stack_config('simple-production')[:capabilities])
    assert_equal("{\"Policy\":{\"P1\":{}}}", @cf_driver.stack_config('simple-production')[:stack_policy_body])
  end

  def test_deploy_with_resources_declared_will_update_a_cf_stack_for_env_with_policy
    cf_template = temp_file(JSON.dump({'Resources' => {'R1' => {}}}))
    cf_policy = sample_file("sample_policy.json", JSON.dump({'Policy' => {'P1' => {}}}))
    deploy(:application => 'simple', :environment => "production",
           :resources => {
               :template => cf_template,
               :policy => cf_policy
           })
    assert @cf_driver.stack_exists?('simple-production')
    deploy(:application => 'simple', :environment => "production",
           :resources => {
               :template => cf_template,
               :policy => cf_policy,
               :override_policy => false
           })
    assert_equal({},  @cf_driver.stack_config('simple-production')[:parameters])
    assert_equal([],  @cf_driver.stack_config('simple-production')[:capabilities])
    assert_equal("{\"Policy\":{\"P1\":{}}}", @cf_driver.stack_config('simple-production')[:stack_policy_body])
  end

  def test_deploy_with_resources_declared_will_update_a_cf_stack_for_env_with_temp_policy
    cf_template = temp_file(JSON.dump({'Resources' => {'R1' => {}}}))
    cf_policy = sample_file("sample_policy.json", JSON.dump({'Policy' => {'P1' => {}}}))
    deploy(:application => 'simple', :environment => "production",
           :resources => {
               :template => cf_template,
               :policy => cf_policy
           })
    assert @cf_driver.stack_exists?('simple-production')
    deploy(:application => 'simple', :environment => "production",
           :resources => {
               :template => cf_template,
               :policy => cf_policy,
               :override_policy => true
           })
    assert_equal({},  @cf_driver.stack_config('simple-production')[:parameters])
    assert_equal([],  @cf_driver.stack_config('simple-production')[:capabilities])
    assert_equal("{\"Policy\":{\"P1\":{}}}", @cf_driver.stack_config('simple-production')[:stack_policy_during_update_body])
  end

  def test_provision_resources_with_capacities
    cf_template = temp_file(JSON.dump({'Resources' => {'R1' => {}}}))
    deploy(:application => 'simple', :environment => "production",
           :resources => {
             :template => cf_template,
             :capabilities => ['CAPABILITY_IAM']
           })
    assert_equal ['CAPABILITY_IAM'],  @cf_driver.stack_config('simple-production')[:capabilities]
  end

  def test_provision_resources_with_parameters
    cf_template = temp_file(JSON.dump({'Resources' => {'R1' => {}}}))
    deploy(:application => 'simple', :environment => "production",
           :resources => {
             :template => cf_template,
             :parameters => {'a' => 1}
           })
    assert_equal({'a' => 1 },  @cf_driver.stack_config('simple-production')[:parameters])
  end

  def test_skip_resource_update
    cf_template = temp_file(JSON.dump({'Resources' => {'R1' => {}}}))
    deploy(:application => 'simple', :environment => "production",
           :resources => {
             :template => cf_template,
             :parameters => {'a' => 1 }
           })
    assert_equal(1, @cf_driver.stack_config('simple-production')[:parameters]['a'])
    deploy(:application => 'simple', :environment => "production",
           :resources => {
             :template => cf_template,
             :parameters => {'a' => 2 }
           })
    assert_equal(2, @cf_driver.stack_config('simple-production')[:parameters]['a'])
    deploy(:application => 'simple',
           :environment => "production",
           :skip_resource_stack_update => true,
           :resources => {
             :template => cf_template,
             :parameters => {'a' => 3 }
           })
    assert_equal(2, @cf_driver.stack_config('simple-production')[:parameters]['a'])
  end

  def test_should_still_query_output_to_set_eb_options_even_skip_resources_update_is_specified
    cf_template = temp_file(JSON.dump({'Resources' => {'R1' => {}},
                                      'Outputs' => {'O1' => {}, 'O2' => {}}}))
    deploy(:application => 'simple', :environment => "production",
           :resources => {
             :template => cf_template
           })

    deploy(:application => 'simple', :environment => "production",
           :skip_resource_stack_update => true,
           :resources => {
             :template => cf_template,
             :transforms => {
               'O2' => lambda { |v| {:namespace => 'aws.foo', :option_name => 'o2', :value => "transformed " + v} }
             }
           })

    assert @eb.environment_settings('simple', t('production', 'simple')).
      include?({:namespace => 'aws.foo', :option_name => 'o2', :value => 'transformed value of O2'})
  end


  def test_transforms_resource_provsion_output_to_elastic_beanstalk_settings
    cf_template = temp_file(JSON.dump({
                                        'Resources' => {'R1' => {}},
                                        'Outputs' => {'O1' => {}, 'O2' => {}}
                                      }))
    deploy(:application => 'simple', :environment => "production",
           :resources => {
             :template => cf_template,
             :transforms => {
               'O1' => lambda { |v| {:namespace => 'aws.foo', :option_name => 'o1', :value => v} }
             }
           })
    assert @eb.environment_settings('simple', t('production', 'simple')).
      include?({:namespace => 'aws.foo', :option_name => 'o1', :value => 'value of O1'})
  end

  def test_can_query_resource_stack_output_after_deploy
    cf_template = temp_file(JSON.dump({
                                        'Resources' => {'R1' => {}},
                                        'Outputs' => {'O1' => {}, 'O2' => {}}
                                      }))
    deploy(:application => 'simple',
           :environment => "production",
           :resources => { :template => cf_template })
    assert_equal 'value of O1', query_resource_output('O1',
                                                      :application => 'simple',
                                                      :environment => "production")
    assert_equal 'value of O2', query_resource_output('O2',
                                                      :application => 'simple',
                                                      :environment => "production")

  end

  def test_should_raise_error_if_query_resources_that_have_not_been_provisioned_yet
    assert_raises(EbDeployer::ResourceNotInReadyState) do
      query_resource_output('O1',
                            :application => 'simple',
                            :environment => "production")
    end
  end

  def test_custom_stack_name
    cf_template = temp_file(JSON.dump({
                                        'Resources' => {'R1' => {}},
                                        'Outputs' => {'O1' => {}, 'O2' => {}}
                                      }))
    deploy(:application => 'simple',
           :environment => "production",
           :resources => { :template => cf_template },
           :stack_name => 'my-lovely-stack')

    assert !@cf_driver.stack_exists?('simple-production')
    assert @cf_driver.stack_exists?('my-lovely-stack')
  end
end
