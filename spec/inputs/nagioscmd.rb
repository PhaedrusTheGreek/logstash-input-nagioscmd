# encoding: utf-8
require "logstash/devutils/rspec/spec_helper"
require "socket"
require "logstash/inputs/nagioscmd"

describe LogStash::Inputs::Nagioscmd do

  let(:settings) { {} }
  let(:queue) { Queue.new }
  let(:plugin) { LogStash::Inputs::Nagioscmd.new(settings) }
  let(:default_settings) { { "count" =>1, "interval" => 1 } }

  context "when registering and tearing down" do

    it "registers without raising exception" do
      expect { plugin.register }.to_not raise_error
      plugin.teardown
    end

    it "tears down without raising exception" do
      plugin.register
      expect { plugin.teardown }.to_not raise_error
    end

  end

  context "check command will pass OK" do

    let(:settings) { default_settings.merge({ "check_command" => "/usr/local/sbin/check_ping -H 127.0.0.1 -w 5,5% -c 100,90%" }) }

    before do
      plugin.register
    end

    after do
      plugin.teardown
    end

    it "knows when a check returns OK" do

      plugin.run(queue)
      expect(queue.pop['status']).to eq(0)

    end
  end

  # context "check command will fail with WARN" do
  #
  #   let(:settings) { default_settings.merge({ "check_command" => "/usr/local/sbin/check_ping -H 0.0.0.0 -w 5,5% -c 100,90%" }) }
  #
  #   before do
  #     plugin.register
  #   end
  #
  #   after do
  #     plugin.teardown
  #   end
  #
  #   it "knows when a check returned WARN" do
  #
  #     plugin.run(queue)
  #     #expect(queue.pop['num_param']).to eq(settings['parameters']['num_param'])
  #
  #   end
  # end


end