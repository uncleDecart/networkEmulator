require_relative "node"
require "test/unit"

class TestPacketParser < Test::Unit::TestCase

	def test_connect_to
		nodeA = Node.new("0000:0000:0000:0001", 1)
		nodeB = Node.new("0000:0000:0000:0002", 0)
		nodeC = Node.new("0000:0000:0000:0003", 1)

		connect_nodes(nodeA, nodeB)
		connect_nodes(nodeB, nodeC)

		nodeA.connect_to(nodeB)
		nodeB.connect_to(nodeC)

		assert_equal(nodeA.connected_devices.first.mac_address,
								 nodeB.attributes.mac_address)
		assert_equal(nodeB.connected_devices.first.mac_address,
								 nodeA.attributes.mac_address)

		nodeA.send_message_to(nodeC, "YANKIES")
		assert_equal(nodeB.routes.first.from.mac_address,
								 nodeA.attributes.mac_address)
		nodeC.send_message_to(nodeA, "BAZINGA")
		assert_equal(nodeB.routes.first.to.mac_address,
							 	 nodeC.attributes.mac_address)
	 	nodeB.print_routes	

	end

end
