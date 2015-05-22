require 'test_helper'

class CloudFormationProvisionerTest < Test::Unit::TestCase
  def setup
    @cf = CFStub.new
    @provisioner = EbDeployer::CloudFormationProvisioner.new("myresources", @cf)
    @template = sample_file("sample_template.json")
  end


  def test_convert_inputs_as_params_to_cf
    resources = { 'template' => @template, 'inputs' => { 'Foo' => 'Bar' } }
    @provisioner.provision(resources)

    assert_equal({ 'Foo' => 'Bar' }, @cf.stack_config("myresources")[:parameters])
  end

  def test_transform_to_eb_settings
    resources = { 'template' => @template,
      'outputs' => {
        'S' => {
          'namespace' => "foo",
          "option_name" => "bar"
        }
      }}

    @provisioner.provision(resources)
    settings = @provisioner.transform_outputs(resources)
    assert_equal [{'namespace' => 'foo', 'option_name' => 'bar', 'value' => 'value of S'}], settings
  end
end
