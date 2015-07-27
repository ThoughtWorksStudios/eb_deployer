require 'securerandom'
require 'digest'
require 'yaml'

module EbDeployer
  class ConfigLoader
    include Utils

    class EvalBinding
      attr_reader :environment, :package_digest
      def initialize(package_digest, env)
        @package_digest = package_digest
        @environment = env
      end

      def random_hash
        SecureRandom.hex[0..9]
      end
    end

    def load(options)
      options = options.dup
      package_digest = package_digest(options[:package])
      config_file = options.delete(:config_file)

      env = options[:environment]
      config_settings = load_config_settings(config_file, package_digest, env)

      app_name = config_settings[:application]

      common_settings = symbolize_keys(config_settings[:common])
      common_settings[:version_label] ||= package_digest

      envs = config_settings[:environments]
      raise "Environment #{env} is not defined in #{config_file}" unless envs.has_key?(env)
      env_settings = symbolize_keys(envs[env] || {})
      env_option_settings = env_settings.delete(:option_settings) || []

      ret = options.merge(common_settings).merge(env_settings)
      ret[:application] = app_name
      ret[:option_settings] ||= []
      ret[:option_settings] += env_option_settings
      ret
    end

    private

    def load_config_settings(config_file, package_digest, env)
      yaml = ERB.new(File.read(config_file)).
             result(eval_binding(package_digest, env))
      symbolize_keys(YAML.load(yaml))
    end

    def eval_binding(package_digest, env)
      EvalBinding.new(package_digest, env).instance_eval { binding }
    end

    def package_digest(package)
      return nil unless package
      return package unless File.exists?(package)
      Digest::MD5.file(package).hexdigest
    end
  end
end
