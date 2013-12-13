module EbDeployer
  class VersionCleaner
    def initialize(app, number_to_keep)
      @app = app
      @number_to_keep = number_to_keep
    end

    def clean(version_prefix = "")
      if @number_to_keep > 0
        versions_to_remove = @app.versions.select do |apv|
          apv[:version].start_with?(version_prefix)
        end

        versions_to_remove.sort! { |x, y| y[:date_updated] <=> x[:date_updated] }
        versions_to_keep = versions_to_remove.slice!(0..(@number_to_keep-1))
        version_labels = versions_to_remove.map { |apv| apv[:version] }
        @app.remove(version_labels, true)
      end
    end
  end
end
