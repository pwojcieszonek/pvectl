# frozen_string_literal: true

module Pvectl
  module Commands
    module Config
      # Handler for the `pvectl config set-cluster` command.
      #
      # Creates a new cluster or modifies an existing one in the configuration.
      # Requires --server flag for new clusters.
      #
      # @example Usage
      #   pvectl config set-cluster staging --server=https://pve-staging.example.com:8006
      #   pvectl config set-cluster prod --server=https://pve.example.com:8006 --certificate-authority=/path/to/ca.crt
      #   pvectl config set-cluster dev --server=https://pve-dev.local:8006 --insecure-skip-tls-verify
      #
      class SetCluster
        # Executes the set-cluster command.
        #
        # @param cluster_name [String] name of the cluster to create or modify
        # @param options [Hash] command options (:server, :certificate_authority, :insecure_skip_tls_verify)
        # @param global_options [Hash] global CLI options (includes :config)
        # @return [Integer] exit code (0 for success)
        def self.execute(cluster_name, options, global_options)
          config_path = global_options[:config]
          service = Pvectl::Config::Service.new
          service.load(config: config_path)

          existing_cluster = service.cluster(cluster_name)
          action = existing_cluster ? "modified" : "created"

          # Use existing values if not provided
          server = options[:server] || existing_cluster&.server
          certificate_authority = options[:"certificate-authority"] ||
                                  options[:certificate_authority] ||
                                  existing_cluster&.certificate_authority

          # Handle insecure-skip-tls-verify flag
          insecure_skip = options[:"insecure-skip-tls-verify"]
          verify_ssl = if insecure_skip.nil?
                         existing_cluster ? existing_cluster.verify_ssl : true
                       else
                         !insecure_skip
                       end

          # Validate required fields for new clusters
          if server.nil?
            $stderr.puts "Error: --server is required for new clusters"
            return ExitCodes::USAGE_ERROR
          end

          service.set_cluster(
            name: cluster_name,
            server: server,
            verify_ssl: verify_ssl,
            certificate_authority: certificate_authority
          )

          puts "Cluster \"#{cluster_name}\" #{action}."
          0
        end
      end
    end
  end
end
