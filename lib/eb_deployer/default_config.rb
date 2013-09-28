module EbDeployer
  class DefaultConfig
    attr_reader :app_name

    def initialize(app_name)
      @app_name = app_name.gsub('_', '-')
    end

    def write_to(path)
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') { |f| f << ERB.new(File.read(config_template)).result(binding) }
    end

    private

    def config_template
      File.expand_path("../default_config.yml", __FILE__)
    end
  end
end
