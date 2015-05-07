require 'spec_helper'
require 'timecop'
require 'rails'
require 'rails-perfmon'
require 'rails-perfmon/logger'
require 'rails-perfmon/request_collector'

class TestCollector < RailsPerfmon::RequestCollector
  attr_accessor :request_data, :sending_data, :last_sent_at, :lock, :logger
end

RSpec.describe RailsPerfmon::RequestCollector do
  let(:collector) { TestCollector.new }

  describe '#initialize' do
    it 'initializes necessary instance variables' do
      expect(collector.request_data).to eq([])
      expect(collector.sending_data).to eq(false)
      expect(collector.last_sent_at.class).to be(Time)
      expect(collector.lock.class).to be(Mutex)
      expect(collector.logger.class).to be(RailsPerfmon::Logger)
    end

    it 'subscribes to process_action.action_controller notifications' do
      expect(ActiveSupport::Notifications).to receive(:subscribe).with('process_action.action_controller').once.and_yield('Name', Time.now, Time.now, '123', {})
      RailsPerfmon::RequestCollector.new
    end
  end

  describe '#add_request' do
    it 'adds the payload to @request_data inside a lock' do
      expect(collector.lock).to receive(:synchronize).twice.and_yield.and_call_original

      collector.send(:add_request, {}, Time.now, Time.now)

      expect(collector.request_data.length).to eq(1)
    end

    it 'does not add when the payload contains an exception' do
      collector.send(:add_request, {exception: 'ERROR!'}, Time.now, Time.now)

      expect(collector.request_data.length).to eq(0)
    end

    it 'excludes :params and :path from the payload' do
      collector.send(:add_request, {params: '123', path: '/path'}, Time.now, Time.now)

      data = collector.request_data.first
      expect(data.has_key?(:params)).to eq(false)
      expect(data.has_key?(:path)).to eq(false)
    end

    it 'adds :total_runtime and :time to the payload' do
      collector.send(:add_request, {}, Time.mktime(2015, 4, 29, 12, 0, 0), Time.mktime(2015, 4, 29, 12, 0, 2))

      data = collector.request_data.first
      expect(data.has_key?(:total_runtime)).to eq(true)
      expect(data.has_key?(:time)).to eq(true)
      expect(data[:total_runtime]).to eq(2000)
      expect(data[:time]).to eq(Time.mktime(2015, 4, 29, 12, 0, 0))
    end

    it 'checks if data should be sent' do
      expect(collector).to receive(:check_if_data_should_be_sent).once

      collector.send(:add_request, {}, Time.now, Time.now)
    end
  end

  describe '#check_if_data_should_be_sent' do
    it 'does not send data when last sending was less than 5 minutes ago' do
      expect(collector).to_not receive(:send_data)
      collector.last_sent_at = Time.now - 4.minutes

      collector.send(:check_if_data_should_be_sent)
    end

    it 'does not send data when currently in the process of sending, logs a debug message instead' do
      expect(collector).to_not receive(:send_data)
      expect(collector.logger).to receive(:log).with(:debug, 'Already sending data, waiting for current push to finish').once
      collector.sending_data = true

      collector.send(:check_if_data_should_be_sent)
    end

    it 'sends data when last sending was more then 5 minutes ago and sending is currently not in the process' do
      expect(collector).to receive(:send_data).once
      collector.last_sent_at = Time.now - 5.minutes
      collector.sending_data = false

      collector.send(:check_if_data_should_be_sent)
      expect(collector.sending_data).to be(true)
    end

    it 'uses the lock' do
      expect(collector.lock).to receive(:synchronize).once.and_yield

      collector.send(:check_if_data_should_be_sent)
    end
  end

  describe '#build_uri_and_request' do
    before(:each) do
      RailsPerfmon.configure do |config|
        config.service_url = 'https://test.example.com:8080'
        config.api_key = '12345'
      end
    end
    let(:data) { [{controller: 'PostsController'}, {controller: 'CommentsController'}] }

    it 'parses the uri and sets request form data' do
      uri, request = collector.send(:build_uri_and_request, data)

      expect(uri).to be_a(URI)
      expect(request).to be_a(Net::HTTP::Post)

      expect(CGI.unescape(request.body)).to eq('api_key=12345&requests=[{"controller":"PostsController"},{"controller":"CommentsController"}]')
    end

    it 'combines config.service_url and /requests for a final request uri' do
      uri, request = collector.send(:build_uri_and_request, data)

      expect(uri.path).to eq('/requests')
      expect(request.uri.to_s).to eq('https://test.example.com:8080/requests')
    end
  end

  describe '#slice_request_data' do
    it 'removes sent request data from the @request_data array' do
      collector.request_data = [1, 2, 3, 4, 5]

      collector.send(:slice_request_data, 5)

      expect(collector.request_data).to eq([])
    end

    it 'removes sent request data from the beginning of the @request_data array' do
      collector.request_data = [1, 2, 3, 4, 5]

      collector.send(:slice_request_data, 3)

      expect(collector.request_data).to eq([4, 5])
    end

    it 'uses the lock while slicing' do
      expect(collector.lock).to receive(:synchronize).once

      collector.send(:slice_request_data, 3)
    end
  end

  describe '#send_request_and_handle_response' do
    before(:each) do
      RailsPerfmon.configure do |config|
        config.service_url = 'https://test.example.com:8080'
        config.api_key = '12345'
        config.ssl_verify_mode = OpenSSL::SSL::VERIFY_PEER
      end

      Timecop.freeze(Time.now)
    end

    after(:each) do
      expect(collector.last_sent_at).to eq(Time.now)
      expect(collector.sending_data).to be(false)

      Timecop.return
    end

    let(:data) { [1, 2, 3, 4, 5] }

    it 'sends a post request' do
      expect(Net::HTTP).to receive(:start).
        with('test.example.com', 8080, {open_timeout: 10, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_PEER}).
        once.and_return(Net::HTTPOK.new('1.1', 200, 'OK'))
      expect(collector.logger).to receive(:log).with(:debug, 'Data accepted').once

      collector.send(:send_request_and_handle_response, data)
    end

    it 'sets use_ssl param correctly' do
      RailsPerfmon.configuration.service_url = 'http://test.example.com:8080'

      expect(Net::HTTP).to receive(:start).
        with('test.example.com', 8080, {open_timeout: 10, use_ssl: false, verify_mode: OpenSSL::SSL::VERIFY_PEER}).
        once.and_return(Net::HTTPOK.new('1.1', 200, 'OK'))
      expect(collector.logger).to receive(:log).with(:debug, 'Data accepted').once

      collector.send(:send_request_and_handle_response, data)
    end

    it 'sets verify_mode param' do
      RailsPerfmon.configuration.ssl_verify_mode = OpenSSL::SSL::VERIFY_NONE

      expect(Net::HTTP).to receive(:start).
        with('test.example.com', 8080, {open_timeout: 10, use_ssl: true, verify_mode: OpenSSL::SSL::VERIFY_NONE}).
        once.and_return(Net::HTTPOK.new('1.1', 200, 'OK'))
      expect(collector.logger).to receive(:log).with(:debug, 'Data accepted').once

      collector.send(:send_request_and_handle_response, data)
    end

    it 'slices request data on a successful request' do
      allow(Net::HTTP).to receive(:start).and_return(Net::HTTPOK.new('1.1', 200, 'OK'))
      expect(collector.logger).to receive(:log).with(:debug, 'Data accepted').once
      expect(collector).to receive(:slice_request_data).with(5)

      collector.send(:send_request_and_handle_response, data)
    end

    it 'slices request data when the api key is invalid' do
      allow(Net::HTTP).to receive(:start).and_return(Net::HTTPUnauthorized.new('1.1', 401, 'Unauhtorized'))
      expect(collector.logger).to receive(:log).with(:error, 'Invalid API key').once
      expect(collector).to receive(:slice_request_data).with(5)

      collector.send(:send_request_and_handle_response, data)
    end

    it 'slices request data when request data was bad' do
      allow(Net::HTTP).to receive(:start).and_return(Net::HTTPBadRequest.new('1.1', 400, 'Bad request'))
      expect(collector.logger).to receive(:log).with(:error, 'Bad request').once
      expect(collector).to receive(:slice_request_data).with(5)

      collector.send(:send_request_and_handle_response, data)
    end

    it 'keeps unsent request data and logs an error when the response code was unknown' do
      allow(Net::HTTP).to receive(:start).and_return(Net::HTTPInternalServerError.new('1.1', 500, 'Internal Server Error'))
      expect(collector.logger).to receive(:log).with(:error, 'Unhandled response code: 500').once
      expect(collector).to_not receive(:slice_request_data)

      collector.send(:send_request_and_handle_response, data)
    end

    it 'rescues from an exception and keeps the unsent request data' do
      allow(Net::HTTP).to receive(:start).and_raise(SocketError.new('Can not connect!??!'))
      expect(collector.logger).to receive(:log).with(:error, 'Connection error: #<SocketError: Can not connect!??!>').once
      expect(collector).to_not receive(:slice_request_data)

      collector.send(:send_request_and_handle_response, data)
    end
  end

  describe '#send_data' do
    it 'creates a new thread and calls at_exit' do
      expect(Thread).to receive(:new).with([1, 2, 3]).once
      expect_any_instance_of(Kernel).to receive(:at_exit).once

      collector.send(:send_data, [1, 2, 3])
    end
  end

end