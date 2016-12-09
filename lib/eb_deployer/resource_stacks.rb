module EbDeployer
  class ResourceStacks
    def initialize(resources, cf_driver, skip_provision=false, tags)
      @resources = resources
      @cf_driver = cf_driver
      @skip_provision = skip_provision
      @tags = {}
      if tags != nil
        @tags = tags.map{ |row| {key: row[0], value: row[1]} }
      end
    end

    def provision(stack_name)
      provisioner = CloudFormationProvisioner.new(stack_name, @cf_driver)
      if @resources
        provisioner.provision(@resources, @tags) unless @skip_provision
        provisioner.transform_outputs(@resources)
      else
        []
      end
    end
  end
end
