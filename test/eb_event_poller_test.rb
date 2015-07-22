require 'test_helper'

class EbEventPollerTest < Test::Unit::TestCase
  def setup
    @eb = EBStub.new
    @poller = EbDeployer::EventPoller.new(EbDeployer::EbEventSource.new("myapp", "test", @eb))
  end

  def test_run_handle_block_through_all_events_when_there_is_no_from_anchor
    messages_handled = []
    @eb.set_events('myapp', 'test', ['a', 'b', nil])
    @poller.poll(nil) do |event|
      break if event[:message].nil?
      messages_handled << event[:message]
    end

    assert_equal ['a', 'b'], messages_handled
  end


  def test_can_poll_all_events_after_an_anchor
    @eb.set_events('myapp', 'test', ['a', 'b'], ['c', 'd', nil])
    anchor = @poller.get_anchor
    messages_handled = []
    @poller.poll(anchor) do |event|
      break if event[:message].nil?
      messages_handled << event[:message]
    end

    assert_equal ['c', 'd'], messages_handled
  end
end
