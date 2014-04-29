require 'test_helper'

class ConfigurationTest < MiniTest::Unit::TestCase
  def setup
    @config = EbDeployer::Configuration.new('simple', 'prod')
  end

  def test_default_values
    assert_equal 'simple', @config.application
    assert_equal 'prod', @config.environment

    assert_nil @config.version_label
    assert_nil @config.version_prefix
    assert_nil @config.keep_latest
    assert_equal [], @config.option_settings
    assert_equal [], @config.inactive_settings
    assert_nil @config.region
    assert_nil @config.package
    assert_nil @config.resources
    assert_nil @config.package_bucket
    assert_equal false, @config.phoenix_mode
    assert_equal 'blue-green', @config.strategy
    assert_nil @config.smoke_test
    assert_equal '64bit Amazon Linux 2014.02 v1.0.1 running Tomcat 7 Java 7', @config.solution_stack_name
    assert_equal 'WebServer', @config.tier
  end

  def test_merge_should_generate_new_config_with_overridden_value
    config = @config.merge(:tier => 'Worker', :strategy => 'inplace-update')
    assert config.object_id != @config.object_id
    assert_equal 'Worker', config.tier
    assert_equal 'inplace-update', config.strategy
  end

  def test_merge_with_string_keys
    config = @config.merge('tier' => 'Worker', 'strategy' => 'inplace-update')
    assert_equal 'Worker', config.tier
    assert_equal 'inplace-update', config.strategy
  end

  def test_should_merge_content_of_option_settings
    config = @config.merge(:option_settings => [{'namespace' => 'aws:autoscaling:launchconfiguration',
                                                  'option_name' => 'InstanceType',
                                                  'value' => 'm1.small'}]).
      merge(:option_settings => [{'namespace' => 'aws:autoscaling:asg',
                                   'option_name' => 'MinSize',
                                   'value' => "2"}])

    assert_equal([{'namespace' => 'aws:autoscaling:launchconfiguration',
                    'option_name' => 'InstanceType',
                    'value' => 'm1.small'},
                  {'namespace' => 'aws:autoscaling:asg',
                    'option_name' => 'MinSize',
                    'value' => "2"}], config.option_settings)
  end

end
