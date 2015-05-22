module EbDeployer
  module AWSDriver
    class S3Driver
      def create_bucket(bucket_name)
        s3.create_bucket(:bucket => bucket_name)
      end

      def bucket_exists?(bucket_name)
        s3.bucket(bucket_name).exists?
      end

      def object_length(bucket_name, obj_name)
        obj(bucket_name, obj_name).content_length rescue nil
      end

      def upload_file(bucket_name, obj_name, file)
        o = obj(bucket_name, obj_name)
        o.upload_file(file)
      end

      private
      def s3
        Aws::S3::Resource.new(client: Aws::S3::Client.new)
      end

      def obj(bucket_name, obj_name)
        s3.bucket(bucket_name).object(obj_name)
      end

      def buckets
        s3.buckets
      end
    end
  end
end
