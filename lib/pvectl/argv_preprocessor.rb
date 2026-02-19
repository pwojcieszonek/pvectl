# frozen_string_literal: true

module Pvectl
  # Command line argument preprocessor.
  #
  # Normalizes ARGV arguments before passing to GLI by:
  # 1. Moving global flags (--output, --verbose, --config) to the beginning
  # 2. Moving subcommand flags before positional arguments
  #
  # This allows using flags anywhere on the command line, providing
  # kubectl-like flexibility.
  #
  # @example Normalizing global flags
  #   ArgvPreprocessor.process(["get", "nodes", "-o", "json"])
  #   #=> ["-o", "json", "get", "nodes"]
  #
  # @example Flags with value via '='
  #   ArgvPreprocessor.process(["get", "vms", "--output=yaml"])
  #   #=> ["-o", "yaml", "get", "vms"]
  #
  # @example Subcommand flags after positional argument
  #   ArgvPreprocessor.process(["config", "set-cluster", "test", "--server", "https://..."])
  #   #=> ["config", "set-cluster", "--server", "https://...", "test"]
  #
  # @example Passthrough mode for --help
  #   ArgvPreprocessor.process(["--help", "get"])
  #   #=> ["--help", "get"]  # unchanged
  #
  class ArgvPreprocessor
    # @return [Integer] Maximum number of arguments (DoS protection)
    MAX_ARGUMENTS = 10_000

    # @return [Integer] Maximum length of single argument in bytes
    MAX_ARGUMENT_LENGTH = 4096

    # @return [Hash<Symbol, Hash>] Global flags configuration
    #   - :short - short flag form (e.g., "-o")
    #   - :long - long flag form (e.g., "--output")
    #   - :has_value - whether flag requires a value
    GLOBAL_FLAGS = {
      output:  { short: "-o", long: "--output",  has_value: true },
      verbose: { short: "-v", long: "--verbose", has_value: false },
      config:  { short: "-c", long: "--config",  has_value: true }
    }.freeze

    # @return [Array<String>] Flags passed through without processing
    PASSTHROUGH_FLAGS = %w[--help -h --version].freeze

    # @return [Hash<String, Hash>] Subcommand flags configuration
    #   Maps "command subcommand" to flag definitions
    SUBCOMMAND_FLAGS = {
      "config set-cluster" => {
        server: { long: "--server", has_value: true },
        "certificate-authority": { long: "--certificate-authority", has_value: true },
        "insecure-skip-tls-verify": { long: "--insecure-skip-tls-verify", has_value: false }
      },
      "config set-credentials" => {
        "token-id": { long: "--token-id", has_value: true },
        "token-secret": { long: "--token-secret", has_value: true },
        username: { long: "--username", has_value: true },
        password: { long: "--password", has_value: true }
      },
      "config set-context" => {
        cluster: { long: "--cluster", has_value: true },
        user: { long: "--user", has_value: true },
        "default-node": { long: "--default-node", has_value: true }
      }
    }.freeze

    # Error raised when the same flag is provided with different values.
    #
    # @example Situation causing error
    #   pvectl -o json get nodes -o yaml  # DuplicateFlagError
    #
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
    # Factory method that creates an instance and invokes processing.
    #
    # @param argv [Array<String>] command line arguments
    # @return [Array<String>] normalized arguments with global flags at the beginning
    # @raise [ArgumentError] when input limits are exceeded
    # @raise [DuplicateFlagError] when global flag has different values
    def self.process(argv)
      new(argv).call
    end

    # Initializes preprocessor with a copy of arguments.
    #
    # @param argv [Array<String>] command line arguments
    def initialize(argv)
      @argv = argv.dup
      @extracted_flags = {}
      @remaining_args = []
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

      process_arguments
      result = build_result
      reorder_subcommand_flags(result)
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

    # Processes all arguments iteratively.
    #
    # @return [void]
    def process_arguments
      index = 0
      while index < @argv.length
        arg = @argv[index]
        index = process_single_argument(arg, index)
      end
    end

    # Processes a single argument.
    #
    # @param arg [String] current argument
    # @param index [Integer] argument index in array
    # @return [Integer] next index to process
    def process_single_argument(arg, index)
      if arg == "--"
        @remaining_args.concat(@argv[index..])
        return @argv.length
      end

      flag_config = find_flag_config(arg)
      if flag_config
        process_global_flag(arg, index, flag_config)
      else
        @remaining_args << arg
        index + 1
      end
    end

    # Finds configuration for a global flag.
    #
    # @param arg [String] argument to check
    # @return [Hash, nil] flag configuration or nil if not a global flag
    def find_flag_config(arg)
      flag_part = arg.split("=", 2).first
      GLOBAL_FLAGS.each do |_name, config|
        return config if flag_part == config[:short] || flag_part == config[:long]
      end
      nil
    end

    # Processes global flag and its value.
    #
    # @param arg [String] argument with flag
    # @param index [Integer] current index
    # @param config [Hash] flag configuration
    # @return [Integer] next index to process
    # @raise [ArgumentError] when value missing for flag requiring value
    def process_global_flag(arg, index, config)
      flag_name = GLOBAL_FLAGS.key(config)

      if arg.include?("=")
        _, value = arg.split("=", 2)
        store_flag(flag_name, value)
        index + 1
      elsif config[:has_value]
        raise ArgumentError, "Missing value for flag #{arg}" if index + 1 >= @argv.length
        value = @argv[index + 1]
        store_flag(flag_name, value)
        index + 2
      else
        store_flag(flag_name, true)
        index + 1
      end
    end

    # Stores flag value with duplicate detection.
    #
    # @param name [Symbol] flag name
    # @param value [String, Boolean] flag value
    # @raise [DuplicateFlagError] when flag already exists with different value
    # @return [void]
    def store_flag(name, value)
      validate_value!(value, name)
      if @extracted_flags.key?(name)
        existing = @extracted_flags[name]
        raise DuplicateFlagError.new(name, existing, value) if existing != value
      else
        @extracted_flags[name] = value
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

    # Builds result argument array.
    #
    # Global flags are placed at the beginning in fixed order,
    # followed by remaining arguments.
    #
    # @return [Array<String>] normalized arguments
    def build_result
      result = []
      GLOBAL_FLAGS.each_key do |name|
        next unless @extracted_flags.key?(name)
        config = GLOBAL_FLAGS[name]
        value = @extracted_flags[name]
        result << config[:short]
        result << value.to_s unless value == true
      end
      result.concat(@remaining_args)
    end

    # Reorders subcommand flags to appear before positional arguments.
    #
    # Identifies the command/subcommand pattern and moves known flags
    # before the first positional argument after the subcommand.
    #
    # @param args [Array<String>] arguments after global flag processing
    # @return [Array<String>] arguments with subcommand flags reordered
    def reorder_subcommand_flags(args)
      return args if args.empty?

      # Find double-dash position to limit processing
      double_dash_pos = args.index("--")

      # Identify command and subcommand (skip global flags at beginning)
      subcommand_info = find_subcommand_key(args)
      return args unless subcommand_info

      subcommand_key, cmd_start_index = subcommand_info
      flags_config = SUBCOMMAND_FLAGS[subcommand_key]
      return args unless flags_config

      # Find where subcommand ends (index after subcommand name)
      subcommand_parts = subcommand_key.split
      subcommand_end_index = cmd_start_index + subcommand_parts.length

      # Process arguments after subcommand
      reorder_flags_after_subcommand(args, cmd_start_index, subcommand_end_index, flags_config, double_dash_pos)
    end

    # Finds the subcommand key from arguments, skipping global flags.
    #
    # @param args [Array<String>] arguments
    # @return [Array(String, Integer), nil] [subcommand_key, start_index] or nil if not found
    def find_subcommand_key(args)
      # Skip global flags at the beginning to find command
      cmd_start = 0
      while cmd_start < args.length
        arg = args[cmd_start]
        global_config = find_flag_config(arg)
        if global_config
          # Skip global flag and its value if needed
          cmd_start += global_config[:has_value] && !arg.include?("=") ? 2 : 1
        else
          break
        end
      end

      # Check for two-part subcommand (e.g., "config set-cluster")
      if args.length >= cmd_start + 2
        key = "#{args[cmd_start]} #{args[cmd_start + 1]}"
        return [key, cmd_start] if SUBCOMMAND_FLAGS.key?(key)
      end
      nil
    end

    # Reorders flags after subcommand to appear before positional arguments.
    #
    # @param args [Array<String>] arguments
    # @param cmd_start_index [Integer] index where command starts
    # @param subcommand_end_index [Integer] index after subcommand
    # @param flags_config [Hash] subcommand flags configuration
    # @param double_dash_pos [Integer, nil] position of -- or nil
    # @return [Array<String>] reordered arguments
    def reorder_flags_after_subcommand(args, cmd_start_index, subcommand_end_index, flags_config, double_dash_pos)
      global_prefix = args[0...cmd_start_index]
      subcommand_prefix = args[cmd_start_index...subcommand_end_index]
      rest = args[subcommand_end_index..]

      # Limit rest to before double-dash if present
      if double_dash_pos && double_dash_pos >= subcommand_end_index
        rest = args[subcommand_end_index...double_dash_pos]
        after_double_dash = args[double_dash_pos..]
      else
        after_double_dash = []
      end

      extracted_flags = []
      positional_args = []
      index = 0

      while index < rest.length
        arg = rest[index]

        if arg.start_with?("-")
          flag_info = find_subcommand_flag(arg, flags_config)
          if flag_info
            extracted_flags << arg
            if flag_info[:has_value] && !arg.include?("=") && index + 1 < rest.length
              index += 1
              extracted_flags << rest[index]
            end
          else
            # Unknown flag - keep with positional args
            positional_args << arg
          end
        else
          positional_args << arg
        end

        index += 1
      end

      global_prefix + subcommand_prefix + extracted_flags + positional_args + after_double_dash
    end

    # Finds subcommand flag configuration.
    #
    # @param arg [String] argument to check
    # @param flags_config [Hash] subcommand flags configuration
    # @return [Hash, nil] flag configuration or nil
    def find_subcommand_flag(arg, flags_config)
      flag_part = arg.split("=", 2).first
      flags_config.each_value do |config|
        return config if flag_part == config[:long]
      end
      nil
    end
  end
end
