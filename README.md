# rails-perfmon

This gem collects performance data from your Rails app. It does this by collecting the data and then sending it to the [monitoring app](https://github.com/yan-hoose/rails-perfmon-app) which shows the data in a human readable form. This gem and the app work in conjunction. First, set up the app and then install this gem to your apps that you want to monitor.

## Requirements

This gem works with Rails 4.x.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rails-perfmon', git: 'https://github.com/yan-hoose/rails-perfmon.git'
```

And then execute:

    $ bundle

Then create a new initializer:

```ruby
# config/initializers/perfmon.rb

RailsPerfmon.configure do |config|
  config.service_url = 'https://the.host.where.you.set.up.your.monitoring.app'
  config.api_key = 'secret123'
end if Rails.env.production?
```
You get the API key from the "Website settings" menu in your monitoring app.

If the monitoring app is running on HTTPS and with a self-signed cert, add this to the config:
```ruby
config.ssl_verify_mode = OpenSSL::SSL::VERIFY_NONE
```
And that is it. After you deploy the changes, the performance data of your app should start appearing in the monitoring app. The data is sent after every 5 minutes, so it'll take at least 5 minutes for the data to start appearing.

## Contributing

1. Fork it ( https://github.com/yan-hoose/rails-perfmon/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
