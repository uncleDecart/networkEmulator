module PacketParser

	attr_reader :recived_message, :from_mac, :recived_mac

	@@separator = '_'
	@@mac_exp = /\d{4}:\d{4}:\d{4}:\d{4}/
	
	@@connection_request_exp = /HELLO/
	@@connection_available_exp = /CONNECTION AVAILABLE/
	@@connection_confirmed_exp = /CONNECTION CONFIRMED/

	@@sending_exp = /SENDING/


	def parsePacket packet
		@recived_mac = packet.slice! @@mac_exp
		@recived_message = cutDynamicLengthVariable packet
		@from_mac = packet.slice! @@mac_exp

	end

	def cutDynamicLengthVariable packet
		first = -1
		last = -1
		i = 0
		len = packet.length - 1
		while i < len and (first == -1 or last == -1)
			first = i + 1 if packet[i] == @@separator and first == -1
			last = len - i - 1 if packet[len - i] == @@separator and last == -1
			i += 1
		end
		return nil if first == -1 or last == -1
		
		res = packet[first .. last]
		packet.slice! first - 1 
		packet.slice! last 
		packet.slice! res
		
		return res
	end

	def dynamicLengthVariable var
		@@separator + var.to_s + @@separator unless var.to_s.length == 0
	end
	def formPacket toWhom, message
		return "#{toWhom}#{dynamicLengthVariable message}#{@attributes.mac_address}"
	end
end


