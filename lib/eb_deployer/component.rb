module EbDeployer
  class Component
    def initialize(name, env, creation_opts, eb_driver)
      @name = name
      @env = env
      @eb_driver = eb_driver
      @creation_opts = creation_opts
    end

    def cname_prefix
      @creation_opts[:cname_prefix] || default_cname_prefix
    end


    def deploy(version_label, strategy_name, eb_settings)
      strategy = create_strategy(strategy_name)
      strategy.deploy(version_label, eb_settings)
    end

    def new_eb_env(suffix=nil, cname_prefix_overriding=nil)
      EbEnvironment.new(@env.app_name,
                        [@env.name, @name, suffix].compact.join('-'),
                        @eb_driver,
                        @creation_opts.merge(:cname_prefix => cname_prefix_overriding || cname_prefix))
    end

    private

    def default_cname_prefix
      [@env.app_name, @env.name, @name].join('-')
    end

    def create_strategy(strategy_name)
      DeploymentStrategy.create(self, strategy_name)
    end

  end
end
