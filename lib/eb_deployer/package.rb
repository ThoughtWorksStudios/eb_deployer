module EbDeployer
  class Package
    def initialize(file, version_label, bucket_name, s3_driver)
      @file, @version_label, @bucket_name = file, version_label, bucket_name
      @s3 = s3_driver
    end

    def upload
      ensure_bucket(@bucket_name)
      upload_if_not_exists(@file, @bucket_name)
    end

    def source_bundle
      { :s3_bucket => @bucket_name, :s3_key => s3_path }
    end

    private

    def s3_path
      @_s3_path ||= @version_label or Digest::MD5.file(@file).hexdigest + "-" + File.basename(@file)
    end

    def ensure_bucket(bucket_name)
      @s3.create_bucket(@bucket_name) unless @s3.bucket_exists?(@bucket_name)
    end

    def upload_if_not_exists(file, bucket_name)
      unless @s3.object_exists?(bucket_name, s3_path)
        log("start uploading to s3 bucket #{@bucket_name}...")
        @s3.upload_file(@bucket_name, s3_path, file)
        log("uploading finished")
      end
    end

    def log(message)
      puts "[#{Time.now.utc}][package:#{File.basename(@file)}] #{message}"
    end
  end
end
