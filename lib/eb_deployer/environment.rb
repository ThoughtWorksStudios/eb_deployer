module EbDeployer
  class Environment

    def initialize(app, name, resource_stacks, settings, creation_opts, bs_driver)
      @app = app
      @name = name
      @resource_stacks = resource_stacks
      @settings = settings
      @creation_opts = creation_opts
      @bs_driver = bs_driver
    end

    def cname_prefix
      @creation_opts[:cname_prefix] || default_cname_prefix
    end

    def deploy(version_label, strategy_name)
      strategy = create_strategy(strategy_name)
      strategy.deploy(version_label,
                       @settings + @resource_stacks.provision(resource_stack_name))
    end

    def new_eb_env(suffix=nil, cname_prefix_overriding=nil)
      EbEnvironment.new(@app.name,
                        [@name, suffix].compact.join('-'),
                        @bs_driver,
                        @creation_opts.merge(:cname_prefix => cname_prefix_overriding || cname_prefix))
    end

    private

    def default_cname_prefix
      [@app.name, @name].join('-')
    end


    def create_strategy(strategy_name)
      DeploymentStrategy.create(self, strategy_name)
    end

    def resource_stack_name
      "#{@app.name}-#{@name}"
    end
  end
end
