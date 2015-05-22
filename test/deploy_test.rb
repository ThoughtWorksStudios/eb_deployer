require 'test_helper'

class DeployTest < Test::Unit::TestCase
  def setup
    @eb = ErrorRaisingWrapper.new(EBStub.new)
    @s3_driver = S3Stub.new
    @cf_driver = CFStub.new
    @sample_package = sample_file('app-package.war')
  end

  protected

  def temp_file(content)
    f = Tempfile.new("foo")
    f.write(content)
    f
  end

  def query_resource_output(key, opts)
    EbDeployer.query_resource_output(key, {:bs_driver => @eb,
                                       :s3_driver => @s3_driver,
                                       :cf_driver => @cf_driver}.merge(opts))
  end

  def deploy(opts)
    @eb.mark_all_envs_ready
    EbDeployer.deploy({:package => @sample_package,
                        :strategy => :'inplace-update',
                        :version_label => 1}.merge(opts).merge(stubs))
  end

  def destroy(opts)
    EbDeployer.destroy(opts.merge(stubs))
  end

  def stubs
    { :bs_driver => @eb,
      :s3_driver => @s3_driver,
      :cf_driver => @cf_driver
    }
  end
end
