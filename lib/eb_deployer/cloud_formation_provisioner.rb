module EbDeployer
  class ResourceNotInReadyState < StandardError
  end

  class CloudFormationProvisioner
    SUCCESS_STATS = [:create_complete, :update_complete, :update_rollback_complete]
    FAILED_STATS = [:create_failed, :update_failed]

    def initialize(stack_name, cf_driver)
      @stack_name = stack_name
      @cf_driver = cf_driver
    end

    def provision(resources)
      params = extract_params
      template = File.read(resources[:template])
      transforms = resources[:transforms]
      capabilities = resources[:capabilities] || []

      stack_exists? ? update_stack(template, params, capabilities) : create_stack(template, params, capabilities)
      wait_for_stack_op_terminate
      transform_output_to_settings(transforms)
    end

    def output(key)
      @cf_driver.query_output(@stack_name, key)
    rescue AWS::CloudFormation::Errors::ValidationError => e
      raise ResourceNotInReadyState.new("Resource stack not in ready state yet, perhaps you should provision it first?")
    end

    private

    def update_stack(template, params, capabilities)
      @cf_driver.update_stack(@stack_name, template,
                              :capabilities => capabilities,
                              :parameters => params)
    end

    def stack_exists?
      @cf_driver.stack_exists?(@stack_name)
    end

    def create_stack(template, params, capabilities)
      @cf_driver.create_stack(@stack_name, template,
                              :disable_rollback => true,
                              :capabilities => capabilities,
                              :parameters => params)
    end

    def stack_status
      @cf_driver.stack_status(@stack_name)
    end

    def transform_output_to_settings(transforms)
      (transforms || []).inject([]) do |settings, pair|
        key, transform = pair
        settings << transform.call(output(key))
        settings
      end.flatten
    end

    def wait_for_stack_op_terminate
      stats = stack_status
      while !SUCCESS_STATS.include?(stats)
        sleep 15
        stats = stack_status
        raise "Resource stack update failed!" if FAILED_STATS.include?(stats)
        log "current status: #{stack_status}"
      end
    end


    def extract_params
      Hash[ENV.map {|k, v| k =~ /^AWSRESOURCES_(.*)/ ? [$1, v] : nil }.compact]
    end

    def log(msg)
      puts "[#{Time.now.utc}][resources-stack] #{msg}"
    end
  end
end
