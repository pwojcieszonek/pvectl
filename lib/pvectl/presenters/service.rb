# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for systemd services on Proxmox nodes.
    #
    # Defines column layout and formatting for table output of node services.
    # Standard columns show node, name, state, active, enabled, description.
    # Wide adds the systemd unit identifier.
    #
    # @example Using with formatter
    #   presenter = Service.new
    #   formatter = Formatters::Table.new
    #   output = formatter.format(services, presenter)
    #
    # @see Pvectl::Models::Service Service model
    # @see Pvectl::Formatters::Table Table formatter
    #
    class Service < Base
      # Returns column headers for standard table output.
      #
      # @return [Array<String>] column headers
      def columns
        %w[NODE NAME STATE ACTIVE ENABLED DESCRIPTION]
      end

      # Returns additional column headers for wide output.
      #
      # @return [Array<String>] extra column headers
      def extra_columns
        %w[UNIT]
      end

      # Converts a Service model to table row values.
      #
      # @param model [Models::Service] Service model
      # @param context [Hash] optional context
      # @return [Array<String>] row values matching columns order
      def to_row(model, **_context)
        [
          model.node || "-",
          model.display_name || "-",
          model.state || "-",
          model.active_state || "-",
          model.unit_state || "-",
          model.desc || "-"
        ]
      end

      # Returns additional values for wide output.
      #
      # @param model [Models::Service] Service model
      # @param context [Hash] optional context
      # @return [Array<String>] extra values matching extra_columns order
      def extra_values(model, **_context)
        [model.service || "-"]
      end

      # Converts a Service model to hash for JSON/YAML output.
      #
      # @param model [Models::Service] Service model
      # @return [Hash{String => String?}] hash representation
      def to_hash(model)
        {
          "node" => model.node,
          "service" => model.service,
          "name" => model.name,
          "state" => model.state,
          "active_state" => model.active_state,
          "unit_state" => model.unit_state,
          "desc" => model.desc
        }
      end
    end
  end
end
