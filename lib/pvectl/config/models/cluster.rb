# frozen_string_literal: true

module Pvectl
  module Config
    module Models
      # Represents a Proxmox cluster server configuration.
      #
      # Cluster is an immutable value object containing connection settings
      # for a single Proxmox server. It stores the server URL, SSL options,
      # and retry/timeout configuration.
      #
      # @example Creating a cluster from constructor
      #   cluster = Cluster.new(
      #     name: "production",
      #     server: "https://pve.example.com:8006",
      #     verify_ssl: true,
      #     certificate_authority: "/path/to/ca.crt"
      #   )
      #
      # @example Creating from YAML config hash
      #   hash = {
      #     "name" => "production",
      #     "cluster" => {
      #       "server" => "https://pve.example.com:8006",
      #       "insecure-skip-tls-verify" => false
      #     }
      #   }
      #   cluster = Cluster.from_hash(hash)
      #
      class Cluster
        # @return [String] unique name identifying this cluster
        attr_reader :name

        # @return [String] Proxmox server URL (e.g., "https://pve.example.com:8006")
        attr_reader :server

        # @return [Boolean] whether to verify SSL certificates
        attr_reader :verify_ssl

        # @return [String, nil] path to CA certificate file
        attr_reader :certificate_authority

        # @return [Integer, nil] request timeout in seconds
        attr_reader :timeout

        # @return [Integer, nil] maximum retry attempts
        attr_reader :retry_count

        # @return [Integer, nil] base delay between retries in seconds
        attr_reader :retry_delay

        # @return [Integer, nil] maximum delay cap for exponential backoff
        attr_reader :max_retry_delay

        # @return [Boolean, nil] whether to retry write operations
        attr_reader :retry_writes

        # Creates a new Cluster instance.
        #
        # @param name [String] unique name for this cluster
        # @param server [String] Proxmox server URL
        # @param verify_ssl [Boolean] whether to verify SSL (default: true)
        # @param certificate_authority [String, nil] path to CA certificate
        # @param timeout [Integer, nil] request timeout in seconds
        # @param retry_count [Integer, nil] maximum retry attempts
        # @param retry_delay [Integer, nil] base delay between retries
        # @param max_retry_delay [Integer, nil] maximum delay cap
        # @param retry_writes [Boolean, nil] whether to retry write operations
        #
        # @raise [InvalidConfigError] if validation fails
        def initialize(name:, server:, verify_ssl: true, certificate_authority: nil,
                       timeout: nil, retry_count: nil, retry_delay: nil,
                       max_retry_delay: nil, retry_writes: nil)
          @name = name
          @server = server
          @verify_ssl = verify_ssl
          @certificate_authority = certificate_authority
          @timeout = timeout
          @retry_count = retry_count
          @retry_delay = retry_delay
          @max_retry_delay = max_retry_delay
          @retry_writes = retry_writes

          validate_retry_settings!
        end

        # Creates a Cluster from a kubeconfig-style hash structure.
        #
        # @param hash [Hash] hash with "name" and "cluster" keys
        # @return [Cluster] new cluster instance
        # @raise [InvalidConfigError] if validation fails
        #
        # @example Hash structure
        #   {
        #     "name" => "production",
        #     "cluster" => {
        #       "server" => "https://pve.example.com:8006",
        #       "insecure-skip-tls-verify" => true,
        #       "certificate-authority" => "/path/to/ca.crt"
        #     }
        #   }
        def self.from_hash(hash)
          cluster_data = hash["cluster"] || {}

          new(
            name: hash["name"],
            server: cluster_data["server"],
            verify_ssl: !cluster_data["insecure-skip-tls-verify"],
            certificate_authority: cluster_data["certificate-authority"],
            timeout: cluster_data["timeout"],
            retry_count: cluster_data["retry-count"],
            retry_delay: cluster_data["retry-delay"],
            max_retry_delay: cluster_data["max-retry-delay"],
            retry_writes: cluster_data["retry-writes"]
          )
        end

        # Converts the cluster to a kubeconfig-style hash structure.
        #
        # @return [Hash] hash representation suitable for YAML serialization
        def to_hash
          cluster_data = {
            "server" => server,
            "insecure-skip-tls-verify" => !verify_ssl
          }
          cluster_data["certificate-authority"] = certificate_authority if certificate_authority
          cluster_data["timeout"] = timeout if timeout
          cluster_data["retry-count"] = retry_count if retry_count
          cluster_data["retry-delay"] = retry_delay if retry_delay
          cluster_data["max-retry-delay"] = max_retry_delay if max_retry_delay
          cluster_data["retry-writes"] = retry_writes unless retry_writes.nil?

          {
            "name" => name,
            "cluster" => cluster_data
          }
        end

        private

        # Validates retry/timeout settings.
        #
        # @raise [InvalidConfigError] if values are invalid
        def validate_retry_settings!
          validate_positive(:timeout, @timeout) if @timeout
          validate_non_negative_integer(:retry_count, @retry_count) if @retry_count
          validate_positive(:retry_delay, @retry_delay) if @retry_delay
          validate_positive(:max_retry_delay, @max_retry_delay) if @max_retry_delay

          if @retry_delay && @max_retry_delay && @max_retry_delay < @retry_delay
            raise InvalidConfigError,
                  "max-retry-delay (#{@max_retry_delay}) must be >= retry-delay (#{@retry_delay})"
          end
        end

        # Validates that a value is a positive number.
        #
        # @param name [Symbol] attribute name for error message
        # @param value [Object] value to validate
        # @raise [InvalidConfigError] if value is not positive
        def validate_positive(name, value)
          return if value.is_a?(Numeric) && value.positive?

          raise InvalidConfigError, "#{name} must be a positive number, got: #{value.inspect}"
        end

        # Validates that a value is a non-negative integer.
        #
        # @param name [Symbol] attribute name for error message
        # @param value [Object] value to validate
        # @raise [InvalidConfigError] if value is not a non-negative integer
        def validate_non_negative_integer(name, value)
          return if value.is_a?(Integer) && value >= 0

          raise InvalidConfigError, "#{name} must be a non-negative integer, got: #{value.inspect}"
        end
      end
    end
  end
end
