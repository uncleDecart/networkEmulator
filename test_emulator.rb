require_relative "emulator"
require "test/unit"

class TestPacketParser < Test::Unit::TestCase

	def test_connect_to
		nodeA = Node.new("0000:0000:0000:0001")
		nodeB = Node.new("0000:0000:0000:0002")

		connect_nodes(nodeA, nodeB)

		nodeB.connect_to(nodeA)

		assert_equal(nodeA.connected_devices.first.mac_address,
								 nodeB.attributes.mac_address)
		assert_equal(nodeB.connected_devices.first.mac_address,
								 nodeA.attributes.mac_address)

	end

end
