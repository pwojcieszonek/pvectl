# frozen_string_literal: true

module Pvectl
  module Presenters
    # Presenter for Proxmox subscription records.
    #
    # Default table view masks the license key to avoid leaking it in shared
    # screenshots; the full key is only shown via `-o wide`, `-o json`, or
    # `-o yaml` so revealing it is an explicit user choice.
    #
    # @see Pvectl::Models::Subscription
    #
    class Subscription < Base
      # @return [Array<String>] standard column headers
      def columns
        %w[NODE LEVEL STATUS NEXTDUEDATE KEY]
      end

      # @return [Array<String>] extra column headers for wide output
      def extra_columns
        %w[PRODUCT REGDATE SERVERID]
      end

      # @param model [Models::Subscription]
      # @return [Array<String>]
      def to_row(model, **_context)
        @subscription = model
        [
          node_display,
          level_display,
          status_display,
          nextduedate_display,
          masked_key
        ]
      end

      # @param model [Models::Subscription]
      # @return [Array<String>]
      def extra_values(model, **_context)
        @subscription = model
        [
          product_display,
          regdate_display,
          serverid_display
        ]
      end

      # Wide row exposes the full key (after PRODUCT/REGDATE/SERVERID extras).
      # We replace the masked KEY column with the full one to make `-o wide`
      # useful for copying the license out without re-running with `-o json`.
      #
      # @param model [Models::Subscription]
      # @return [Array<String>]
      def to_wide_row(model, **context)
        row = to_row(model, **context).dup
        row[columns.index("KEY")] = full_key_display
        row + extra_values(model, **context)
      end

      # Hash representation for JSON/YAML output. Includes the full key —
      # JSON/YAML output is opt-in via `-o`, so the user already asked for
      # the raw data.
      #
      # @param model [Models::Subscription]
      # @return [Hash{String => Object}]
      def to_hash(model)
        @subscription = model
        {
          "node" => subscription.node,
          "status" => subscription.status,
          "level" => subscription.level,
          "product" => subscription.productname,
          "key" => subscription.key,
          "next_due_date" => subscription.nextduedate,
          "registration_date" => subscription.regdate,
          "checktime" => subscription.checktime,
          "server_id" => subscription.serverid,
          "sockets" => subscription.sockets,
          "url" => subscription.url,
          "message" => subscription.message
        }
      end

      # Description-style hash for `pvectl describe subscription` future use.
      #
      # @param model [Models::Subscription]
      # @return [Hash{String => Object}]
      def to_description(model)
        @subscription = model
        {
          "Node" => node_display,
          "Status" => status_display,
          "Level" => level_display,
          "Product" => product_display,
          "Key" => masked_key,
          "Next Due Date" => nextduedate_display,
          "Registration Date" => regdate_display,
          "Server ID" => serverid_display,
          "Sockets" => sockets_display,
          "Last Check" => checktime_display,
          "Message" => message_display
        }
      end

      # @return [String]
      def node_display
        subscription.node || "-"
      end

      # @return [String]
      def status_display
        subscription.status || "-"
      end

      # @return [String]
      def level_display
        subscription.level || "-"
      end

      # @return [String]
      def product_display
        subscription.productname || "-"
      end

      # @return [String]
      def regdate_display
        subscription.regdate || "-"
      end

      # @return [String]
      def serverid_display
        subscription.serverid || "-"
      end

      # @return [String]
      def nextduedate_display
        subscription.nextduedate || "-"
      end

      # @return [String]
      def sockets_display
        subscription.sockets ? subscription.sockets.to_s : "-"
      end

      # @return [String]
      def message_display
        subscription.message || "-"
      end

      # @return [String] formatted timestamp or "-"
      def checktime_display
        return "-" if subscription.checktime.nil? || subscription.checktime.to_i.zero?

        Time.at(subscription.checktime.to_i).utc.strftime("%Y-%m-%d %H:%M:%S UTC")
      end

      # Returns the license key with the middle masked.
      #
      # Proxmox keys look like `pveXp-1234567890` (16 chars). We preserve the
      # 6-char prefix (`pveXp-`) and the last 4 chars, masking the rest.
      # Returns "-" when no key is set (community node).
      #
      # @return [String]
      def masked_key
        key = subscription.key
        return "-" if key.nil? || key.empty?

        if key.length <= 6
          key
        elsif key.length <= 10
          "#{key[0, 4]}***#{key[-2..]}"
        else
          "#{key[0, 6]}****#{key[-4..]}"
        end
      end

      # @return [String] full key or "-"
      def full_key_display
        key = subscription.key
        key.nil? || key.empty? ? "-" : key
      end

      private

      # @return [Models::Subscription]
      attr_reader :subscription
    end
  end
end
