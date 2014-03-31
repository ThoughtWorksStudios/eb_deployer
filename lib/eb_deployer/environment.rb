module EbDeployer
  class Environment
    attr_writer :resource_stacks, :settings, :creation_opts, :components
    attr_reader :name

    def initialize(app, name, eb_driver, &block)
      @app = app
      @name = name
      @eb_driver = eb_driver
      @creation_opts = {}
      @settings = []
      yield(self) if block_given?
      unless @components
        @components = [DefaultComponent.new(self, @creation_opts, @eb_driver)]
      end
    end

    def app_name
      @app.name
    end

    def deploy(version_label, strategy_name)
      resource_settings = @resource_stacks.provision(resource_stack_name)
      @components.each do |component|
        component.deploy(version_label, strategy_name, @settings + resource_settings)
      end
    end

    def components=(components_attrs)
      return unless components_attrs
      @components = components_attrs.map do |attrs|
        attrs = symbolize_keys(attrs)
        name = attrs.delete(:name)
        eb_settings = attrs.delete(:option_settings) || []
        Component.new(name, self, @creation_opts.merge(attrs), eb_settings, @eb_driver)
      end
    end

    private
    def symbolize_keys(hash)
      hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
    end

    def resource_stack_name
      "#{app_name}-#{@name}"
    end

  end
end
