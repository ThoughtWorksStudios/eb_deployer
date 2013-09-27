require 'test_helper'

class CloudFormationProvisionerTest < Minitest::Test
  def setup
    @cf = CFStub.new
    @provisioner = EbDeployer::CloudFormationProvisioner.new("myresources", @cf)
    @template = sample_file("sample_template.json")
  end


  def test_convert_inputs_as_params_to_cf
    @provisioner.provision(:template => @template,
                           :inputs => { 'Foo' => 'Bar' })

    assert_equal({ 'Foo' => 'Bar' }, @cf.stack_config("myresources")[:parameters])
  end

  def test_transform_to_eb_settings
    settings = @provisioner.provision(:template => @template,
                                      :outputs => {
                                        'S' => {
                                          'namespace' => "foo",
                                          "option_name" => "bar"
                                        }
                                      })
    assert_equal [{'namespace' => 'foo', 'option_name' => 'bar', 'value' => 'value of S'}], settings
  end
end
