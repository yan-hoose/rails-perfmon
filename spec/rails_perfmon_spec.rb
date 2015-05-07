require 'spec_helper'
require 'rails'
require 'rails-perfmon'

RSpec.describe RailsPerfmon do

  describe 'configuration' do
    context 'default config' do
      before(:each) do
        RailsPerfmon.configuration = RailsPerfmon::Configuration.new
      end

      it 'has service_url as nil' do
        expect(RailsPerfmon.configuration.service_url).to be_nil
      end

      it 'has api_key as nil' do
        expect(RailsPerfmon.configuration.api_key).to be_nil
      end

      it 'has ssl_verify_mode as OpenSSL::SSL::VERIFY_PEER' do
        expect(RailsPerfmon.configuration.ssl_verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
      end
    end

    context 'setting config' do
      before(:each) do
        RailsPerfmon.configure do |config|
          config.service_url = 'https://test.example.com:8080'
          config.api_key = '12345'
          config.ssl_verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
      end

      it 'has service_url attribute set' do
        expect(RailsPerfmon.configuration.service_url).to eq('https://test.example.com:8080')
      end

      it 'has api_key attribute set' do
        expect(RailsPerfmon.configuration.api_key).to eq('12345')
      end

      it 'has ssl_verify_mode attribute set' do
        expect(RailsPerfmon.configuration.ssl_verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
      end
    end
  end

end