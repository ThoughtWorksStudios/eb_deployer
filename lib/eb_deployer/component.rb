module EbDeployer
  class Component
    attr_reader :name

    def initialize(name, env, options, eb_driver)
      @name = name
      @env = env
      @eb_driver = eb_driver
      @options = options.dup
      @component_eb_settings = @options.delete(:option_settings) || []
      @component_inactive_settings = @options.delete(:inactive_settings) || []
      strategy_name = @options[:strategy] || @env.strategy_name
      @strategy = DeploymentStrategy.create(self, strategy_name)
    end

    def cname_prefix
      @options[:cname_prefix] || default_cname_prefix
    end

    def deploy(version_label, eb_settings, inactive_settings=[])
      @strategy.deploy(version_label,
                       eb_settings + @component_eb_settings,
                       inactive_settings + @component_inactive_settings)
    end

    def new_eb_env(suffix=nil, cname_prefix_overriding=nil)
      env_name = [@env.name, @name, suffix].compact.join('-')
      creation_opts = @env.creation_opts.merge(@options)
      creation_opts = creation_opts.merge(:cname_prefix => cname_prefix_overriding || cname_prefix)
      EbEnvironment.new(@env.app_name,
                        env_name,
                        @eb_driver,
                        creation_opts)

    end

    private

    def default_cname_prefix
      [@env.app_name, @env.name, @name].join('-')
    end
  end
end
