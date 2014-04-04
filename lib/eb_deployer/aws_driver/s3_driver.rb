module EbDeployer
  module AWSDriver
    class S3Driver
      def create_bucket(bucket_name)
        buckets.create(bucket_name)
      end

      def bucket_exists?(bucket_name)
        buckets[bucket_name].exists?
      end

      def object_length(bucket_name, obj_name)
        obj(bucket_name, obj_name).content_length rescue nil
      end

      def upload_file(bucket_name, obj_name, file)
        o = obj(bucket_name, obj_name)
        File.open(file, 'rb') { |f| o.write(f) }
      end

      private
      def s3
        AWS::S3.new
      end

      def obj(bucket_name, obj_name)
        buckets[bucket_name].objects[obj_name]
      end

      def buckets
        s3.buckets
      end
    end
  end
end
