$:.unshift(File.expand_path("../../lib", __FILE__))

require 'tempfile'
require 'eb_deployer'
require 'aws_driver_stubs'
require 'test/unit'

def silence_warnings(&block)
  old_verbose, $VERBOSE = $VERBOSE, nil
  yield
ensure
  $VERBOSE = old_verbose
end

silence_warnings { EbDeployer::Utils::BACKOFF_INITIAL_SLEEP = 0 }
silence_warnings { EbDeployer::EventPoller::POLL_INTERVAL = 0 }

class ErrorRaisingWrapper < SimpleDelegator
  def initialize(stub)
    @errors = {}
    super(stub)
  end

  def set_error(method, error)
    set_error_generator(method) do
      error
    end
  end

  def set_error_generator(method, &error_gen)
    define_delegate_method(method)
    @errors[method] = Proc.new(&error_gen)
  end

  private
  def define_delegate_method(method)
    method = method.to_s
    original_method_name = "__#{method}_without_error"
    raise "method #{method} not defined" unless self.respond_to?(method)
    return if self.respond_to?(original_method_name)

    self.instance_eval <<-CODE
      def #{original_method_name}(*args, &block)
        self.__get_obj__.send(:#{method}, *args, &block)
      end

      def #{method}(*args, &block)
        if error_gen = @errors[:#{method}]
          error = error_gen.call
          raise error if error
        end
        super
      end
    CODE
  end
end

class Test::Unit::TestCase
  def sample_file(file_name, content='s' * 100)
    path = File.join('/tmp', file_name)
    File.open(path, 'w') { |f| f << content }
    path
  end

  def t(env, app_name)
    EbDeployer::EbEnvironment.unique_ebenv_name(env, app_name)
  end
end
