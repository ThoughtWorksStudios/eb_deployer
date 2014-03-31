module EbDeployer
  class Environment
    attr_writer :resource_stacks, :settings, :creation_opts, :components, :component_under_deploy
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
      components_to_deploy.each do |component|
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
    def components_to_deploy
      if @component_under_deploy
        component = component_named(@component_under_deploy)
        raise "'#{@component_under_deploy}' is not in the configuration. Available components are #{@components.map(&:name) }" unless component
        [component]
      else
        @components
      end
    end

    def component_named(name)
      @components.detect { |c| c.name == name }
    end

    def symbolize_keys(hash)
      hash.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
    end

    def resource_stack_name
      "#{app_name}-#{@name}"
    end
  end
end
