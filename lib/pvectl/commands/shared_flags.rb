# frozen_string_literal: true

module Pvectl
  module Commands
    # Shared flag definitions for command registration.
    #
    # Provides reusable flag groups that multiple commands share.
    # Called during command registration to DRY up flag definitions.
    #
    # @example Usage in a command's register method
    #   def self.register(cli)
    #     cli.command :start do |c|
    #       SharedFlags.lifecycle(c)
    #       c.action { |g, o, a| ... }
    #     end
    #   end
    #
    module SharedFlags
      # Defines the 8 flags shared by all lifecycle commands.
      #
      # @param command [GLI::Command] the command to add flags to
      # @return [void]
      def self.lifecycle(command)
        command.desc "Timeout in seconds for sync operations"
        command.flag [:timeout], type: Integer, arg_name: "SECONDS"

        command.desc "Force async mode (return task ID immediately)"
        command.switch [:async], negatable: false

        command.desc "Force sync mode (wait for completion)"
        command.switch [:wait], negatable: false

        command.desc "Select all VMs"
        command.switch [:all, :A], negatable: false

        command.desc "Filter by node name"
        command.flag [:node, :n], arg_name: "NODE"

        command.desc "Skip confirmation prompt"
        command.switch [:yes, :y], negatable: false

        command.desc "Stop on first error (default: continue and report all)"
        command.switch [:"fail-fast"], negatable: false

        command.desc "Filter VMs by selector (e.g., status=running,tags=prod)"
        command.flag [:l, :selector], arg_name: "SELECTOR", multiple: true
      end
    end
  end
end
