# frozen_string_literal: true

module Pvectl
  module Config
    module Models
      # Represents a context linking a cluster to a user.
      #
      # Context is an immutable value object that binds together a cluster
      # and user configuration, similar to kubectl contexts. It optionally
      # includes a default node for operations.
      #
      # @example Creating a context
      #   context = Context.new(
      #     name: "production",
      #     cluster_ref: "pve-prod",
      #     user_ref: "admin",
      #     default_node: "pve1"
      #   )
      #
      # @example Creating from YAML config hash
      #   hash = {
      #     "name" => "prod",
      #     "context" => {
      #       "cluster" => "production",
      #       "user" => "admin-prod",
      #       "default-node" => "pve1"
      #     }
      #   }
      #   context = Context.from_hash(hash)
      #
      class Context
        # @return [String] unique name identifying this context
        attr_reader :name

        # @return [String] reference to cluster name
        attr_reader :cluster_ref

        # @return [String] reference to user name
        attr_reader :user_ref

        # @return [String, nil] default node for operations
        attr_reader :default_node

        # Creates a new Context instance.
        #
        # @param name [String] unique name for this context
        # @param cluster_ref [String] name of the cluster to use
        # @param user_ref [String] name of the user to use
        # @param default_node [String, nil] optional default node
        def initialize(name:, cluster_ref:, user_ref:, default_node: nil)
          @name = name
          @cluster_ref = cluster_ref
          @user_ref = user_ref
          @default_node = default_node
        end

        # Creates a Context from a kubeconfig-style hash structure.
        #
        # @param hash [Hash] hash with "name" and "context" keys
        # @return [Context] new context instance
        #
        # @example Hash structure
        #   {
        #     "name" => "prod",
        #     "context" => {
        #       "cluster" => "production",
        #       "user" => "admin-prod",
        #       "default-node" => "pve1"
        #     }
        #   }
        def self.from_hash(hash)
          context_data = hash["context"] || {}

          new(
            name: hash["name"],
            cluster_ref: context_data["cluster"],
            user_ref: context_data["user"],
            default_node: context_data["default-node"]
          )
        end

        # Converts the context to a kubeconfig-style hash structure.
        #
        # @return [Hash] hash representation suitable for YAML serialization
        def to_hash
          context_data = {
            "cluster" => cluster_ref,
            "user" => user_ref
          }
          context_data["default-node"] = default_node if default_node

          {
            "name" => name,
            "context" => context_data
          }
        end
      end
    end
  end
end
