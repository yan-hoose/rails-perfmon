require 'rails-perfmon/version'
require 'rails-perfmon/request_collector'
require 'rails-perfmon/railtie'

module RailsPerfmon
  class << self
    attr_writer :configuration
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  class Configuration
    attr_accessor :service_url, :api_key, :ssl_verify_mode, :params_inclusion_threshold

    def initialize
      @service_url = nil
      @api_key = nil
      @params_inclusion_threshold = nil
      @ssl_verify_mode = OpenSSL::SSL::VERIFY_PEER
    end
  end

end
