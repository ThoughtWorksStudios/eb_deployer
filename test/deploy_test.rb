require 'test_helper'

class DeployTest < MiniTest::Unit::TestCase
  def setup
    @eb_driver = EBStub.new
    @s3_driver = S3Stub.new
    @cf_driver = CFStub.new
    @sample_package = sample_file('app-package.war')
  end

  def test_deployment_with_s3_package_specification
    File.open('mingle_package.yml', 'w') do |f|
      f.write("s3_bucket: test-bucket\n")
      f.write("s3_key: test-mingle.war")
    end

    deploy(:application => 'simple', :environment => "production",
           :package => 'mingle_package.yml', :version_label => 1)
    assert @eb_driver.application_exists?('simple')
    last_version = @eb_driver.application_versions('simple').last
    assert_equal({'s3_bucket' => 'test-bucket', 's3_key' => 'test-mingle.war'}, last_version[:source_bundle])
  ensure
    FileUtils.rm_rf('mingle_package.yml')
  end

  def test_first_deployment_create_eb_application
    assert !@eb_driver.application_exists?('simple')
    deploy(:application => 'simple', :environment => "production")
    assert @eb_driver.application_exists?('simple')
  end

  def test_set_option_settings_on_deployment
    redudant = [{:namespace => 'aws:autoscaling:launchconfiguration',
                                  :option_name => 'MinSize',
                                  :value => '2' }]
    deploy(:application => 'simple', :environment => "production",
           :option_settings => [redudant])

    assert_equal [redudant], @eb_driver.environment_settings('simple', eb_envname('simple', 'production'))

  end

  def test_destroy_should_clean_up_eb_application_and_env
    deploy(:application => 'simple', :environment => "production")
    destroy(:application => 'simple')
    assert !@eb_driver.application_exists?('simple')
    assert !@eb_driver.environment_exists?('simple', eb_envname('simple', 'production'))
  end

  def test_first_deployment_create_environment
    assert !@eb_driver.environment_exists?('simple', eb_envname('simple', 'production'))
    deploy(:application => 'simple', :environment => "production")
    assert @eb_driver.environment_exists?('simple', eb_envname('simple', 'production'))
  end

  def test_support_very_very_long_app_name
    deploy(:application => 'ver-very-simple-application', :environment => "production")
    assert @eb_driver.environment_exists?('ver-very-simple-application', eb_envname('ver-very-simple-application', 'production'))
  end

  def test_should_raise_error_when_env_name_is_too_long
    assert_raises(RuntimeError) { deploy(:application => 'simple', :environment => "p" * 16) }
  end

  def test_update_environment_with_new_version_should_change_version_that_deployed
    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 1)
    assert_equal '1', @eb_driver.environment_verion_label('simple', eb_envname('simple', 'production'))

    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 2)

    assert_equal '2', @eb_driver.environment_verion_label('simple', eb_envname('simple', 'production'))
  end

  def test_version_prefix_should_be_prepended_to_version_label
    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 1,
           :version_prefix => "prod-")
    assert_equal 'prod-1', @eb_driver.environment_verion_label('simple', eb_envname('simple', 'production'))
  end

  def test_should_keep_only_number_of_versions_specified
    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 1)

    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 2)

    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 3,
           :keep_latest => 2)

    assert_equal '1', @eb_driver.versions_deleted('simple').first
  end

  def test_should_only_remove_versions_with_matching_prefix
    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 1,
           :version_prefix => "prod1-",
           :keep_latest => 1)
    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 2,
           :version_prefix => "prod1-",
           :keep_latest => 1)
    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 1,
           :version_prefix => "prod2-",
           :keep_latest => 1)

    assert_equal 'prod1-1', @eb_driver.versions_deleted('simple').first
    assert_equal 1, @eb_driver.versions_deleted('simple').count

    app_versions = @eb_driver.application_versions('simple').map { |apv| apv[:version_label] }
    assert_equal ["prod1-2", "prod2-1"], app_versions
  end

  def test_default_cname_that_deployed_should_app_env_name
    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 42)
    assert_equal "simple-production", @eb_driver.environment_cname_prefix('simple', eb_envname('simple', 'production'))
  end

  def test_cname_prefix_can_be_override
    deploy(:application => 'simple',
           :environment => "production",
           :cname_prefix => 'sports123',
           :version_label => 42)
    assert_equal "sports123", @eb_driver.environment_cname_prefix('simple', eb_envname('simple', 'production'))
  end

  def test_smoke_test_should_be_run_after_env_created_or_update
    host_for_smoke_test = nil
    deploy(:application => 'simple',
           :environment => "production",
           :cname_prefix => 'foobar',
           :smoke_test => lambda { |host| host_for_smoke_test = host },
           :version_label => 42)
    assert_equal 'foobar.elasticbeanstalk.com', host_for_smoke_test

    host_for_smoke_test = nil
    deploy(:application => 'simple',
           :environment => "production",
           :cname_prefix => 'foobar',
           :smoke_test => lambda { |host| host_for_smoke_test = host },
           :version_label => 43)

    assert_equal 'foobar.elasticbeanstalk.com', host_for_smoke_test
  end

  def test_blue_green_deployment_strategy_should_create_blue_env_on_first_deployment
    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 42)

    assert @eb_driver.environment_exists?('simple', eb_envname('simple', 'production-a'))
    assert_equal 'simple-production',  @eb_driver.environment_cname_prefix('simple', eb_envname('simple', 'production-a'))
  end


  def test_blue_green_deployment_should_create_green_env_if_blue_exists
    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 42)

    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 43)

    assert @eb_driver.environment_exists?('simple', eb_envname('simple', 'production-a'))
    assert @eb_driver.environment_exists?('simple', eb_envname('simple', 'production-b'))
  end


  def test_blue_green_deployment_should_swap_cname_to_make_active_most_recent_updated_env
    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 42)

    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 43)

    assert_match(/simple-production-inactive/,  @eb_driver.environment_cname_prefix('simple', eb_envname('simple', 'production-a')))

    assert_equal 'simple-production',  @eb_driver.environment_cname_prefix('simple', eb_envname('simple', 'production-b'))


    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 44)

    assert_match(/simple-production-inactive/,  @eb_driver.environment_cname_prefix('simple', eb_envname('simple', 'production-b')))

    assert_equal 'simple-production',  @eb_driver.environment_cname_prefix('simple', eb_envname('simple', 'production-a'))
  end


  def test_blue_green_deploy_should_run_smoke_test_before_cname_switch
    smoked_host = []
    smoke_test = lambda { |host| smoked_host << host }
    [42, 43, 44].each do |version_label|
      deploy(:application => 'simple',
             :environment => "production",
             :strategy => 'blue-green',
             :smoke_test => smoke_test,
             :version_label => version_label)
    end

    assert_equal ['simple-production.elasticbeanstalk.com',
                  'simple-production-inactive.elasticbeanstalk.com',
                  'simple-production-inactive.elasticbeanstalk.com'], smoked_host
  end

  def test_deploy_with_resources_declared_will_create_a_cf_stack_for_env
    cf_template = temp_file(JSON.dump({'Resources' => {'R1' => {}}}))
    deploy(:application => 'simple', :environment => "production",
           :resources => {
             :template => cf_template
           })
    assert @cf_driver.stack_exists?('simple-production')
    assert_equal({},  @cf_driver.stack_config('simple-production')[:parameters])
    assert_equal([],  @cf_driver.stack_config('simple-production')[:capabilities])
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

    assert @eb_driver.environment_settings('simple', eb_envname('simple', 'production')).
      include?({:namespace => 'aws.foo', :option_name => 'o2', :value => 'transformed value of O2'})
  end


  def test_set_s3_bucket_name_on_deployment
    deploy(:application => 'simple',
           :environment => "production",
           :package_bucket => 'thoughtworks.simple')

    assert @s3_driver.bucket_exists?('thoughtworks.simple.packages')
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
    assert @eb_driver.environment_settings('simple', eb_envname('simple', 'production')).
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

  def test_should_terminate_old_environment_if_phoenix_mode_is_enabled
    deploy(:application => 'simple', :environment => "production", :phoenix_mode => true)
    assert @eb_driver.environment_exists?('simple', eb_envname('simple', 'production'))
    deploy(:application => 'simple', :environment => "production", :phoenix_mode => true)
    assert @eb_driver.environments_been_deleted('simple').include?(eb_envname('simple', 'production'))
    assert @eb_driver.environment_exists?('simple', eb_envname('simple', 'production'))
  end

  def test_blue_green_deployment_should_delete_and_recreate_inactive_env_if_phoenix_mode_is_enabled
    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 42,
           :phoenix_mode => true)

    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 43,
           :phoenix_mode => true)

    assert_equal [],  @eb_driver.environments_been_deleted('simple')

    inactive_env = eb_envname('simple', 'production-a')
    assert_match(/inactive/,  @eb_driver.environment_cname_prefix('simple', inactive_env))


    deploy(:application => 'simple',
           :environment => "production",
           :strategy => 'blue-green',
           :version_label => 44,
           :phoenix_mode => true)

    assert_equal [inactive_env], @eb_driver.environments_been_deleted('simple')

    assert_equal 'simple-production',  @eb_driver.environment_cname_prefix('simple', inactive_env)
  end

  def test_pass_pathname_as_package_file
    deploy(:package => Pathname.new(@sample_package),
           :application => 'simple',
           :environment => "production",
           :package_bucket => 'thoughtworks.simple')

    s3_objects = @s3_driver.objects('thoughtworks.simple.packages')
    assert_equal 1, s3_objects.size
    assert_equal @sample_package, s3_objects.values.first.to_s
  end

  def test_pass_s3_object_name_as_package_file
    package_name = '512.zip'

    @s3_driver.create_bucket('thoughtworks.simple')
    @s3_driver.upload_file('thoughtworks.simple', package_name, true)

    deploy(:package => package_name,
           :application => 'simple',
           :environment => "production",
           :package_bucket => 'thoughtworks.simple')

    s3_objects = @s3_driver.objects('thoughtworks.simple.packages')
    assert_equal 1, s3_objects.size
    assert_equal package_name, s3_objects.values.first.to_s
  end

  private

  def temp_file(content)
    f = Tempfile.new("foo")
    f.write(content)
    f
  end

  def query_resource_output(key, opts)
    EbDeployer.query_resource_output(key, {:bs_driver => @eb_driver,
                                       :s3_driver => @s3_driver,
                                       :cf_driver => @cf_driver}.merge(opts))
  end

  def deploy(opts)
    EbDeployer.deploy({:package => @sample_package,
                        :strategy => :'inplace-update',
                        :version_label => 1}.merge(opts).merge(stubs))
  end

  def destroy(opts)
    EbDeployer.destroy(opts.merge(stubs))
  end

  def stubs
    { :bs_driver => @eb_driver,
      :s3_driver => @s3_driver,
      :cf_driver => @cf_driver
    }
  end
end
