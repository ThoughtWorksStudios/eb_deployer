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
      @strategy.test_compatibility(create_options)
      @strategy.deploy(version_label,
                       eb_settings + @component_eb_settings,
                       inactive_settings + @component_inactive_settings)
    end

    def new_eb_env(suffix=nil, cname_prefix_overriding=nil)
      EbEnvironment.new(@env.app_name,
                        [@env.name, @name, suffix].compact.join('-'),
                        @eb_driver,
                        create_options.merge(:cname_prefix => cname_prefix_overriding || cname_prefix))

    end

    private

    def create_options
      @env.creation_opts.merge(@options)
    end

    def default_cname_prefix
      [@env.app_name, @env.name, @name].join('-')
    end
  end
end
