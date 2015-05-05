require 'net/http'
require 'uri'
require 'thread'
require 'rails-perfmon/logger'

class RailsPerfmon::RequestCollector
  attr_reader :logger

  def initialize
    @request_data = []
    @sending_data = false
    @last_sent_at = Time.now
    @lock = Mutex.new
    @logger = RailsPerfmon::Logger.new

    ActiveSupport::Notifications.subscribe('process_action.action_controller') do |name, start, finish, id, payload|
      add_request(payload, start, finish)
    end
  end

  private

  def add_request(payload, start, finish)
    @lock.synchronize do
      @request_data << payload.except(:params, :path).merge(total_runtime: (finish - start) * 1000, time: start) unless payload.has_key?(:exception)
    end
    check_if_data_should_be_sent
  end

  def check_if_data_should_be_sent
    @lock.synchronize do
      if @last_sent_at < 5.minutes.ago && !@sending_data
        @sending_data = true
        send_data(@request_data)
      elsif @sending_data
        logger.log(:debug, 'Already sending data, waiting for current push to finish')
      end
    end
  end

  def send_data(request_data)
    thread = Thread.new(request_data) do |req_data|
      logger.log(:debug, "Sending #{req_data.length.to_s} requests")

      send_request_and_handle_response(req_data)
    end
    at_exit { thread.join }
  end

  def send_request_and_handle_response(req_data)
    uri, request = build_uri_and_request(req_data)
    begin
      response =
        Net::HTTP.start(
          uri.hostname,
          uri.port,
          open_timeout: 10,
          use_ssl: uri.scheme == 'https',
          verify_mode: RailsPerfmon.configuration.ssl_verify_mode) { |http| http.request(request) }

      case response
      when Net::HTTPOK
        logger.log(:debug, 'Data accepted')
        slice_request_data(req_data.length)
      when Net::HTTPUnauthorized
        logger.log(:error, 'Invalid API key')
        slice_request_data(req_data.length)
      when Net::HTTPBadRequest
        logger.log(:error, 'Bad request')
        slice_request_data(req_data.length)
      else
        logger.log(:error, "Unhandled response code: #{response.code.to_s}")
      end
    rescue Exception => e
      logger.log(:error, "Connection error: #{e.inspect}")
    ensure
      @lock.synchronize do
        @last_sent_at = Time.now
        @sending_data = false
      end
    end
  end

  def slice_request_data(length)
    @lock.synchronize { @request_data.slice!(0, length) }
  end

  def build_uri_and_request(request_data)
    uri = URI.parse(RailsPerfmon.configuration.service_url)
    req = Net::HTTP::Post.new(uri)
    req.set_form_data('api_key' => RailsPerfmon.configuration.api_key, 'requests' => request_data.to_json)
    [uri, req]
  end

end
