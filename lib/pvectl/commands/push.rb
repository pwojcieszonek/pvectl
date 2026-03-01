# frozen_string_literal: true

require "fileutils"

module Pvectl
  module Commands
    # Push command -- applies YAML manifests to the Proxmox cluster.
    # Creates resources that don't exist, updates those that do.
    #
    # @example Register with CLI
    #   Push.register(cli)
    class Push
      RESOURCE_TYPES = {
        "vm" => :vm,
        "vms" => :vm,
        "container" => :container,
        "containers" => :container,
        "ct" => :container
      }.freeze

      # Registers the push command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Push YAML manifest to cluster (create or update)"
        cli.long_desc <<~HELP
          DESCRIPTION
            Applies resource configuration from YAML manifest files to the
            Proxmox cluster. Creates resources that don't exist, updates those
            that do. Shows a diff and asks for confirmation before applying.

          EXAMPLES
            $ pvectl push vm vm-100.yaml
            $ pvectl push vm ./manifests/
            $ pvectl push ./manifests/
            $ pvectl push vm vm-100.yaml --dry-run
            $ pvectl push vm vm-100.yaml --yes

          NOTES
            Without resource type, reads kind from each file.
            With --yes, skips confirmation (useful for CI/CD).
            With --dry-run, shows diff without applying changes.

          SEE ALSO
            pull, edit, create, delete
        HELP

        cli.command :push do |c|
          c.switch [:y, :yes], desc: "Auto-confirm without prompting", negatable: false
          c.switch [:"dry-run"], desc: "Show diff without applying", negatable: false
          c.flag [:node], desc: "Override node from metadata (for create)"

          c.action do |global_options, options, args|
            Push.new(args, options, global_options).execute
          end
        end
      end

      # @param args [Array<String>] command arguments
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(args, options, global_options)
        @args = args
        @options = options
        @global_options = global_options
      end

      # Executes the push command.
      #
      # @return [Integer] exit code
      def execute
        args = @args.dup
        filter_type = parse_resource_type(args)
        file_paths = args

        return usage_error("File or directory path is required") if file_paths.empty?

        yaml_contents = collect_yaml_contents(file_paths)
        return usage_error("No YAML files found") if yaml_contents.empty?

        load_config
        connection = Pvectl::Connection.new(@config)
        service = build_service(connection)

        result = service.prepare_batch(yaml_contents, filter_type: filter_type)

        # Report errors and skipped
        result[:errors].each { |e| $stderr.puts "Error: #{e}" }
        result[:skipped].each { |s| $stderr.puts "Info: #{s}" }

        if result[:plans].empty?
          if result[:errors].empty?
            $stdout.puts "No changes to apply."
          end
          return result[:errors].empty? ? ExitCodes::SUCCESS : ExitCodes::GENERAL_ERROR
        end

        # Display plans
        display_plans(result[:plans])

        if @options[:"dry-run"]
          $stdout.puts "\n(dry-run mode -- no changes applied)"
          return ExitCodes::SUCCESS
        end

        # Confirm unless --yes
        unless @options[:yes]
          $stdout.print "\nApply #{result[:plans].length} change(s)? [y/N] "
          answer = $stdin.gets&.strip&.downcase
          unless answer == "y" || answer == "yes"
            $stdout.puts "Cancelled."
            return ExitCodes::SUCCESS
          end
        end

        # Apply
        apply_result = service.apply(result[:plans])

        apply_result[:results].each do |r|
          if r[:success]
            $stdout.puts "#{r[:action].capitalize}d #{type_label_for(r)} #{r[:vmid]} successfully."
          else
            $stderr.puts "Error: Failed to #{r[:action]} #{r[:vmid]}: #{r[:error]}"
          end
        end

        apply_result[:errors].empty? ? ExitCodes::SUCCESS : ExitCodes::GENERAL_ERROR
      rescue Pvectl::Config::ConfigNotFoundError,
             Pvectl::Config::InvalidConfigError,
             Pvectl::Config::ContextNotFoundError,
             Pvectl::Config::ClusterNotFoundError,
             Pvectl::Config::UserNotFoundError
        raise
      rescue StandardError => e
        $stderr.puts "Error: #{e.message}"
        ExitCodes::GENERAL_ERROR
      end

      private

      # Parses and removes the optional resource type from the argument list.
      #
      # @param args [Array<String>] argument list (modified in place)
      # @return [Symbol, nil] :vm or :container, or nil if first arg is not a type
      def parse_resource_type(args)
        return nil if args.empty?

        first = args.first.downcase
        if RESOURCE_TYPES.key?(first)
          args.shift
          RESOURCE_TYPES[first]
        end
      end

      # Collects YAML file contents from given paths (files or directories).
      #
      # @param paths [Array<String>] file or directory paths
      # @return [Array<Hash>] array of { filename: String, content: String }
      def collect_yaml_contents(paths)
        contents = []
        paths.each do |path|
          if File.directory?(path)
            Dir.glob(File.join(path, "*.{yaml,yml}")).sort.each do |file|
              contents << { filename: File.basename(file), content: File.read(file) }
            end
          elsif File.file?(path)
            contents << { filename: File.basename(path), content: File.read(path) }
          else
            $stderr.puts "Error: File not found: #{path}"
          end
        end
        contents
      end

      # Displays push plans with diffs to stdout.
      #
      # @param plans [Array<Hash>] prepared push plans
      # @return [void]
      def display_plans(plans)
        plans.each do |plan|
          label = plan[:type] == :container ? "Container" : "VM"
          if plan[:action] == :update
            $stdout.puts "\n#{label} #{plan[:vmid]} (#{plan[:node]}) -- UPDATE:"
            $stdout.puts ConfigSerializer.format_diff(plan[:diff])
          elsif plan[:action] == :create
            $stdout.puts "\n#{label} #{plan[:vmid]} (#{plan[:node]}) -- CREATE:"
            plan[:params].each do |key, val|
              $stdout.puts "  + #{key}: #{val}"
            end
          end
        end
      end

      # Returns a human-readable type label for a result hash.
      #
      # @param result [Hash] apply result with optional :type key
      # @return [String] "VM" or "Container"
      def type_label_for(result)
        result[:type] == :container ? "Container" : "VM"
      end

      # Builds the PushConfig service with repositories.
      #
      # @param connection [Connection] API connection
      # @return [Services::PushConfig]
      def build_service(connection)
        vm_repo = Pvectl::Repositories::Vm.new(connection)
        ct_repo = Pvectl::Repositories::Container.new(connection)
        Pvectl::Services::PushConfig.new(
          vm_repository: vm_repo,
          container_repository: ct_repo
        )
      end

      # Loads configuration from file/env.
      #
      # @return [void]
      def load_config
        service = Pvectl::Config::Service.new
        service.load(config: @global_options[:config])
        @config = service.current_config
      end

      # Prints a usage error and returns the USAGE_ERROR exit code.
      #
      # @param message [String] error message
      # @return [Integer] USAGE_ERROR exit code
      def usage_error(message)
        $stderr.puts "Error: #{message}"
        ExitCodes::USAGE_ERROR
      end
    end
  end
end
