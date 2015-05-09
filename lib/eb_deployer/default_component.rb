module EbDeployer
  class DefaultComponent
    def initialize(env, creation_opts, strategy_name, eb_driver)
      @env = env
      @eb_driver = eb_driver
      @creation_opts = creation_opts
      @strategy = DeploymentStrategy.create(self, strategy_name)
    end

    def cname_prefix
      @creation_opts[:cname_prefix] || default_cname_prefix
    end

    def deploy(version_label, eb_settings, inactive_settings=[])
      @strategy.test_compatibility(@creation_opts)
      @strategy.deploy(version_label, eb_settings, inactive_settings)
    end

    def new_eb_env(suffix=nil, cname_prefix_overriding=nil)
      EbEnvironment.new(@env.app_name,
                        [@env.name, suffix].compact.join('-'),
                        @eb_driver,
                        @creation_opts.merge(:cname_prefix => cname_prefix_overriding || cname_prefix))
    end

    private

    def default_cname_prefix
      [@env.app_name, @env.name].join('-')
    end
  end
end
