module EbDeployer
  class Configuration
    include Utils
    def self.config_option(name, default=nil)
      self.instance_eval do
        define_method(name) do
          @attrs[name] || default
        end
      end
    end

    attr_reader :application, :environment
    config_option :version_label
    config_option :version_prefix
    config_option :keep_latest
    config_option :option_settings, []
    config_option :inactive_settings, []
    config_option :region
    config_option :tier, 'WebServer'
    config_option :resources
    config_option :package_bucket
    config_option :package
    config_option :phoenix_mode, false
    config_option :strategy, 'blue-green'
    config_option :smoke_test
    config_option :solution_stack_name, '64bit Amazon Linux 2014.02 v1.0.1 running Tomcat 7 Java 7'

    def initialize(application, environment, attrs={})
      @application = application
      @environment = environment
      @attrs = attrs
    end

    def merge(attrs)
      return self unless attrs
      attrs = symbolize_keys(attrs)

      old_option_settings = self.option_settings
      new_option_settings = attrs[:option_settings] || []
      new_attrs = @attrs.
        merge(attrs).
        merge(:option_settings => old_option_settings + new_option_settings)

      self.class.new(@application, @environment, new_attrs)
    end

  end
end
