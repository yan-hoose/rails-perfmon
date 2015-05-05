require 'rails-perfmon/request_collector'

class RailsPerfmon::Railtie < Rails::Railtie

  config.after_initialize do
    if RailsPerfmon.configuration.service_url && RailsPerfmon.configuration.api_key
      RailsPerfmon::RequestCollector.new
    end
  end

end
