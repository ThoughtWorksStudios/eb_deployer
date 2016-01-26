require 'test_helper'

class BeanstalkTest < Test::Unit::TestCase

  class StubbedCnameResponder
    def initialize(stubbed_response)
      @stubbed_response = stubbed_response
    end

    def describe_environments(options)
      {:environments => [@stubbed_response.merge(:status => "online")]}
    end
  end

  def test_cname_prefix_will_parse_both_legacy_and_regionalized_domains
    legacy_domain = "mingle-saas.elasticbeanstalk.com"
    regionalized_domain = "mingle-saas.us-west-1.elasticbeanstalk.com"

    assert_equal "mingle-saas", EbDeployer::AWSDriver::Beanstalk.new(StubbedCnameResponder.new(:cname => legacy_domain)).environment_cname_prefix("mingle", "saas")
    assert_equal "mingle-saas", EbDeployer::AWSDriver::Beanstalk.new(StubbedCnameResponder.new(:cname => regionalized_domain)).environment_cname_prefix("mingle", "saas")
  end

end
