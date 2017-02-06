require "test/unit"
require_relative "test_packet_parser"
require_relative "node"

class TestPacketParser < Test::Unit::TestCase

	def test_sending
		
		nodeA = Node.new("0000:0000:0000:0001", 1)
		nodeB = Node.new("0000:0000:0000:0002", 0)
		nodeC = Node.new("0000:0000:0000:0003", 1)

		connect_nodes(nodeA, nodeB)
		connect_nodes(nodeB, nodeC)

		nodeA.connect_to(nodeB)
		nodeB.connect_to(nodeC)

		assert_equal(nodeB.attributes.mac_address,
								 nodeA.connected_devices.first.mac_address)
		assert_equal(nodeA.attributes.mac_address,
								 nodeB.connected_devices.first.mac_address)
		
		n = 4
		m = 3
		n.times do
			nodeA.send_message_to(nodeC, "YANKIES")
		end
		m.times do
			nodeC.send_message_to(nodeA, "BAZINGA")
		end

		assert_equal(nodeA.attributes.mac_address,
								 nodeB.routes.first.from.mac_address)
		assert_equal(nodeC.attributes.mac_address,
							 	 nodeB.routes.first.to.mac_address)
		
		assert_equal(m - 1, nodeB.routes.first.to.packet_count)
		assert_equal(n - 1, nodeB.routes.first.from.packet_count)

	end

end
