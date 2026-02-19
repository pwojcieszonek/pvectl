# frozen_string_literal: true

module Pvectl
  module Presenters
    module Config
      # Presenter for formatting context list output.
      #
      # Context presenter provides column definitions and row formatting
      # for displaying contexts in table, wide table, JSON, and YAML formats.
      # Inherits from Base to support unified output formatting.
      #
      # @example Using with OutputHelper
      #   presenter = Context.new
      #   OutputHelper.print(
      #     data: contexts,
      #     presenter: presenter,
      #     format: "table",
      #     current_context: "production"
      #   )
      #
      # @example Wide format includes DEFAULT-NODE column
      #   pvectl config get-contexts -o wide
      #   # CURRENT  NAME        CLUSTER  USER       DEFAULT-NODE
      #   # *        production  prod     admin@pam  pve1
      #
      class Context < Pvectl::Presenters::Base
        # Returns the column headers for table output.
        #
        # @return [Array<String>] column names
        def columns
          ["CURRENT", "NAME", "CLUSTER", "USER"]
        end

        # Returns additional columns for wide format.
        #
        # @return [Array<String>] extra column names
        def extra_columns
          ["DEFAULT-NODE"]
        end

        # Converts a context to a table row.
        #
        # @param context [Config::Models::Context] context to format
        # @param current_context [String, nil] name of the current context
        # @param context_kwargs [Hash] additional context (ignored)
        # @return [Array<String>] row values
        def to_row(context, current_context: nil, **context_kwargs)
          [
            context.name == current_context ? "*" : "",
            context.name,
            context.cluster_ref,
            context.user_ref
          ]
        end

        # Returns additional values for wide format.
        #
        # @param context [Config::Models::Context] context to format
        # @param context_kwargs [Hash] additional context (ignored)
        # @return [Array<String, nil>] extra values
        def extra_values(context, **context_kwargs)
          [context.default_node]
        end

        # Converts a context to a hash for JSON/YAML output.
        #
        # @param context [Config::Models::Context] context to format
        # @return [Hash] hash representation
        def to_hash(context)
          {
            "name" => context.name,
            "cluster" => context.cluster_ref,
            "user" => context.user_ref,
            "default_node" => context.default_node
          }
        end
      end
    end
  end
end
