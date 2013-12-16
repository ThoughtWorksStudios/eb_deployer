module EbDeployer
  class VersionCleaner
    def initialize(app, number_to_keep)
      @app = app
      @number_to_keep = number_to_keep
    end

    def clean(version_prefix = "")
      if @number_to_keep > 0
        versions_to_remove = versions_to_clean(version_prefix)
        @app.remove(versions_to_remove, true)
      end
    end

    private
    def versions_to_clean(version_prefix = "")
      all_versions = @app.versions.select do |apv|
        apv[:version].start_with?(version_prefix)
      end

      all_versions.sort! { |x, y| y[:date_updated] <=> x[:date_updated] }
      versions_to_keep = all_versions.slice!(range_to_keep)
      all_versions.map { |apv| apv[:version] }
    end

    def range_to_keep
      (0..(@number_to_keep-1))
    end
  end
end
