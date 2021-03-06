#! /usr/bin/env ruby
#
# check-gearman-workers
#
# DESCRIPTION:
#   #YELLOW
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: gearman-ruby
#   gem: sensu-plugin
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2016 Aaron Brady <aaron@iweb.co.uk>
#   Copyright S. Zachariah Sprackett <zac@sprackett.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'gearman/server'

#
# Check Gearman Workers
#
class CheckGearmanWorkers < Sensu::Plugin::Check::CLI
  option :host,
         short: '-H HOST',
         default: 'localhost'
  option :port,
         short: '-p PORT',
         default: '4730'
  option :queue,
         short: '-q QUEUE'
  option :crit_high,
         short: '-c CRIT_HIGH_THRESHOLD',
         proc: proc(&:to_i),
         default: false
  option :warn_high,
         short: '-w WARN_HIGH_THRESHOLD',
         proc: proc(&:to_i),
         default: false
  option :crit_low,
         short: '-C CRIT_LOW_THRESHOLD',
         proc: proc(&:to_i),
         default: 0
  option :warn_low,
         short: '-W WARN_LOW_THRESHOLD',
         proc: proc(&:to_i),
         default: 0

  def run
    begin
      gearman = Gearman::Server.new(
        "#{config[:host]}:#{config[:port]}"
      )
    rescue => e
      critical "Failed to connect: (#{e})"
    end

    stats = {}
    criticals = []
    warnings = []
    okays = []

    if config[:queue]
      stat = gearman.status[config[:queue]]
      if stat.nil?
        warning "Queue #{config[:queue]} not found"
      else
        stats = { config[:queue] => stat }
      end
    else
      stats = gearman.status
    end

    stats.each do |queue_name, single_stat|
      workers = single_stat[:workers].to_i
      if config[:crit_high] && workers > config[:crit_high]
        criticals << "#{queue_name}: High threshold is #{config[:crit_high]} workers (#{workers} active workers)"
      elsif config[:warn_high] && workers > config[:warn_high]
        warnings << "#{queue_name}: High threshold is #{config[:warn_high]} workers (#{workers} active workers)"
      elsif workers < config[:crit_low]
        criticals << "#{queue_name}: Low threshold is #{config[:crit_low]} workers (#{workers} active workers)"
      elsif workers < config[:warn_low]
        warnings << "#{queue_name}: Low threshold is #{config[:warn_low]} (#{workers} active workers)"
      else
        okays << "#{queue_name}: #{workers} workers found."
      end
    end

    unless criticals.empty?
      critical criticals.join(' ')
    end
    unless warnings.empty?
      warning warnings.join(' ')
    end
    ok okays.join(' ')
  end
end
