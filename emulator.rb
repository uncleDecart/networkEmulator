require_relative "node"

def connect_nodes(nodeA, nodeB)
	Qt::Object.connect(nodeA, SIGNAL('send(const QString&)'),nodeB, 
										 SLOT('recive(const QString&)'))
	Qt::Object.connect(nodeB, SIGNAL('send(const QString&)'),nodeA, 
										 SLOT('recive(const QString&)'))
end

def print_stat
	Node.elements.each do |node|
		puts "=" * 25
		puts "Mac :  #{node.attributes.mac_address}"
		puts "Devices : "
		node.print_connected_devices
		puts "Routes : "
		node.print_routes
	end
end

observer = Observer.new

#СМОТРИ ЗА КЛЮЧАМИ
nodeA = Node.new("0000:0000:0000:0001", 1) 
nodeB = Node.new("0000:0000:0000:0002", 0)
nodeC = Node.new("0000:0000:0000:0003", 1)
#nodeD = Node.new("0000:0000:0000:0004", 0)

Node.elements.each do |node|
	connect_nodes(node, observer) 
end

connect_nodes(nodeA, nodeB)
connect_nodes(nodeB, nodeC)
#connect_nodes(nodeC, nodeD)

nodeA.connect_to(nodeB)
nodeB.connect_to(nodeC)
#nodeC.connect_to(nodeD)

#nodeA.send_message_to(nodeC, "YANKIES")
nodeA.send_message_to(nodeC, "HORNETS")
nodeA.send_message_to(nodeC, "HORNETS")
nodeA.send_message_to(nodeC, "HORNETS")
nodeA.send_message_to(nodeC, "HORNETS")
nodeA.send_message_to(nodeC, "HORNETS")
nodeC.send_message_to(nodeA, "BAZINGA")
nodeC.send_message_to(nodeA, "BAZINGA")
nodeC.send_message_to(nodeA, "BAZINGA")
nodeC.send_message_to(nodeA, "BAZINGA")
nodeC.send_message_to(nodeA, "BAZINGA")

if $options[:debug]

	#nodeB.print_routes
	print_stat

	#puts "Observer stat"
	#observer.table.each do |element|
	#	puts element
	#end

end
