# frozen_string_literal: true

module Pvectl
  module Commands
    module Config
      # Handler for the `pvectl config set-context` command.
      #
      # Creates a new context or modifies an existing one in the configuration.
      # Requires --cluster and --user flags for new contexts.
      #
      # @example Usage
      #   pvectl config set-context production --cluster=pve-prod --user=admin
      #   pvectl config set-context dev --cluster=pve-dev --user=admin --default-node=pve1
      #
      class SetContext
        # Executes the set-context command.
        #
        # @param context_name [String] name of the context to create or modify
        # @param options [Hash] command options (:cluster, :user, :default_node)
        # @param global_options [Hash] global CLI options (includes :config)
        # @return [Integer] exit code (0 for success)
        # @raise [Config::ClusterNotFoundError] if cluster doesn't exist
        # @raise [Config::UserNotFoundError] if user doesn't exist
        def self.execute(context_name, options, global_options)
          config_path = global_options[:config]
          service = Pvectl::Config::Service.new
          service.load(config: config_path)

          existing_context = service.context(context_name)
          action = existing_context ? "modified" : "created"

          # Use existing values if not provided
          cluster = options[:cluster] || existing_context&.cluster_ref
          user = options[:user] || existing_context&.user_ref
          default_node = options[:"default-node"] || options[:default_node] || existing_context&.default_node

          # Validate required fields for new contexts
          if cluster.nil? || user.nil?
            $stderr.puts "Error: --cluster and --user are required for new contexts"
            return ExitCodes::USAGE_ERROR
          end

          # Validate cluster and user exist
          validate_cluster_exists!(service, cluster)
          validate_user_exists!(service, user)

          service.set_context(
            name: context_name,
            cluster: cluster,
            user: user,
            default_node: default_node
          )

          puts "Context \"#{context_name}\" #{action}."
          0
        rescue Pvectl::Config::ClusterNotFoundError => e
          $stderr.puts "Error: #{e.message}"
          ExitCodes::CONFIG_ERROR
        rescue Pvectl::Config::UserNotFoundError => e
          $stderr.puts "Error: #{e.message}"
          ExitCodes::CONFIG_ERROR
        end

        # Validates that the cluster exists in the configuration.
        #
        # @param service [Config::Service] configuration service
        # @param cluster_name [String] cluster name to validate
        # @raise [Config::ClusterNotFoundError] if cluster doesn't exist
        def self.validate_cluster_exists!(service, cluster_name)
          clusters = service.raw_config["clusters"] || []
          found = clusters.any? { |c| c["name"] == cluster_name }
          unless found
            available = clusters.map { |c| c["name"] }.join(", ")
            raise Pvectl::Config::ClusterNotFoundError,
                  "Cluster '#{cluster_name}' not found in configuration. Available: #{available}"
          end
        end

        # Validates that the user exists in the configuration.
        #
        # @param service [Config::Service] configuration service
        # @param user_name [String] user name to validate
        # @raise [Config::UserNotFoundError] if user doesn't exist
        def self.validate_user_exists!(service, user_name)
          users = service.raw_config["users"] || []
          found = users.any? { |u| u["name"] == user_name }
          unless found
            available = users.map { |u| u["name"] }.join(", ")
            raise Pvectl::Config::UserNotFoundError,
                  "User '#{user_name}' not found in configuration. Available: #{available}"
          end
        end
      end
    end
  end
end
