require 'test_helper'

class ConfigLoaderTest < Test::Unit::TestCase
  def setup
    @loader = EbDeployer::ConfigLoader.new
    @sample_package = sample_file('app-package.war')
  end

  def test_all_default_cases
    config = @loader.load(generate_input(<<-YAML))
application: myapp
common:
  option_settings:
  resources:
environments:
  dev:
  production:
YAML
    assert_equal('myapp', config[:application])
    assert_equal(@sample_package, config[:package])
    assert_equal('dev', config[:environment])
    assert_equal(md5_digest(@sample_package), config[:version_label])
    assert_equal([], config[:option_settings])
    assert_equal(nil, config[:resources])
    assert_equal(nil, config[:common])
  end

  def test_use_package_as_version_label_when_using_s3_obj_as_package
    config = @loader.load(generate_input(<<-YAML, :package => 'bucket:obj'))
application: myapp
common:
  strategy: inplace-update
environments:
  dev:
YAML
    assert_equal('myapp', config[:application])
    assert_equal('bucket:obj', config[:package])
    assert_equal('bucket:obj', config[:version_label])
  end

  def test_common_settings_get_merge_into_the_config
    config = @loader.load(generate_input(<<-YAML))
application: myapp
common:
  strategy: inplace-update
  package_bucket: thoughtworks
  phoenix_mode: true
  option_settings:
    - namespace: aws:autoscaling:launchconfiguration
      option_name: InstanceType
      value: m1.small
  resources:
environments:
  dev:
  production:
YAML
    assert_equal('inplace-update', config[:strategy])
    assert_equal('thoughtworks', config[:package_bucket])
    assert_equal([{'namespace' => 'aws:autoscaling:launchconfiguration',
                    'option_name' => 'InstanceType',
                    'value' => 'm1.small'}], config[:option_settings])
  end

  def test_eval_random_hash
    yaml = <<-YAML
application: myapp
common:
  resources:
    template: config/my_rds.json
    inputs:
      DBPassword: <%= random_hash %>
environments:
  dev:
  production:
YAML
    first_time = @loader.load(generate_input(yaml))[:resources]['inputs']['DBPassword']
    second_time = @loader.load(generate_input(yaml))[:resources]['inputs']['DBPassword']
    assert first_time &&  second_time
    assert first_time != second_time
  end

  def test_environment_specific_setting_will_override_common_settings
    yaml = <<-YAML
application: myapp
common:
  phoenix_mode: true
environments:
  dev:
    phoenix_mode: false
  production:
YAML

    assert !@loader.load(generate_input(yaml, :environment => 'dev'))[:phoenix_mode]
    assert  @loader.load(generate_input(yaml, :environment => 'production'))[:phoenix_mode]
  end

  def test_env_specific_option_settings_will_merge_with_commons
    config = @loader.load(generate_input(<<-YAML, :environment => 'production'))
application: myapp
common:
  strategy: inplace-update
  phoenix_mode: true
  option_settings:
    - namespace: aws:autoscaling:launchconfiguration
      option_name: InstanceType
      value: m1.small
  resources:
environments:
  dev:
  production:
    option_settings:
      - namespace: aws:autoscaling:asg
        option_name: MinSize
        value: "2"
YAML
    assert_equal([{'namespace' => 'aws:autoscaling:launchconfiguration',
                    'option_name' => 'InstanceType',
                    'value' => 'm1.small'},
                  {'namespace' => 'aws:autoscaling:asg',
                    'option_name' => 'MinSize',
                    'value' => "2"}], config[:option_settings])
  end

  def test_env_is_required
   error = assert_raises(RuntimeError) {
      @loader.load(generate_input(<<-YAML, :environment => 'non_existant'))
application: myapp
common:
  strategy: inplace-update
environments:
  dev:
YAML
    }

    assert_match(/non_existant/, error.message)
  end

  def test_set_inactive_settings_at_common_level
    config = @loader.load(generate_input(<<-YAML, :environment => 'production'))
application: myapp
common:
  inactive_settings:
    - namespace: aws:autoscaling:asg
      option_name: MinSize
      value: "1"
environments:
  dev:
  production:
YAML
    assert_equal([{'namespace' => 'aws:autoscaling:asg',
                    'option_name' => 'MinSize',
                    'value' => '1'}], config[:inactive_settings])
  end

  def test_set_inactive_settings_at_env_level
    config = @loader.load(generate_input(<<-YAML, :environment => 'dev'))
application: myapp
common:
  inactive_settings:
    - namespace: aws:autoscaling:asg
      option_name: MinSize
      value: "1"
environments:
  dev:
    inactive_settings:
      - namespace: aws:autoscaling:asg
        option_name: MinSize
        value: "0"
  production:
YAML
    assert_equal([{'namespace' => 'aws:autoscaling:asg',
                    'option_name' => 'MinSize',
                    'value' => '0'}], config[:inactive_settings])
  end

  def test_access_environment_name_in_config_yml_file
    config = @loader.load(generate_input(<<-YAML, :environment => 'dev'))
application: myapp
common:
  resources:
    inputs:
      env: <%= environment %>
environments:
  dev:
  production:
YAML
    assert_equal('dev', config[:resources]['inputs']['env'])
  end

  private

  def md5_digest(file)
    Digest::MD5.file(file).hexdigest
  end

  def generate_input(config_file_content, overriding={})
    { :environment => 'dev',
      :package => @sample_package,
      :config_file => generate_config(config_file_content)}.merge(overriding)
  end

  def generate_config(content)
    sample_file('eb_deployer.yml', content)
  end
end
