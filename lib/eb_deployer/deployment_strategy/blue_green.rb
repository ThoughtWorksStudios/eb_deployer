module EbDeployer
  module DeploymentStrategy
    class BlueGreen
      def initialize(component)
        @component = component
      end

      def test_compatibility(env_create_options)
        @create_opts = env_create_options
        tier = env_create_options[:tier]

        if tier && tier.downcase == 'worker'
          raise "Blue green deployment is not supported for Worker tier"
        end
      end

      def deploy(version_label, env_settings, inactive_settings=[])

        if !ebenvs.any?(&method(:active_ebenv?))
          ebenv('a', @component.cname_prefix).
            deploy(version_label, env_settings)
          return
        end

        active_ebenv = ebenvs.detect(&method(:active_ebenv?))
        inactive_ebenv = ebenvs.reject(&method(:active_ebenv?)).first

        inactive_ebenv.deploy(version_label, env_settings)
        active_ebenv.swap_cname_with(inactive_ebenv)

        blue_green_terminate_inactive       = @create_opts[:blue_green_terminate_inactive]
        blue_green_terminate_inactive_wait  = @create_opts[:blue_green_terminate_inactive_wait]
        blue_green_terminate_inactive_sleep = @create_opts[:blue_green_terminate_inactive_sleep]

        if blue_green_terminate_inactive
          active_ebenv.log("Waiting #{blue_green_terminate_inactive_wait}s before terminating environment...")
      
          sleep 120

          active_ebenv.log("terminating inactive (black) environment")
          active_ebenv.terminate
        end

        unless inactive_settings.empty? || blue_green_terminate_inactive
          active_ebenv.log("applying inactive settings...")
          active_ebenv.apply_settings(inactive_settings)
        end
      end

      private
      def active_ebenv?(ebenv)
        ebenv.cname_prefix == @component.cname_prefix
      end

      def ebenvs
        [ebenv('a'), ebenv('b')]
      end

      def ebenv(suffix, cname_prefix=nil)
        @component.new_eb_env(suffix, cname_prefix || inactive_cname_prefix)
      end

      def inactive_cname_prefix
        "#{@component.cname_prefix}-inactive"
      end
    end
  end
end
