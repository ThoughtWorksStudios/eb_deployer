$:.unshift(File.expand_path("../../lib", __FILE__))

require 'tempfile'
require 'eb_deployer'
require 'aws_driver_stubs'
require 'minitest/autorun'
require 'minitest/pride'


class Minitest::Test
  def sample_file(file_name, content='s' * 100)
    path = File.join('/tmp', file_name)
    File.open(path, 'w') { |f| f << content }
    path
  end
end
