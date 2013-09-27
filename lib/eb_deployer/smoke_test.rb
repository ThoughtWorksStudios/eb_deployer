module EbDeployer
  class SmokeTest
    def initialize(test_body)
      @test_body = test_body
    end

    def run(host_name, logger=nil)
      return unless @test_body
      logger.log("running smoke test for #{host_name}...") if logger

      case @test_body
      when Proc
        @test_body.call(host_name)
      when String
        eval(@test_body, binding)
      else
        raise "smoke test can only be a string to evaluate or a proc object such as lambda"
      end

      logger.log("smoke test succeeded.") if logger
    end
  end
end
