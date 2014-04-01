module EbDeployer
  class Component
    attr_reader :name

    def initialize(name, env, creation_opts, eb_settings, strategy_name, eb_driver)
      @name = name
      @env = env
      @eb_driver = eb_driver
      @creation_opts = creation_opts
      @eb_settings = eb_settings
      @strategy = DeploymentStrategy.create(self, strategy_name)
    end

    def cname_prefix
      @creation_opts[:cname_prefix] || default_cname_prefix
    end

    def deploy(version_label, eb_settings)
      @strategy.deploy(version_label, eb_settings + @eb_settings)
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
  end
end
