require 'test_helper'

class CfEventPollerTest < Test::Unit::TestCase
  def setup
    @cf = CFStub.new
    @poller = EbDeployer::EventPoller.new(EbDeployer::CfEventSource.new("mystack", @cf))
  end

  def test_run_handle_block_through_all_events_when_there_is_no_from_anchor
    messages_handled = []
    @cf.set_events('mystack', ['a', 'b', nil])
    @poller.poll(nil) do |event|
      break if event.resource_status.nil?
      messages_handled << event.resource_status
    end

    assert_equal ['a', 'b'], messages_handled
  end


  def test_can_poll_all_events_after_an_anchor
    @cf.set_events('mystack', ['a', 'b'], ['c', 'd', nil])
    anchor = @poller.get_anchor
    messages_handled = []
    @poller.poll(anchor) do |event|
      break if event.resource_status.nil?
      messages_handled << event.resource_status
    end

    assert_equal ['c', 'd'], messages_handled
  end
end
