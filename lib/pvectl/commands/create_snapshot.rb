# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl create snapshot` sub-command.
    #
    # Creates snapshots for VMs/containers. Snapshot name is the first
    # positional argument, VMIDs are specified via --vmid flag.
    # Without --vmid, operates on ALL VMs/CTs in the cluster.
    #
    # @example Create single snapshot
    #   pvectl create snapshot before-upgrade --vmid 100
    #
    # @example Create for multiple VMs
    #   pvectl create snapshot before-upgrade --vmid 100 --vmid 101
    #
    # @example Create cluster-wide
    #   pvectl create snapshot before-upgrade --yes
    #
    class CreateSnapshot
      VMID_PATTERN = /\A[1-9]\d{0,8}\z/

      # Registers as a sub-command under the parent create command.
      #
      # @param parent [GLI::Command] the parent create command
      # @return [void]
      def self.register_subcommand(parent)
        parent.command :snapshot do |s|
          s.desc "VM/CT ID (repeatable)"
          s.flag [:vmid], arg_name: "VMID", multiple: true

          s.desc "Save VM memory state (QEMU only)"
          s.switch [:vmstate], negatable: false

          s.action do |global_options, options, args|
            exit_code = execute(args, options, global_options)
            exit exit_code if exit_code != 0
          end
        end
      end

      # Executes the create snapshot command.
      #
      # @param args [Array<String>] positional args (snapshot name)
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      # @return [Integer] exit code
      def self.execute(args, options, global_options)
        new(args, options, global_options).execute
      end

      # Initializes a create snapshot command.
      #
      # @param args [Array<String>] positional args (snapshot name)
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(args, options, global_options)
        @args = Array(args)
        @options = options
        @global_options = global_options
        @snapshot_name = @args.first
        @vmids = parse_vmids(options[:vmid])
        @node = options[:node]
      end

      # Executes the create snapshot command.
      #
      # @return [Integer] exit code
      def execute
        return usage_error("Snapshot name required") unless @snapshot_name
        return usage_error("Invalid VMID: #{invalid_vmid}") if invalid_vmid

        perform_operation
      end

      private

      # Parses --vmid flag values to integer array.
      #
      # @param vmid_values [Array<String>, nil] raw vmid values
      # @return [Array<Integer>] parsed VMIDs
      def parse_vmids(vmid_values)
        return [] if vmid_values.nil? || vmid_values.empty?

        Array(vmid_values).map(&:to_i)
      end

      # Finds first invalid VMID in options.
      #
      # @return [String, nil] invalid VMID value or nil
      def invalid_vmid
        return nil if @options[:vmid].nil? || @options[:vmid].empty?

        Array(@options[:vmid]).find { |v| !VMID_PATTERN.match?(v.to_s) }
      end

      # Performs the snapshot creation operation.
      #
      # @return [Integer] exit code
      def perform_operation
        load_config
        connection = Pvectl::Connection.new(@config)

        snapshot_repo = Pvectl::Repositories::Snapshot.new(connection)
        resolver = Pvectl::Utils::ResourceResolver.new(connection)
        task_repo = Pvectl::Repositories::Task.new(connection)

        service = Pvectl::Services::Snapshot.new(
          snapshot_repo: snapshot_repo,
          resource_resolver: resolver,
          task_repo: task_repo,
          options: service_options
        )

        return ExitCodes::SUCCESS unless confirm_operation

        results = service.create(
          @vmids,
          name: @snapshot_name,
          description: @options[:description],
          vmstate: @options[:vmstate] || false,
          node: @node
        )

        output_results(results)
        determine_exit_code(results)
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

      # Confirms operation with user prompt.
      #
      # @return [Boolean] true if operation should proceed
      def confirm_operation
        return true if @vmids.size == 1
        return true if @options[:yes]

        if @vmids.empty?
          $stdout.puts "You are about to create snapshot '#{@snapshot_name}' for ALL VMs/CTs in the cluster."
        else
          $stdout.puts "You are about to create snapshot '#{@snapshot_name}' for #{@vmids.size} VMs:"
          @vmids.each { |vmid| $stdout.puts "  - #{vmid}" }
        end
        $stdout.puts ""
        $stdout.print "Proceed? [y/N]: "

        response = $stdin.gets&.strip&.downcase
        %w[y yes].include?(response)
      end

      # Loads configuration.
      #
      # @return [void]
      def load_config
        service = Pvectl::Config::Service.new
        service.load(config: @global_options[:config])
        @config = service.current_config
      end

      # Builds service options.
      #
      # @return [Hash] service options
      def service_options
        opts = {}
        opts[:timeout] = @options[:timeout] if @options[:timeout]
        opts[:async] = true if @options[:async]
        opts[:fail_fast] = true if @options[:"fail-fast"]
        opts
      end

      # Outputs operation results.
      #
      # @param results [Array<Models::OperationResult>] results
      # @return [void]
      def output_results(results)
        presenter = Pvectl::Presenters::SnapshotOperationResult.new
        format = @global_options[:output] || "table"
        color_flag = @global_options[:color]

        formatter = Pvectl::Formatters::Registry.for(format)
        output = formatter.format(results, presenter, color: color_flag)
        puts output
      end

      # Determines exit code.
      #
      # @param results [Array<Models::OperationResult>] results
      # @return [Integer] exit code
      def determine_exit_code(results)
        return ExitCodes::SUCCESS if results.all?(&:successful?)
        return ExitCodes::SUCCESS if results.all?(&:pending?)

        ExitCodes::GENERAL_ERROR
      end

      # Outputs usage error.
      #
      # @param message [String] error message
      # @return [Integer] exit code
      def usage_error(message)
        $stderr.puts "Error: #{message}"
        ExitCodes::USAGE_ERROR
      end
    end
  end
end
