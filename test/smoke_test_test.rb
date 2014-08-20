require 'test_helper'

class SmokeTestTest < MiniTest::Unit::TestCase
  def test_call_proc_type_smoke_tests
    host_name_in_proc = nil
    stack_name_in_proc = nil
    EbDeployer::SmokeTest.new(lambda {|v, u| host_name_in_proc = v; stack_name_in_proc = u }).run("foo", "bar")
    
    assert_equal 'foo', host_name_in_proc
    assert_equal 'bar', stack_name_in_proc
  end

  def test_eval_string_type_smoke_test
    $host_name_in_proc = nil
    $stack_name_in_proc = nil
    EbDeployer::SmokeTest.new("$host_name_in_proc=host_name; $stack_name_in_proc=stack_name").run("foo", "bar")

    assert_equal 'foo', $host_name_in_proc
    assert_equal 'bar', $stack_name_in_proc
  end

  def test_should_raise_if_test_body_raise
    assert_raises(RuntimeError) do
      EbDeployer::SmokeTest.new("raise host_name").run("foo", "bar")
    end
  end

end
