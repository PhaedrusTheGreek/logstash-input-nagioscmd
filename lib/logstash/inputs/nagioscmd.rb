# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "concurrent/atomics"
require "socket" # for Socket.gethostname
require "pp"

#https://nagios-plugins.org/doc/guidelines.html#AEN200

# Read events from standard input.
#
# By default, each event is assumed to be one line. If you
# want to join lines, you'll want to use the multiline filter.
class String
  def rchomp(sep = $/)
    self.start_with?(sep) ? self[sep.size..-1] : self
  end
end

class LogStash::Inputs::Nagioscmd < LogStash::Inputs::Base
  config_name "nagioscmd"

  default :codec, "plain"

  milestone 1

  # The nagios command to run
  config :check_command, :validate => :string

  # Set how frequently the check should b performed
  #
  # The default, `60`, means send a message every 60 seconds.
  config :interval, :validate => :number, :default => 60

  # This is typically used only for testing purposes.
  config :count, :validate => :number, :default => -1

  # Define the target field for placing the performance data. If this setting is
  # omitted, the JSON data will be stored at the root (top level) of the event.
  config :target, :validate => :string

  class SequenceComplete < StandardError
  end

  def initialize(*args)
    super(*args)
    @stop_requested = Concurrent::AtomicBoolean.new(false)
    @parser = NagiosCommandParser.new
  end


  def register
    @host = Socket.gethostname
    fix_streaming_codecs
  end

  def run(queue)

      sequence = 0;

      Stud.interval(@interval) do

        begin

          sequence += 1

          event = @parser.check(@check_command)
          decorate(event)
          queue << event

          if sequence == @count || stop?
            raise SequenceComplete, "Max Sequence"
          end

        rescue SequenceComplete, LogStash::ShutdownSignal => e
          @logger.info(e.to_s)
          break

        rescue => e
          puts e.to_s #why isn't the logger outputting in my rspec?
          @logger.error(e.to_s)
          if (@count == 1) # test mode
            raise e
          end

        end # handling

      end # loop

  end

  def stop
    Stud.stop!(@thread) || @stop_requested
  end

  def teardown
    @stop_requested.make_true
    @logger.debug("nagios input shutting down.")
    $stdin.close rescue nil
    finished
  end

   # PING OK - Packet loss = 0%, RTA = 0.07 ms|rta=0.069000ms;5.000000;100.000000;0.000000 pl=0%;5;90;0

  class NagiosCommandParser

    def initialize()

    end

    def check(command)

      t1 = Time.now.to_f
      status = `#{command}`
      delta = Time.now.to_f - t1

      event = LogStash::Event.new(
          "status" => $?,
          "check_ms" => delta,
          "host" => @hosts
      )

      parts = status.split('|');
      cmd_message = parts[0];
      cmd_perf = parts[1];

      # if @target.nil?
      #   event.to_hash.merge! perf
      # else
      #   event[@target] = parsed
      # end

      event["message"] = cmd_message;

      unless cmd_perf.nil?
        event["perf"] = {}
        cmd_perf.split(" ").each { |metric|

          metric_parts = metric.split('=');

          metric_key = metric_parts[0];
          metric_key = metric_key.rchomp("'").chomp("'")

          metric_value = metric_parts[1];

          value_parts = metric_value.split(';');

          value_metric = value_parts[0];
          value_warn = value_parts[1];
          value_crit = value_parts[2];
          value_max = value_parts[3];

          (value_metric_numeric, value_metric_unit) = value_metric.scan(/[\d\.]+|[A-Za-z%]*/)

          event["perf"][metric_key] = {};
          event["perf"][metric_key]["metric"] = value_metric_numeric.to_f;
          event["perf"][metric_key]["warn"] = value_warn.to_f;
          event["perf"][metric_key]["crit"] = value_crit.to_f;
          event["perf"][metric_key]["max"] = value_max.to_f;
          event["perf"][metric_key]["uom"] = value_metric_unit;

        }
      end

      pp(event["perf"])
      event

    end


  end




end
