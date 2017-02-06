require_relative "node"

class Observer < Node

	attr_reader :table

	@@ObserverAttr = Struct.new(:mac_address, :amount_of_messages,
														 	:total_message_len)
	
	def initialize
		super nil, nil
		@table = []
	end

	def recive(packet)
		len = packet.length 
		parse_packet(packet)
		match = find(@from_whom_mac)
		if match.nil? then
			@table << @@ObserverAttr.new(@from_whom_mac, 1, len)
		else
			match.amount_of_messages += 1
			match.total_message_len += len
		end
	end

	private

	def find(mac)
		unless @table.empty?
			@table.each do |element|
				return element if element.mac_address == mac
			end
		end
		nil
	end

end

def setup_emulator
	
	@observer = Observer.new
	
	#СМОТРИ ЗА КЛЮЧАМИ
	@nodeA = Node.new("0000:0000:0000:0001", 1) 
	@nodeB = Node.new("0000:0000:0000:0002", 0)
	@nodeC = Node.new("0000:0000:0000:0003", 0)
	@nodeD = Node.new("0000:0000:0000:0004", 1)
	#@nodeE = Node.new("0000:0000:0000:0005", 1)

	Node.elements.each do |node|
		connect_nodes(node, @observer) 
	end

	connect_nodes(@nodeA, @nodeB)
	connect_nodes(@nodeB, @nodeC)
	connect_nodes(@nodeC, @nodeD)
	#connect_nodes(@nodeD, @nodeE)

end

def run_emulation

	@nodeA.connect_to(@nodeB)
	@nodeB.connect_to(@nodeC)
	@nodeC.connect_to(@nodeD)
	#@nodeD.connect_to(@nodeE)

	3.times do
		@nodeA.send_message_to(@nodeD, "HORNETS")
		@nodeD.send_message_to(@nodeA, "BAZINGA")
	end
	print_stat

end
