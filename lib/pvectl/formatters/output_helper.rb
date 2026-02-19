# frozen_string_literal: true

module Pvectl
  module Formatters
    # Facade for output formatting in commands.
    #
    # Coordinates Formatter and Presenter to produce formatted output.
    # Handles color flag interpretation and prints to stdout.
    #
    # @example Usage in a command
    #   def self.execute(global_options)
    #     service = Pvectl::Services::Vm.new
    #     vms = service.list
    #     presenter = Pvectl::Presenters::Vm.new
    #
    #     OutputHelper.print(
    #       data: vms,
    #       presenter: presenter,
    #       format: global_options[:output],
    #       color_flag: global_options[:color]
    #     )
    #   end
    #
    # @example Rendering without printing (for testing)
    #   output = OutputHelper.render(
    #     data: vms,
    #     presenter: presenter,
    #     format: "json"
    #   )
    #
    module OutputHelper
      class << self
        # Formats data and prints to stdout.
        #
        # @param data [Array, Object] collection of models or single model
        # @param presenter [Presenters::Base] presenter for the resource type
        # @param format [String] output format ("table", "json", "yaml", "wide")
        # @param color_flag [Boolean, nil] color flag from CLI
        #   - true: --color was passed
        #   - false: --no-color was passed
        #   - nil: auto-detect based on TTY
        # @param describe [Boolean] whether this is a describe command (default: false)
        # @param context [Hash] additional context passed to presenter
        # @return [void]
        def print(data:, presenter:, format: "table", color_flag: nil, describe: false, **context)
          output = render(data: data, presenter: presenter, format: format, color_flag: color_flag, describe: describe, **context)
          puts output
        end

        # Returns formatted string without printing.
        #
        # Useful for testing or when you need to manipulate the output
        # before displaying.
        #
        # @param data [Array, Object] collection of models or single model
        # @param presenter [Presenters::Base] presenter for the resource type
        # @param format [String] output format ("table", "json", "yaml", "wide")
        # @param color_flag [Boolean, nil] color flag from CLI
        # @param describe [Boolean] whether this is a describe command
        # @param context [Hash] additional context passed to presenter
        # @return [String] formatted output
        def render(data:, presenter:, format: "table", color_flag: nil, describe: false, **context)
          formatter = Registry.for(format)
          color_enabled = ColorSupport.enabled?(explicit_flag: color_flag)

          formatter.format(
            data,
            presenter,
            color_enabled: color_enabled,
            describe: describe,
            **context
          )
        end
      end
    end
  end
end
