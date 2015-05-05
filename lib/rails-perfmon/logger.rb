class RailsPerfmon::Logger

  def initialize
    @logger = Rails.logger
  end

  def log(level, msg)
    @logger.tagged('RAILS-PERFMON') { @logger.send(level, msg) }
  end

end