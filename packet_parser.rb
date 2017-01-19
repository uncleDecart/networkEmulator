module PacketParser

	attr_reader :recived_message, :from_mac, :recived_mac

	@@separator = '_'
	@@mac_exp = /\d{4}:\d{4}:\d{4}:\d{4}/
	
	@@connection_request_exp = /HELLO/
	@@connection_available_exp = /CONNECTION AVAILABLE/
	@@connection_confirmed_exp = /CONNECTION CONFIRMED/

	@@sending_exp = /SENDING/


	def parse_packet(packet)
		@to_whom_mac = packet.slice!(@@mac_exp)
		@recived_message = cut_dyn_len_var(packet)
		@from_whom_mac = packet.slice!(@@mac_exp)

	end

	def cut_dyn_len_var(packet)
		first = -1
		last = -1
		i = 0
		len = packet.length - 1
		
		while i < len && (first == -1 || last == -1)
			first = i + 1 if packet[i] == @@separator && first == -1
			last = len - i - 1 if packet[len - i] == @@separator && last == -1
			i += 1
		end
		
		return nil if first == -1 || last == -1
		
		res = packet[first .. last]
		packet.slice! first - 1 
		packet.slice! last 
		packet.slice! res
		
		res
	end

	def dyn_len_var(var)
		@@separator + var.to_s + @@separator unless var.to_s.length == 0
	end
	def form_packet(to_whom, message, from_whom)
		"#{to_whom}#{dyn_len_var(message)}#{from_whom}"
	end
end
