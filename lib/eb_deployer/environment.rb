module EbDeployer
  class Environment
    include Utils
    attr_accessor :creation_opts, :strategy_name

    attr_writer :resource_stacks, :settings, :inactive_settings, :components, :component_under_deploy

    attr_reader :name

    def initialize(app, name, eb_driver, &block)
      @app = app
      @name = name
      @eb_driver = eb_driver
      @creation_opts = {}
      @settings = []
      @inactive_settings = []
      @strategy_name = :blue_green
      yield(self) if block_given?
      unless @components
        @components = [DefaultComponent.new(self, @creation_opts, @strategy_name, @eb_driver)]
      end
    end

    def app_name
      @app.name
    end

    def deploy(version_label)
      resource_settings = @resource_stacks.provision(resource_stack_name)
      components_to_deploy.each do |component|
        component.deploy(version_label, @settings + resource_settings, @inactive_settings)
      end
    end

    def components=(components_attrs)
      return unless components_attrs
      @components = components_attrs.map do |attrs|
        attrs = symbolize_keys(attrs)
        Component.new(attrs.delete(:name), self, attrs, @eb_driver)
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

    def resource_stack_name
      "#{app_name}-#{@name}"
    end
  end
end
