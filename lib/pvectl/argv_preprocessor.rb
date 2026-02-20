# frozen_string_literal: true

module Pvectl
  # Command line argument preprocessor.
  #
  # Normalizes ARGV arguments before passing to GLI by reordering flags
  # to appear before positional arguments, using GLI command metadata
  # for dynamic flag discovery.
  #
  # GLI with `subcommand_option_handling :normal` requires flags before
  # positional arguments. This preprocessor allows kubectl-style flag
  # placement anywhere on the command line.
  #
  # @example Global flags moved to beginning
  #   ArgvPreprocessor.process(["get", "nodes", "-o", "json"], cli_app: CLI)
  #   #=> ["-o", "json", "get", "nodes"]
  #
  # @example Command flags moved before positional args
  #   ArgvPreprocessor.process(["delete", "vm", "103", "--yes"], cli_app: CLI)
  #   #=> ["delete", "--yes", "vm", "103"]
  #
  # @example Passthrough mode for --help
  #   ArgvPreprocessor.process(["--help", "get"], cli_app: CLI)
  #   #=> ["--help", "get"]  # unchanged
  #
  class ArgvPreprocessor
    # @return [Integer] Maximum number of arguments (DoS protection)
    MAX_ARGUMENTS = 10_000

    # @return [Integer] Maximum length of single argument in bytes
    MAX_ARGUMENT_LENGTH = 4096

    # @return [Array<String>] Flags passed through without processing
    PASSTHROUGH_FLAGS = %w[--help -h --version].freeze

    # Error raised when the same global flag is provided with different values.
    class DuplicateFlagError < Pvectl::Error
      # Creates a new flag duplication error.
      #
      # @param flag_name [Symbol] flag name (e.g., :output)
      # @param existing_value [String, Boolean] first flag value
      # @param new_value [String, Boolean] second (conflicting) flag value
      def initialize(flag_name, existing_value, new_value)
        super("Duplicate global flag --#{flag_name} with different values: #{existing_value}, #{new_value}")
      end
    end

    # Processes command line arguments.
    #
    # @param argv [Array<String>] command line arguments
    # @param cli_app [GLI::App] CLI application with registered commands
    # @return [Array<String>] normalized arguments
    # @raise [ArgumentError] when input limits are exceeded
    # @raise [DuplicateFlagError] when global flag has different values
    def self.process(argv, cli_app: Pvectl::CLI)
      new(argv, cli_app: cli_app).call
    end

    # Initializes preprocessor with a copy of arguments.
    #
    # @param argv [Array<String>] command line arguments
    # @param cli_app [GLI::App] CLI application with registered commands
    def initialize(argv, cli_app: Pvectl::CLI)
      @argv = argv.dup
      @cli_app = cli_app
    end

    # Executes argument processing.
    #
    # @return [Array<String>] normalized arguments
    # @raise [ArgumentError] when input limits are exceeded
    # @raise [DuplicateFlagError] when global flag has different values
    def call
      validate_input_limits!
      return @argv if passthrough_mode?
      return [] if @argv.empty?

      reorder_all_flags
    end

    private

    # Validates input limits for DoS attack protection.
    #
    # @raise [ArgumentError] when argument count or length exceeds limits
    # @return [void]
    def validate_input_limits!
      raise ArgumentError, "Too many arguments (max #{MAX_ARGUMENTS})" if @argv.length > MAX_ARGUMENTS

      @argv.each do |arg|
        raise ArgumentError, "Argument too long (max #{MAX_ARGUMENT_LENGTH})" if arg.length > MAX_ARGUMENT_LENGTH
      end
    end

    # Checks if arguments contain flags requiring passthrough.
    #
    # @return [Boolean] true if --help, -h or --version detected
    def passthrough_mode?
      (@argv & PASSTHROUGH_FLAGS).any?
    end

    # Main reordering logic. Three phases:
    # 1. Extract global flags to front
    # 2. Identify command (and optional subcommand)
    # 3. Reorder command/subcommand flags before positional args
    #
    # @return [Array<String>] reordered arguments
    def reorder_all_flags
      global_flags, rest = extract_global_flags(@argv)
      return global_flags + rest if rest.empty?

      command_name, command_tokens, after_command = identify_command(rest)
      return global_flags + rest unless command_name

      cmd = find_gli_command(command_name)
      return global_flags + rest unless cmd

      # Check for subcommand
      if after_command.any? && cmd.commands.any?
        sub_name = after_command.first
        sub_cmd = find_gli_subcommand(cmd, sub_name)
        if sub_cmd
          subcommand_tokens = [after_command.shift]
          reordered = reorder_command_flags(after_command, sub_cmd)
          return global_flags + command_tokens + subcommand_tokens + reordered
        end
      end

      reordered = reorder_command_flags(after_command, cmd)
      global_flags + command_tokens + reordered
    end

    # Extracts global flags from anywhere in the argument list.
    #
    # @param args [Array<String>] arguments
    # @return [Array(Array<String>, Array<String>)] [extracted_global_flags, remaining_args]
    def extract_global_flags(args)
      global_flags_collected = {}
      global_result = []
      remaining = []
      index = 0

      while index < args.length
        arg = args[index]

        if arg == "--"
          remaining.concat(args[index..])
          break
        end

        flag_info = find_global_flag(arg)
        if flag_info
          name, has_value = flag_info
          if arg.include?("=")
            _, value = arg.split("=", 2)
            validate_value!(value, name)
            store_global_flag(global_flags_collected, name, value)
            global_result << arg
          elsif has_value
            raise ArgumentError, "Missing value for flag #{arg}" if index + 1 >= args.length

            value = args[index + 1]
            validate_value!(value, name)
            store_global_flag(global_flags_collected, name, value)
            global_result << arg << value
            index += 1
          else
            store_global_flag(global_flags_collected, name, true)
            global_result << arg
          end
        else
          remaining << arg
        end

        index += 1
      end

      [global_result, remaining]
    end

    # Finds a global flag definition matching the given argument.
    #
    # @param arg [String] argument to check
    # @return [Array(Symbol, Boolean), nil] [flag_name, has_value] or nil
    def find_global_flag(arg)
      flag_part = arg.split("=", 2).first

      @cli_app.flags.each_value do |flag|
        return [flag_display_name(flag), true] if flag_matches?(flag, flag_part)
      end

      @cli_app.switches.each_value do |sw|
        return [flag_display_name(sw), false] if flag_matches?(sw, flag_part)
      end

      nil
    end

    # Checks if a GLI flag/switch matches the given argument string.
    #
    # @param gli_flag [GLI::Flag, GLI::Switch] GLI flag or switch object
    # @param flag_part [String] argument to match (e.g., "-o", "--output")
    # @return [Boolean] true if matches
    def flag_matches?(gli_flag, flag_part)
      all_names = [gli_flag.name] + (gli_flag.aliases || [])
      all_names.any? do |name|
        prefix = name.to_s.length == 1 ? "-" : "--"
        "#{prefix}#{name}" == flag_part
      end
    end

    # Returns the display name for a GLI flag/switch (prefers long name).
    #
    # @param gli_flag [GLI::Flag, GLI::Switch] GLI flag or switch object
    # @return [Symbol] display name (long form if available)
    def flag_display_name(gli_flag)
      all_names = [gli_flag.name] + (gli_flag.aliases || [])
      long_name = all_names.find { |n| n.to_s.length > 1 }
      long_name || gli_flag.name
    end

    # Stores a global flag value with duplicate detection.
    #
    # @param store [Hash] flag storage
    # @param name [Symbol] flag name
    # @param value [String, Boolean] flag value
    # @raise [DuplicateFlagError] when flag already exists with different value
    # @return [void]
    def store_global_flag(store, name, value)
      if store.key?(name)
        existing = store[name]
        raise DuplicateFlagError.new(name, existing, value) if existing != value
      else
        store[name] = value
      end
    end

    # Validates flag value for security.
    #
    # @param value [String, Boolean] value to validate
    # @param flag_name [Symbol] flag name (for error message)
    # @raise [ArgumentError] when value contains null byte
    # @return [void]
    def validate_value!(value, flag_name)
      return if value == true

      raise ArgumentError, "Invalid null byte in value for --#{flag_name}" if value.to_s.include?("\x00")
    end

    # Identifies the command name from remaining args (after global flag extraction).
    #
    # @param args [Array<String>] arguments without global flags
    # @return [Array(String, Array<String>, Array<String>)] [command_name, command_tokens, rest]
    def identify_command(args)
      return [nil, [], args] if args.empty? || args.first.start_with?("-")

      command_name = args.first
      [command_name, [command_name], args[1..]]
    end

    # Finds a GLI command by name (supports aliases and dash-to-underscore).
    #
    # @param name [String] command name
    # @return [GLI::Command, nil] command object or nil
    def find_gli_command(name)
      @cli_app.commands[name.to_sym] || @cli_app.commands[name.tr("-", "_").to_sym]
    end

    # Finds a GLI subcommand by name (supports aliases and dash-to-underscore).
    #
    # @param cmd [GLI::Command] parent command
    # @param name [String] subcommand name
    # @return [GLI::Command, nil] subcommand object or nil
    def find_gli_subcommand(cmd, name)
      cmd.commands[name.to_sym] || cmd.commands[name.tr("-", "_").to_sym]
    end

    # Reorders command flags to appear before positional arguments.
    #
    # @param args [Array<String>] arguments after command name
    # @param cmd [GLI::Command] GLI command with flag/switch metadata
    # @return [Array<String>] reordered arguments
    def reorder_command_flags(args, cmd)
      flags = []
      positional = []
      index = 0

      while index < args.length
        arg = args[index]

        if arg == "--"
          positional.concat(args[index..])
          break
        end

        flag_info = find_command_flag(arg, cmd)
        unless flag_info.nil?
          has_value = flag_info
          if has_value && !arg.include?("=") && index + 1 < args.length
            flags << arg << args[index + 1]
            index += 1
          else
            flags << arg
          end
        else
          positional << arg
        end

        index += 1
      end

      flags + positional
    end

    # Finds a command flag/switch definition matching the given argument.
    #
    # @param arg [String] argument to check
    # @param cmd [GLI::Command] command to search in
    # @return [Boolean, nil] has_value (true for flags, false for switches) or nil if not found
    def find_command_flag(arg, cmd)
      flag_part = arg.split("=", 2).first

      cmd.flags.each_value do |flag|
        return true if flag_matches?(flag, flag_part)
      end

      cmd.switches.each_value do |sw|
        return false if flag_matches?(sw, flag_part)
      end

      nil
    end
  end
end
