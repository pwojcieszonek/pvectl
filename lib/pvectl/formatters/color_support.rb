# frozen_string_literal: true

module Pvectl
  module Formatters
    # Manages color output based on TTY detection and user flags.
    #
    # Implements color flag priority:
    # 1. --no-color flag (highest) -> disabled
    # 2. --color flag -> enabled
    # 3. NO_COLOR env var -> disabled (see https://no-color.org/)
    # 4. TTY detection (lowest) -> $stdout.tty?
    #
    # @example Check if colors are enabled
    #   ColorSupport.enabled?(explicit_flag: nil)   # TTY auto-detect
    #   ColorSupport.enabled?(explicit_flag: true)  # forced on
    #   ColorSupport.enabled?(explicit_flag: false) # forced off
    #
    # @example Get Pastel instance
    #   pastel = ColorSupport.pastel(explicit_flag: global_options[:color])
    #   puts pastel.green("Success!")
    #
    # @example Colorize status value
    #   pastel = ColorSupport.pastel(explicit_flag: true)
    #   ColorSupport.colorize_status("running", pastel) #=> "\e[32mrunning\e[0m"
    #
    module ColorSupport
      # Status color mapping following kubectl conventions.
      # @return [Hash<String, Symbol>] mapping of status to Pastel color method
      STATUS_COLORS = {
        "running" => :green,
        "stopped" => :red,
        "paused" => :yellow
      }.freeze

      class << self
        # Determines if color output should be enabled.
        #
        # Priority order:
        # 1. explicit_flag: false (--no-color) -> disabled
        # 2. explicit_flag: true (--color) -> enabled
        # 3. NO_COLOR env var present -> disabled
        # 4. TTY detection -> $stdout.tty?
        #
        # @param explicit_flag [Boolean, nil] value from --color / --no-color flag
        #   - true: --color was passed
        #   - false: --no-color was passed
        #   - nil: no flag passed, use auto-detection
        # @return [Boolean] true if colors should be used
        def enabled?(explicit_flag: nil)
          return false if explicit_flag == false
          return true if explicit_flag == true
          return false if ENV.key?("NO_COLOR")

          $stdout.tty?
        end

        # Returns a Pastel instance configured based on color settings.
        #
        # @param explicit_flag [Boolean, nil] value from --color / --no-color flag
        # @return [Pastel] pastel instance with appropriate enabled state
        #
        # @example
        #   pastel = ColorSupport.pastel(explicit_flag: true)
        #   pastel.green("text") #=> "\e[32mtext\e[0m"
        def pastel(explicit_flag: nil)
          require "pastel"
          Pastel.new(enabled: enabled?(explicit_flag: explicit_flag))
        end

        # Colors status text according to kubectl conventions.
        #
        # Status colors:
        # - running -> green
        # - stopped -> red
        # - paused -> yellow
        # - unknown status -> dim (gray)
        #
        # @param status [String, nil] status value
        # @param pastel_instance [Pastel] pastel instance
        # @return [String] colored text (or "-" if nil, or dim if unknown status)
        def colorize_status(status, pastel_instance)
          return "-" if status.nil?

          color = STATUS_COLORS[status.to_s.downcase]
          color ? pastel_instance.public_send(color, status) : pastel_instance.dim(status)
        end
      end
    end
  end
end
