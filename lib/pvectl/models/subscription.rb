# frozen_string_literal: true

module Pvectl
  module Models
    # Represents a Proxmox subscription record for a specific node.
    #
    # Immutable value object created by Repositories::Subscription from the
    # `/nodes/{node}/subscription` API endpoint. One Subscription per node.
    #
    # For community (unlicensed) nodes the API still returns a record with
    # status="notfound" or similar; key/productname/etc. are nil in that case.
    #
    # @see Pvectl::Repositories::Subscription
    # @see Pvectl::Presenters::Subscription
    #
    class Subscription < Base
      # @return [String, nil] node this subscription belongs to
      attr_reader :node

      # @return [String, nil] subscription status (active, notfound, invalid, expired, ...)
      attr_reader :status

      # @return [String, nil] subscription level code (c, b, s, p)
      attr_reader :level

      # @return [String, nil] human-readable product name
      attr_reader :productname

      # @return [String, nil] subscription key (full, unmasked)
      attr_reader :key

      # @return [String, nil] next due date (ISO date string)
      attr_reader :nextduedate

      # @return [String, nil] registration date (ISO date string)
      attr_reader :regdate

      # @return [Integer, nil] last server check timestamp (epoch)
      attr_reader :checktime

      # @return [String, nil] server ID for license validation
      attr_reader :serverid

      # @return [Integer, nil] number of sockets covered
      attr_reader :sockets

      # @return [String, nil] URL to web shop
      attr_reader :url

      # @return [String, nil] signature for offline keys
      attr_reader :signature

      # @return [String, nil] human-readable status message
      attr_reader :message

      # Creates a Subscription value object.
      #
      # @param attrs [Hash] subscription attributes (symbol or string keys)
      def initialize(attrs = {})
        super
        @node = @attributes[:node]
        @status = @attributes[:status]
        @level = @attributes[:level]
        @productname = @attributes[:productname]
        @key = @attributes[:key]
        @nextduedate = @attributes[:nextduedate]
        @regdate = @attributes[:regdate]
        @checktime = @attributes[:checktime]
        @serverid = @attributes[:serverid]
        @sockets = @attributes[:sockets]
        @url = @attributes[:url]
        @signature = @attributes[:signature]
        @message = @attributes[:message]
      end

      # @return [Boolean] true if subscription is active
      def active?
        status == "active"
      end

      # @return [Boolean] true if the node has no subscription set
      def missing?
        status.nil? || status == "notfound" || status == "new"
      end
    end
  end
end
