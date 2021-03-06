module Terraforming
  module Resource
    class NetworkInterface
      include Terraforming::Util

      def self.tf(ids: [], client: Aws::EC2::Client.new)
        self.new(client, ids).tf
      end

      def self.tfstate(ids: [], client: Aws::EC2::Client.new)
        self.new(client, ids).tfstate
      end

      def self.name(id, client: Aws::EC2::Client.new)
        self.new(client, []).name(id)
      end

      def initialize(client, ids)
        @client = client
        @ids = ids
      end

      def tf
        apply_template(@client, "tf/network_interface")
      end

      def tfstate
        network_interfaces.inject({}) do |resources, network_interface|
          attributes = {
            "attachment.#" => attachment_of(network_interface) ? "1" : "0",
            "id" => network_interface.network_interface_id,
            "private_ips.#" => private_ips_of(network_interface).length.to_s,
            "security_groups.#" => security_groups_of(network_interface).length.to_s,
            "source_dest_check" => network_interface.source_dest_check.to_s,
            "subnet_id" => network_interface.subnet_id,
            "tags.#" => network_interface.tag_set.length.to_s,
          }
          resources["aws_network_interface.#{module_name_of(network_interface)}"] = {
            "type" => "aws_network_interface",
            "primary" => {
              "id" => network_interface.network_interface_id,
              "attributes" => attributes
            }
          }

          resources
        end
      end

      def name(id)
        v = network_interfaces.select { |e| e.network_interface_id==id }
        if v.length > 0
          "${aws_network_interface.#{module_name_of(v[0])}.id}"
        else
          id
        end
      end

      private

      def attachment_of(network_interface)
        network_interface.attachment
      end

      def private_ips_of(network_interface)
        network_interface.private_ip_addresses.map { |addr| addr.private_ip_address }
      end

      def security_groups_of(network_interface)
        network_interface.groups.map { |group| group.group_id }
      end

      def module_name_of(network_interface)
        network_interface.network_interface_id
      end

      def network_interfaces
        return @client.describe_network_interfaces.map(&:network_interfaces).flatten if @ids.empty?
        @client.describe_network_interfaces.map(&:network_interfaces).flatten.select{ |e| @ids.include?(e.network_interface_id) }
      end
    end
  end
end
