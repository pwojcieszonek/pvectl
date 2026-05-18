# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl edit hosts` command.
    #
    # Opens /etc/hosts for a node in the user's editor. On save, POSTs the
    # new content back via /nodes/{node}/hosts with the original digest for
    # optimistic concurrency control.
    #
    # The node identifier may be supplied either as a positional argument
    # (matching `pvectl edit node NAME` semantics) or via the --node flag.
    #
    # @example Basic usage
    #   pvectl edit hosts pve1
    #   pvectl edit hosts --node pve1
    #
    # @example Dry-run mode
    #   pvectl edit hosts pve1 --dry-run
    #
    class EditHosts
      # Executes the edit hosts command.
      #
      # @param args [Array<String>] command arguments (positional NODE)
      # @param options [Hash] command options (:node, :editor, :"dry-run")
      # @param global_options [Hash] global CLI options
      # @return [Integer] exit code
      def self.execute(args, options, global_options)
        new(args, options, global_options).execute
      end

      # Initializes the command.
      #
      # @param args [Array<String>] command arguments
      # @param options [Hash] command options
      # @param global_options [Hash] global CLI options
      def initialize(args, options, global_options)
        @args = args
        @options = options
        @global_options = global_options
      end

      # Executes the edit flow.
      #
      # @return [Integer] exit code
      def execute
        node_name = @args.first || @options[:node]
        return usage_error("NODE is required (positional argument or --node flag)") if node_name.nil? || node_name.empty?

        load_config
        connection = Pvectl::Connection.new(@config)
        service = build_edit_service(connection)
        result = service.execute(node_name: node_name)

        if result.nil?
          $stdout.puts "Edit cancelled, no changes made."
          return ExitCodes::SUCCESS
        end

        if result.successful?
          if @options[:"dry-run"]
            $stdout.puts "(dry-run mode — no changes applied)"
          else
            $stdout.puts "/etc/hosts on node #{node_name} updated successfully."
          end
          ExitCodes::SUCCESS
        else
          $stderr.puts "Error: #{result.error}"
          ExitCodes::GENERAL_ERROR
        end
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

      # Builds the EditHosts service with a connection.
      #
      # @param connection [Connection] API connection
      # @return [Services::EditHosts]
      def build_edit_service(connection)
        hosts_repo = Pvectl::Repositories::Hosts.new(connection)
        Pvectl::Services::EditHosts.new(
          hosts_repository: hosts_repo,
          editor_session: build_editor_session,
          options: service_options
        )
      end

      # Loads configuration from file or environment.
      #
      # @return [void]
      def load_config
        service = Pvectl::Config::Service.new
        service.load(config: @global_options[:config])
        @config = service.current_config
      end

      # Builds service options from CLI options.
      #
      # @return [Hash] service options
      def service_options
        opts = {}
        opts[:dry_run] = true if @options[:"dry-run"]
        opts
      end

      # Builds an editor session from --editor option.
      #
      # @return [EditorSession, nil] editor session or nil if no --editor flag
      def build_editor_session
        editor_cmd = @options[:editor]
        return nil unless editor_cmd

        Pvectl::EditorSession.new(editor: ->(path) { system(editor_cmd, path) })
      end

      # Outputs usage error and returns exit code.
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
