# frozen_string_literal: true

module Pvectl
  module Commands
    module Resize
      # Registers the `pvectl resize` command group with subcommands.
      #
      # Currently supports `resize disk`. Designed for extensibility
      # with future subcommands (memory, cpu).
      #
      # @example
      #   Commands::Resize::Command.register(cli)
      #
      class Command
        # Registers the resize command and subcommands with the CLI.
        #
        # @param cli [GLI::App] the CLI application object
        # @return [void]
        def self.register(cli)
          cli.desc "Resize a resource property"
          cli.command :resize do |c|
            register_disk_subcommand(c)
          end
        end

        # Registers the disk subcommand.
        #
        # @param parent [GLI::Command] parent resize command
        # @return [void]
        def self.register_disk_subcommand(parent)
          parent.desc "Resize a disk on a VM or container"
          parent.arg_name "RESOURCE_TYPE ID DISK SIZE"
          parent.command :disk do |disk_cmd|
            disk_cmd.desc "Skip confirmation prompt"
            disk_cmd.switch [:yes, :y], negatable: false

            disk_cmd.desc "Target node name"
            disk_cmd.flag [:node, :n], arg_name: "NODE"

            disk_cmd.action do |global_options, options, args|
              resource_type = args.shift

              exit_code = case resource_type
              when "vm"
                Resize::ResizeDiskVm.execute(args, options, global_options)
              when "container", "ct"
                Resize::ResizeDiskCt.execute(args, options, global_options)
              when nil
                $stderr.puts "Error: Resource type required (vm, container, ct)"
                ExitCodes::USAGE_ERROR
              else
                $stderr.puts "Error: Unknown resource type: #{resource_type}"
                $stderr.puts "Valid types: vm, container, ct"
                ExitCodes::USAGE_ERROR
              end

              exit exit_code if exit_code != 0
            end
          end
        end
        private_class_method :register_disk_subcommand
      end
    end
  end
end
