require 'securerandom'
require 'digest'

module EbDeployer
  class ConfigLoader
    include Utils

    class EvalBinding
      def initialize(package_digest)
        @package_digest = package_digest
      end

      def random_hash
        SecureRandom.hex[0..9]
      end

      def package_digest
        @package_digest
      end
    end

    def load(options)
      options = options.dup
      package_digest = package_digest(options[:package])
      config_file = options.delete(:config_file)
      config_settings = load_config_settings(config_file, package_digest)

      app_name = config_settings[:application]

      common_settings = symbolize_keys(config_settings[:common])
      common_settings[:version_label] ||= package_digest

      envs = config_settings[:environments]
      env = options[:environment]
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

    def load_config_settings(config_file, package_digest)
      yaml = ERB.new(File.read(config_file)).result(eval_binding(package_digest))
      symbolize_keys(YAML.load(yaml))
    end

    def eval_binding(package_digest)
      EvalBinding.new(package_digest).instance_eval { binding }
    end

    def package_digest(package)
      return nil unless package
      return package unless File.exists?(package)
      Digest::MD5.file(package).hexdigest
    end
  end
end
