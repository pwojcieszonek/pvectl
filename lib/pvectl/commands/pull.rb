# frozen_string_literal: true

require "fileutils"

module Pvectl
  module Commands
    # Pull command -- exports resource configuration from the Proxmox cluster
    # as kubectl-like YAML manifest files.
    #
    # @example Register with CLI
    #   Pull.register(cli)
    class Pull
      RESOURCE_TYPES = {
        "vm" => :vm,
        "vms" => :vm,
        "container" => :container,
        "containers" => :container,
        "ct" => :container
      }.freeze

      FILE_PREFIXES = {
        vm: "vm",
        container: "ct"
      }.freeze

      # Registers the pull command with the CLI.
      #
      # @param cli [GLI::App] the CLI application object
      # @return [void]
      def self.register(cli)
        cli.desc "Pull resource configuration to YAML manifest"
        cli.long_desc <<~HELP
          DESCRIPTION
            Exports resource configuration from the Proxmox cluster as kubectl-like
            YAML manifest files. Supports single resources, multiple IDs, selectors,
            and bulk export with --all.

          EXAMPLES
            $ pvectl pull vm 100
            $ pvectl pull vm 100 -f vm-100.yaml
            $ pvectl pull vm 100 101 102 -f ./manifests/
            $ pvectl pull vm --all -f ./manifests/
            $ pvectl pull vm -l tags=prod -f ./manifests/
            $ pvectl pull container 200

          NOTES
            Without -f, YAML is printed to stdout (pipe-friendly).
            With --all or -l, -f must point to a directory.
            File naming convention: vm-{vmid}.yaml or ct-{vmid}.yaml.

          SEE ALSO
            push, get, describe, edit
        HELP

        cli.command :pull do |c|
          c.flag [:f, :file], desc: "Output file or directory"
          c.flag [:l, :selector], desc: "Filter by selector (e.g. tags=prod,status=running)", multiple: true
          c.switch [:all], desc: "Pull all resources of given type", negatable: false
          c.flag [:node], desc: "Limit to specific node"

          c.action do |global_options, options, args|
            Pull.new(args, options, global_options).execute
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

      # Executes the pull command.
      #
      # @return [Integer] exit code
      def execute
        resource_type_str = @args.shift
        return usage_error("Resource type is required (vm, container)") unless resource_type_str

        type = RESOURCE_TYPES[resource_type_str.downcase]
        return usage_error("Unknown resource type '#{resource_type_str}'. Valid: vm, container") unless type

        ids = @args.map(&:to_i)
        all = @options[:all]
        node = @options[:node]
        output = @options[:file]

        if ids.empty? && !all && @options[:selector].nil?
          return usage_error("Provide resource IDs, --all, or -l selector")
        end

        if (all || @options[:selector]) && output && !directory_output?(output)
          return usage_error("--all and -l require -f to be a directory (end with /)")
        end

        selector = build_selector(type)

        load_config
        connection = Pvectl::Connection.new(@config)
        service = build_service(connection)

        result = service.execute(type: type, ids: ids, all: all, node: node, selector: selector)

        result[:errors].each { |e| $stderr.puts "Error: #{e}" }

        write_output(result[:manifests], type, output)

        result[:errors].empty? ? ExitCodes::SUCCESS : ExitCodes::GENERAL_ERROR
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

      def build_service(connection)
        vm_repo = Pvectl::Repositories::Vm.new(connection)
        ct_repo = Pvectl::Repositories::Container.new(connection)
        Pvectl::Services::PullConfig.new(
          vm_repository: vm_repo,
          container_repository: ct_repo
        )
      end

      def build_selector(type)
        expressions = @options[:selector]
        return nil if expressions.nil? || (expressions.is_a?(Array) && expressions.empty?)

        selector_class = type == :container ? Selectors::Container : Selectors::Vm
        selector_class.new(Array(expressions))
      end

      def write_output(manifests, type, output)
        return if manifests.empty?

        if output.nil?
          # stdout mode
          manifests.each { |m| $stdout.puts m[:yaml] }
        elsif manifests.length == 1 && !directory_output?(output)
          # single file mode
          File.write(output, manifests.first[:yaml])
          $stderr.puts "Written to #{output}"
        else
          # directory mode
          FileUtils.mkdir_p(output)
          prefix = FILE_PREFIXES[type]
          manifests.each do |m|
            filename = "#{prefix}-#{m[:vmid]}.yaml"
            path = File.join(output, filename)
            File.write(path, m[:yaml])
          end
          $stderr.puts "Written #{manifests.length} manifest(s) to #{output}"
        end
      end

      def directory_output?(path)
        return false if path.nil?

        path.end_with?("/") || File.directory?(path)
      end

      def load_config
        service = Pvectl::Config::Service.new
        service.load(config: @global_options[:config])
        @config = service.current_config
      end

      def usage_error(message)
        $stderr.puts "Error: #{message}"
        ExitCodes::USAGE_ERROR
      end
    end
  end
end
