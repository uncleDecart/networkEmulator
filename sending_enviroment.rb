require 'Qt4'
require 'singleton'

class SendingEnviroment
	
	include Singleton

	attr_reader :sending, :reciving, :dependences, :sending_delay

	@@Dependences_attr = Struct.new(:node, :connected_nodes)

	def initialize
		@senging_delay = 0	
		@sending = Queue.new
		@reciving = []
		@dependences = []
	end
	def set_sending_delay(sd)
		@sending_delay = sd.to_i
	end
	def connect_nodes(nodeA, nodeB)
		update_dependences(nodeA, nodeB)
		update_dependences(nodeB, nodeA)
		
	end
	def update_dependences(for_node, with_node)
		contains_node = false
		has_node_record = false

		@dependences.each do |dep|
			if dep.node == for_node
				has_node_record = true
				dep.connected_nodes.each do |node|
					if node == with_node
						contains_node = true
						break
					end
				end
				
				dep.connected_nodes << with_node unless contains_node
				break
			end
		end
		
		unless has_node_record || for_node.attributes.mac_address == nil	
			@dependences << @@Dependences_attr.new(for_node, [with_node])
		end
	end


	def process_sending
		block = @sending.pop
		temp = block.message
		@dependences.each do |dep|
			if dep.node == block.node
				dep.connected_nodes.reverse_each do |dev|
					dev.recive(temp.clone)
				end
			end
		end
	end

end

module Sending
	# Должны быть объявлен recive 
	
	@@Sending_attr = Struct.new(:node, :message)

	def send_to_env message
		se = SendingEnviroment.instance
		se.sending << @@Sending_attr.new(self, message)
		sleep(se.sending_delay)
		se.process_sending until se.sending.empty?
	end

end
