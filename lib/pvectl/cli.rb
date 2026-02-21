# frozen_string_literal: true

require "gli"

module Pvectl
  # Main CLI class using the GLI framework.
  #
  # The CLI class is the entry point for the pvectl command line interface.
  # It is responsible for:
  # - Defining global flags and options
  # - Loading commands via PluginLoader (built-in + plugins)
  # - Error handling and system signal handling
  #
  # Uses the GLI (Git-Like Interface) framework to create commands
  # in kubectl/git style.
  #
  # @example Running CLI
  #   Pvectl::CLI.run(ARGV)
  #
  # @example Typical command line usage
  #   pvectl get nodes                    # List nodes
  #   pvectl get vms -o json              # List VMs in JSON format
  #   pvectl describe vm 100 --verbose    # VM details with debugging
  #
  # @see https://github.com/davetron5000/gli GLI documentation
  # @see Pvectl::ExitCodes Exit codes used by CLI
  #
  class CLI
    extend GLI::App

    # Program configuration - description and version shown in --help and --version
    program_desc "CLI tool for managing Proxmox clusters with kubectl-like syntax"
    version Pvectl::VERSION

    # Help formatting: preserve whitespace for code examples in long_desc
    wrap_help_text :verbatim

    # Display commands in declaration order (not alphabetical)
    sort_help :manually

    # Enable normal flag processing in subcommands
    # Note: We do NOT use 'arguments :strict' to allow flexible flag/argument ordering
    subcommand_option_handling :normal

    # @!group Global flags

    desc "Output format (table, json, yaml, wide)"
    arg_name "FORMAT"
    default_value "table"
    flag [:o, :output], must_match: %w[table json yaml wide]

    desc "Enable verbose output for debugging"
    switch [:v, :verbose], negatable: false

    desc "Path to configuration file"
    arg_name "FILE"
    flag [:c, :config]

    desc "Force colored output (even when not TTY)"
    switch [:color], negatable: true, default_value: nil

    # @!endgroup

    # Error handling - maps exceptions to appropriate exit codes.
    #
    # @param exception [Exception] caught exception
    # @return [void]
    on_error do |exception|
      case exception
      when SystemExit
        # Re-raise SystemExit to preserve the exit code
        raise
      when GLI::BadCommandLine, GLI::UnknownCommand
        $stderr.puts "Error: #{exception.message}"
        exit ExitCodes::USAGE_ERROR
      when Pvectl::ArgvPreprocessor::DuplicateFlagError
        $stderr.puts "Error: #{exception.message}"
        exit ExitCodes::USAGE_ERROR
      when Pvectl::Config::ContextNotFoundError,
           Pvectl::Config::ClusterNotFoundError,
           Pvectl::Config::UserNotFoundError,
           Pvectl::Config::ConfigNotFoundError,
           Pvectl::Config::InvalidConfigError
        $stderr.puts "Error: #{exception.message}"
        exit ExitCodes::CONFIG_ERROR
      else
        $stderr.puts "Error: #{exception.message}"
        $stderr.puts exception.backtrace.join("\n") if ENV["GLI_DEBUG"] == "true"
        exit ExitCodes::GENERAL_ERROR
      end
    end

    # SIGINT (Ctrl+C) handling - clean exit with code 130
    trap("INT") do
      $stderr.puts "\nInterrupted"
      exit ExitCodes::INTERRUPTED
    end

    # --- Load all commands (built-in + plugins) ---
    Pvectl::PluginLoader.load_all(self)
  end
end
