$:.unshift(File.expand_path("../../lib", __FILE__))

require 'tempfile'
require 'eb_deployer'
require 'aws_driver_stubs'
require 'minitest/autorun'
require 'minitest/pride'


class MiniTest::Unit::TestCase
  def sample_file(file_name, content='s' * 100)
    path = File.join('/tmp', file_name)
    File.open(path, 'w') { |f| f << content }
    path
  end

  def t(env, app_name)
    EbDeployer::EbEnvironment.unique_ebenv_name(env, app_name)
  end
end
