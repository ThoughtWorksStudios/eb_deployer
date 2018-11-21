module EbDeployer
  class ResourceNotInReadyState < StandardError
  end

  class CloudFormationProvisioner
    SUCCESS_STATS = ["CREATE_COMPLETE", "UPDATE_COMPLETE"]
    FAILED_STATS = ["CREATE_FAILED", "UPDATE_FAILED", "UPDATE_ROLLBACK_COMPLETE"]

    def initialize(stack_name, cf_driver)
      @stack_name = stack_name
      @cf_driver = cf_driver
      @poller = EventPoller.new(CfEventSource.new(@stack_name, @cf_driver))
    end

    def provision(resources, tags)
      resources = symbolize_keys(resources)
      template = File.read(resources[:template])
      capabilities = resources[:capabilities] || []
      params = resources[:inputs] || resources[:parameters] || {}
      policy = File.read(resources[:policy]) if resources[:policy]
      override_policy = resources[:override_policy] || false
      anchor = nil
      begin
        if stack_exists?
          anchor = @poller.get_anchor
          update_stack(template, params, capabilities, policy, override_policy, tags)
        else
          create_stack(template, params, capabilities, policy, tags)
        end
      rescue Aws::CloudFormation::Errors::ValidationError => e
        if e.message =~ /No updates are to be performed/
          log(e.message)
          return
        else
          raise
        end
      end
      wait_for_stack_op_terminate(anchor)
      log("Resource stack provisioned successfully")
    end

    def transform_outputs(resources)
      resources = symbolize_keys(resources)
      outputs = resources[:outputs] || {}
      transforms = resources[:transforms] || {}
      transform_output_to_settings(convert_to_transforms(outputs).merge(transforms))
    end

    def output(key)
      @cf_driver.query_output(@stack_name, key)
    rescue Aws::CloudFormation::Errors::ValidationError
      raise ResourceNotInReadyState.new("Resource stack not in ready state yet, perhaps you should provision it first?")
    end

    private

    #todo: remove duplication
    def symbolize_keys(hash)
      hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
    end


    def convert_to_transforms(outputs)
      outputs.inject({}) do |memo, (key, value)|
        memo[key] = lambda { |output_value| value.merge('value' => output_value) }
        memo
      end
    end

    def update_stack(template, params, capabilities, policy, override_policy, tags)
      opts = {:capabilities => capabilities, :parameters => params, :tags => tags}
      if (policy)
        opts[:stack_policy_during_update_body] = policy if override_policy
        log("Using temporary stack policy to apply resource stack updates") if override_policy
        opts[:stack_policy_body] = policy unless override_policy
        log("Applying new stack policy to existing resource stack") unless override_policy
      end
      @cf_driver.update_stack(@stack_name, template, opts)
    end

    def stack_exists?
      @cf_driver.stack_exists?(@stack_name)
    end

    def create_stack(template, params, capabilities, policy, tags)
      opts = {:disable_rollback => true, :capabilities => capabilities, :parameters => params, :tags => tags}
      opts[:stack_policy_body] = policy if policy
      log("Applying stack policy to new resource stack") if policy
      @cf_driver.create_stack(@stack_name, template, opts)
    end

    def transform_output_to_settings(transforms)
      (transforms || []).inject([]) do |settings, pair|
        key, transform = pair
        settings << transform.call(output(key))
        settings
      end.flatten
    end

    def wait_for_stack_op_terminate(anchor)
      @poller.poll(anchor) do |event|
        log_event(event)
        if FAILED_STATS.include?(event.resource_status)
          raise "Resource stack update failed!"
        end

        break if event.logical_resource_id == @stack_name && SUCCESS_STATS.include?(event.resource_status)
      end
    end

    def log_event(event)
      puts "[#{event.timestamp}][cloud_formation_provisioner] #{event.resource_type}(#{event.logical_resource_id}) #{event.resource_status} \"#{event.resource_status_reason}\""
    end


    def log(msg)
      puts "[#{Time.now.utc}][cloud_formation_provisioner] #{msg}"
    end
  end
end
