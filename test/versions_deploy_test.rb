require 'deploy_test'

class VersionsDeployTest < DeployTest

  def test_deployment_with_s3_package_specification
    File.open('mingle_package.yml', 'w') do |f|
      f.write("s3_bucket: test-bucket\n")
      f.write("s3_key: test-mingle.war")
    end

    deploy(:application => 'simple', :environment => "production",
           :package => 'mingle_package.yml', :version_label => 1)
    assert @eb.application_exists?('simple')
    last_version = @eb.application_versions('simple').last
    assert_equal({'s3_bucket' => 'test-bucket', 's3_key' => 'test-mingle.war'}, last_version[:source_bundle])
  ensure
    FileUtils.rm_rf('mingle_package.yml')
  end



  def test_version_prefix_should_be_prepended_to_version_label
    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 1,
           :version_prefix => "prod-")
    assert_equal 'prod-1', @eb.environment_verion_label('simple', t('production', 'simple'))
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

    assert_equal '1', @eb.versions_deleted('simple').first
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

    assert_equal 'prod1-1', @eb.versions_deleted('simple').first
    assert_equal 1, @eb.versions_deleted('simple').count

    app_versions = @eb.application_versions('simple').map { |apv| apv[:version_label] }
    assert_equal ["prod1-2", "prod2-1"], app_versions
  end

  def test_default_cname_that_deployed_should_app_env_name
    deploy(:application => 'simple',
           :environment => "production",
           :version_label => 42)
    assert_equal "simple-production", @eb.environment_cname_prefix('simple', t('production', 'simple'))
  end

  def test_cname_prefix_can_be_override
    deploy(:application => 'simple',
           :environment => "production",
           :cname_prefix => 'sports123',
           :version_label => 42)
    assert_equal "sports123", @eb.environment_cname_prefix('simple', t('production', 'simple'))
  end

  def test_pass_s3_object_name_as_package_file
    package_name = 'test-bucket:test-mingle.war'

    deploy(:package => package_name,
           :application => 'simple',
           :environment => "production",
           :version_label => 1)

    assert @eb.application_exists?('simple')
    last_version = @eb.application_versions('simple').last
    assert_equal({'s3_bucket' => 'test-bucket', 's3_key' => 'test-mingle.war'}, last_version[:source_bundle])
  end

  def test_set_s3_bucket_name_on_deployment
    deploy(:application => 'simple',
           :environment => "production",
           :package_bucket => 'thoughtworks.simple')

    assert @s3_driver.bucket_exists?('thoughtworks.simple.packages')
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


end
