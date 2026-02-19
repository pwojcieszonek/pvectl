# frozen_string_literal: true

module Pvectl
  module Commands
    # Handler for the `pvectl create container` command.
    #
    # Includes CreateResourceCommand for shared workflow and overrides
    # template methods with container-specific behavior.
    #
    # @example Flag-based creation
    #   pvectl create container --hostname web-ct --ostemplate local:vztmpl/debian-12.tar.zst \
    #     --rootfs storage=local-lvm,size=8G --cores 2 --memory 2048
    #
    class CreateContainer
      include CreateResourceCommand

      private

      # @return [String] human label for container resources
      def resource_label
        "container"
      end

      # @return [String] human label for container IDs
      def resource_id_label
        "CTID"
      end

      # @return [Boolean] true if --hostname is missing
      def required_params_missing?
        !@options[:hostname]
      end

      # @return [Object] container creation wizard
      def build_wizard
        Pvectl::Wizards::CreateContainer.new(@options, @global_options)
      end

      # @param connection [Connection] API connection
      # @param task_repo [Repositories::Task] task repository
      # @return [Services::CreateContainer] container creation service
      def build_create_service(connection, task_repo)
        ct_repo = Pvectl::Repositories::Container.new(connection)
        Pvectl::Services::CreateContainer.new(
          container_repository: ct_repo,
          task_repository: task_repo,
          options: service_options
        )
      end

      # @param result [Models::ContainerOperationResult] operation result
      # @return [void]
      def output_result(result)
        presenter = Pvectl::Presenters::ContainerOperationResult.new
        format = @global_options[:output] || "table"
        color_flag = @global_options[:color]

        formatter = Pvectl::Formatters::Registry.for(format)
        output = formatter.format([result], presenter, color: color_flag)
        puts output
      end

      # Validates flags and performs flag-based creation.
      #
      # @return [Integer] exit code
      def perform_create
        return usage_error("--hostname is required") unless @options[:hostname]
        return usage_error("--ostemplate is required") unless @options[:ostemplate]
        return usage_error("--rootfs is required") unless @options[:rootfs]

        super
      end

      # @return [Hash] parameters built from CLI flags
      def build_params_from_flags
        params = {
          hostname: @options[:hostname],
          node: @options[:node] || resolve_default_node,
          ostemplate: @options[:ostemplate],
          cores: @options[:cores],
          memory: @options[:memory],
          swap: @options[:swap],
          description: @options[:description],
          tags: @options[:tags],
          pool: @options[:pool],
          features: @options[:features],
          password: @options[:password],
          ssh_public_keys: @options[:"ssh-public-keys"],
          onboot: @options[:onboot],
          startup: @options[:startup]
        }

        ctid = @args.first
        params[:ctid] = ctid.to_i if ctid

        params[:rootfs] = Parsers::LxcMountConfig.parse(@options[:rootfs]) if @options[:rootfs]
        params[:mountpoints] = parse_mountpoints if @options[:mp]
        params[:nets] = parse_nets if @options[:net]
        params[:privileged] = true if @options[:privileged]

        params.compact
      end

      # @param params [Hash] container creation parameters
      # @return [void]
      def display_resource_summary(params)
        $stdout.puts "  Hostname:  #{params[:hostname]}"
        $stdout.puts "  Node:      #{params[:node] || '(from context)'}"
        $stdout.puts "  Template:  #{truncate_template(params[:ostemplate])}"
        $stdout.puts "  CPU:       #{params[:cores] || 1} cores" if params[:cores]
        $stdout.puts "  Memory:    #{params[:memory] || 512} MB"
        $stdout.puts "  Swap:      #{params[:swap] || 512} MB"

        if params[:rootfs]
          $stdout.puts "  Root FS:   #{params[:rootfs][:storage]}, #{params[:rootfs][:size]}"
        end

        if params[:mountpoints]
          params[:mountpoints].each_with_index do |mp, i|
            $stdout.puts "  Mount#{i}:    #{mp[:storage]}, #{mp[:size]} -> #{mp[:mp]}"
          end
        end

        if params[:nets]
          params[:nets].each_with_index do |net, i|
            ip_info = net[:ip] ? ", #{net[:ip]}" : ""
            $stdout.puts "  Net#{i}:      #{net[:bridge]}, #{net[:name] || 'eth0'}#{ip_info}"
          end
        end

        $stdout.puts "  Unpriv:    #{params[:privileged] ? 'No' : 'Yes'}"
        $stdout.puts "  Features:  #{params[:features]}" if params[:features]
        $stdout.puts "  Tags:      #{params[:tags]}" if params[:tags]
        $stdout.puts "  Pool:      #{params[:pool]}" if params[:pool]
      end

      # Parses mountpoint configuration strings.
      #
      # @return [Array<Hash>] parsed mountpoint configurations
      def parse_mountpoints
        Array(@options[:mp]).map { |m| Parsers::LxcMountConfig.parse(m) }
      end

      # Parses LXC network configuration strings.
      #
      # @return [Array<Hash>] parsed network configurations
      def parse_nets
        Array(@options[:net]).map { |n| Parsers::LxcNetConfig.parse(n) }
      end

      # Truncates long template paths for display.
      #
      # @param template [String] full template path
      # @return [String] truncated template name
      def truncate_template(template)
        return template unless template

        parts = template.split("/")
        parts.last || template
      end
    end
  end
end
