# frozen_string_literal: true

module Pvectl
  module Presenters
    # Shared metrics formatting for top command presenters.
    #
    # Provides common display methods for CPU cores, CPU usage percentage,
    # and generic percentage calculations used across TopNode, TopVm,
    # and TopContainer presenters.
    #
    # @example Including in a presenter
    #   class TopVm < Vm
    #     include TopPresenter
    #   end
    #
    module TopPresenter
      # Returns CPU core count for display.
      #
      # @param resource [Object] model with maxcpu attribute
      # @return [String] core count or "-" if unavailable
      def cpu_cores_value(resource)
        return "-" if resource.maxcpu.nil?

        resource.maxcpu.to_s
      end

      # Returns CPU usage as percentage string.
      #
      # @param resource [Object] model with cpu attribute (0.0-1.0 fraction)
      # @return [String] CPU percentage (e.g., "23%") or "-" if unavailable
      def cpu_usage_value(resource)
        return "-" if resource.cpu.nil?

        "#{(resource.cpu * 100).round}%"
      end

      # Returns percentage display string from used/total values.
      #
      # @param used [Numeric, nil] used amount
      # @param total [Numeric, nil] total amount
      # @return [String] percentage (e.g., "45%") or "-" if unavailable
      def percent_display(used, total)
        pct = percent_value(used, total)
        pct ? "#{pct}%" : "-"
      end

      # Calculates percentage as integer from used/total values.
      #
      # @param used [Numeric, nil] used amount
      # @param total [Numeric, nil] total amount
      # @return [Integer, nil] percentage or nil if unavailable
      def percent_value(used, total)
        return nil if used.nil? || total.nil? || total.zero?

        ((used.to_f / total) * 100).round
      end
    end
  end
end
