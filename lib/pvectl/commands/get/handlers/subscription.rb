# frozen_string_literal: true

module Pvectl
  module Commands
    module Get
      module Handlers
        # Handler for `pvectl get subscription`.
        #
        # Aggregates subscription records across cluster nodes via
        # Repositories::Subscription. Supports filtering to a single node
        # with `--node`.
        #
        # @see Pvectl::Repositories::Subscription
        # @see Pvectl::Presenters::Subscription
        #
        class Subscription
          include ResourceHandler

          # @param repository [Repositories::Subscription, nil]
          def initialize(repository: nil)
            @repository = repository
          end

          # @param node [String, nil] limit to a single node
          # @return [Array<Models::Subscription>]
          def list(node: nil, name: nil, args: [], storage: nil, **_options)
            repository.list(node: node)
          end

          # @return [Presenters::Subscription]
          def presenter
            Pvectl::Presenters::Subscription.new
          end

          # @param name [String] node name to describe
          # @return [Models::Subscription]
          # @raise [Pvectl::ResourceNotFoundError] when the record cannot be fetched
          def describe(name:, node: nil, args: [], vmid: nil)
            raise ArgumentError, "Invalid node name" if name.nil? || name.empty?

            record = repository.get(name)
            raise Pvectl::ResourceNotFoundError, "Subscription not found for node: #{name}" if record.nil?

            record
          end

          private

          def repository
            @repository ||= build_repository
          end

          def build_repository
            config_service = Pvectl::Config::Service.new
            config_service.load
            connection = Pvectl::Connection.new(config_service.current_config)
            Pvectl::Repositories::Subscription.new(connection)
          end
        end
      end
    end
  end
end

Pvectl::Commands::Get::ResourceRegistry.register(
  "subscription",
  Pvectl::Commands::Get::Handlers::Subscription,
  aliases: ["subscriptions", "sub"]
)
