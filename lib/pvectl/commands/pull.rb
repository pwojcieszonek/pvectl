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

            When writing to files (-f), shows a diff of changes and asks for
            confirmation before overwriting existing files. Use --yes to skip
            confirmation or --dry-run to preview changes without writing.

          EXAMPLES
            $ pvectl pull vm 100
            $ pvectl pull vm 100 -f vm-100.yaml
            $ pvectl pull vm 100 -f vm-100.yaml --dry-run
            $ pvectl pull vm 100 101 102 -f ./manifests/
            $ pvectl pull vm --all -f ./manifests/ --yes
            $ pvectl pull vm -l tags=prod -f ./manifests/
            $ pvectl pull container 200

          NOTES
            Without -f, YAML is printed to stdout (pipe-friendly).
            With -f, shows diff against existing files and asks to confirm.
            With --all or -l, -f must point to a directory.
            File naming convention: vm-{vmid}.yaml or ct-{vmid}.yaml.

          SEE ALSO
            push, get, describe, edit
        HELP

        cli.command :pull do |c|
          c.flag [:f, :file], desc: "Output file or directory"
          c.flag [:l, :selector], desc: "Filter by selector (e.g. tags=prod,status=running)", multiple: true
          c.switch [:all], desc: "Pull all resources of given type", negatable: false
          c.switch [:y, :yes], desc: "Auto-confirm without prompting", negatable: false
          c.switch [:"dry-run"], desc: "Show diff without writing files", negatable: false
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

      # Writes pull results to stdout or files.
      # For file output, shows diff against existing files and asks for confirmation.
      #
      # @param manifests [Array<Hash>] pulled manifests with :yaml and :vmid
      # @param type [Symbol] :vm or :container
      # @param output [String, nil] output file/directory or nil for stdout
      # @return [void]
      def write_output(manifests, type, output)
        return if manifests.empty?

        if output.nil?
          # stdout mode -- no diff, just print
          manifests.each { |m| $stdout.puts m[:yaml] }
          return
        end

        # File output mode -- build operations, show diff, confirm, write
        operations = build_file_operations(manifests, type, output)
        actionable = operations.reject { |op| op[:action] == :unchanged }

        if actionable.empty?
          $stdout.puts "No changes."
          return
        end

        display_pull_plan(operations, type)

        if @options[:"dry-run"]
          $stdout.puts "\n(dry-run mode -- no files written)"
          return
        end

        unless @options[:yes]
          $stdout.print "\nWrite #{actionable.length} file(s)? [y/N] "
          answer = $stdin.gets&.strip&.downcase
          unless answer == "y" || answer == "yes"
            $stdout.puts "Cancelled."
            return
          end
        end

        apply_file_operations(operations)
      end

      # Builds a list of file operations (create/update/unchanged) for each manifest.
      #
      # @param manifests [Array<Hash>] pulled manifests
      # @param type [Symbol] :vm or :container
      # @param output [String] output file or directory path
      # @return [Array<Hash>] operation hashes with :action, :path, :vmid, :yaml, :diff
      def build_file_operations(manifests, type, output)
        if manifests.length == 1 && !directory_output?(output)
          [build_operation(manifests.first, output, type)]
        else
          prefix = FILE_PREFIXES[type]
          manifests.map do |m|
            filename = "#{prefix}-#{m[:vmid]}.yaml"
            path = File.join(output, filename)
            build_operation(m, path, type)
          end
        end
      end

      # Builds a single file operation by comparing new YAML with existing file.
      #
      # @param manifest [Hash] manifest with :yaml and :vmid
      # @param path [String] target file path
      # @param type [Symbol] :vm or :container
      # @return [Hash] operation hash
      def build_operation(manifest, path, type)
        new_yaml = manifest[:yaml]

        unless File.file?(path)
          return { action: :create, path: path, vmid: manifest[:vmid], yaml: new_yaml }
        end

        old_yaml = File.read(path)
        return { action: :unchanged, path: path, vmid: manifest[:vmid] } if old_yaml == new_yaml

        diff = compute_manifest_diff(old_yaml, new_yaml, type)
        { action: :update, path: path, vmid: manifest[:vmid], yaml: new_yaml, diff: diff }
      end

      # Computes a flat config diff between old and new manifest YAML strings.
      #
      # @param old_yaml [String] existing file content
      # @param new_yaml [String] new content from server
      # @param type [Symbol] :vm or :container
      # @return [Hash, nil] diff hash or nil on parse error
      def compute_manifest_diff(old_yaml, new_yaml, type)
        old_manifest = ManifestSerializer.from_yaml(old_yaml)
        new_manifest = ManifestSerializer.from_yaml(new_yaml)
        old_flat = ConfigSerializer.from_nested(old_manifest[:spec], type: type)
        new_flat = ConfigSerializer.from_nested(new_manifest[:spec], type: type)
        ConfigSerializer.diff(old_flat, new_flat)
      rescue StandardError
        nil
      end

      # Displays the pull plan with diffs for each file operation.
      #
      # @param operations [Array<Hash>] file operations
      # @param type [Symbol] :vm or :container
      # @return [void]
      def display_pull_plan(operations, type)
        label = type == :container ? "Container" : "VM"
        operations.each do |op|
          case op[:action]
          when :create
            $stdout.puts "\n#{label} #{op[:vmid]} -- NEW (#{File.basename(op[:path])})"
          when :update
            $stdout.puts "\n#{label} #{op[:vmid]} -- UPDATE (#{File.basename(op[:path])}):"
            if op[:diff] && diff_has_changes?(op[:diff])
              $stdout.puts ConfigSerializer.format_diff(op[:diff])
            else
              $stdout.puts "  (metadata changed)"
            end
          when :unchanged
            $stderr.puts "Info: #{File.basename(op[:path])}: no changes"
          end
        end
      end

      # Checks if a diff hash has any actual changes.
      #
      # @param diff [Hash] diff hash from ConfigSerializer.diff
      # @return [Boolean]
      def diff_has_changes?(diff)
        diff[:changed].any? || diff[:added].any? || diff[:removed].any?
      end

      # Writes files for all actionable operations.
      #
      # @param operations [Array<Hash>] file operations
      # @return [void]
      def apply_file_operations(operations)
        written = 0
        operations.each do |op|
          next if op[:action] == :unchanged

          dir = File.dirname(op[:path])
          FileUtils.mkdir_p(dir) unless File.directory?(dir)
          File.write(op[:path], op[:yaml])
          written += 1
        end
        $stderr.puts "Written #{written} manifest(s)"
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
