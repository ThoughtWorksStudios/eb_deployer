require 'test_helper'

class SmokeTestTest < Test::Unit::TestCase
  def test_call_proc_type_smoke_tests
    host_name_in_proc = nil
    EbDeployer::SmokeTest.new(lambda {|v| host_name_in_proc = v }).run("foo")

    assert_equal 'foo', host_name_in_proc
  end

  def test_eval_string_type_smoke_test
    $host_name_in_proc = nil
    EbDeployer::SmokeTest.new("$host_name_in_proc=host_name").run("foo")
    assert_equal 'foo', $host_name_in_proc
  end

  def test_should_raise_if_test_body_raise
    assert_raises(RuntimeError) do
      EbDeployer::SmokeTest.new("raise host_name").run("foo")
    end
  end

end
