require_relative "packet_parser"
require "test/unit"

class TestPacketParser < Test::Unit::TestCase
    
	include PacketParser	

	def test_dyn_len_var
		assert_equal(nil, dyn_len_var(""))
		
		input = "ABCD"
	 	ans = "#{@@separator}#{input}#{@@separator}"
		assert_equal(ans, dyn_len_var(input))
	end
	def test_cut_dyn_len_var
		
		packet = "adfadf"
		packet_copy = packet.clone
		ans = cut_dyn_len_var(packet)		
		assert_equal(nil, ans)
		assert_equal(packet_copy, packet)

		packet = "asdadf#{@@separator}"
		packet_copy = packet.clone
		ans = cut_dyn_len_var(packet)
		assert_equal(nil, ans)
		assert_equal(packet_copy, packet)

		packet = "#{@@separator}asdadf"
		packet_copy = packet.clone
		ans = cut_dyn_len_var(packet)
		assert_equal(nil, ans)
		assert_equal(packet_copy, packet)

		var = "lololo"
		mess = "asdadf"
		packet = "#{mess}#{dyn_len_var(var)}"
		packet_copy = packet.clone
		ans = cut_dyn_len_var(packet)
		assert_equal(var, ans)
		assert_equal(mess, packet)
		
		var = "lololo"
		mess = "asdadf"
		packet = "#{dyn_len_var(mess + dyn_len_var(var) )}"
		packet_copy = packet.clone
		expected = mess + dyn_len_var(var)
		ans = cut_dyn_len_var(packet)
		assert_equal(expected, ans)
		assert_equal("", packet)

		mes = "asd"
		expected = mes.clone
		n = 10
		n.times do
			mes = dyn_len_var(mes)
		end
		n.times do
			mes = cut_dyn_len_var(mes)
		end
		assert_equal(expected, mes)

	end

	def test_form_packet
		from_whom = "0000:0000:0000:0000"
		message = "MESSAGE"
		to_whom = "0000:0000:0000:0001"
		expected = "0000:0000:0000:0001_MESSAGE_0000:0000:0000:0000"
		assert_equal(expected, form_packet(to_whom, message, from_whom))
	end

	def test_parse_packet
		from_whom = "0000:0000:0000:0000"
		message = "MESSAGE"
		to_whom = "0000:0000:0000:0001"
		packet = form_packet(to_whom, message, from_whom)
		parse_packet(packet)
		assert_equal(to_whom, @to_whom_mac)
		assert_equal(message, @recived_message)
		assert_equal(from_whom, @from_whom_mac)
		assert_equal("", packet)
		
		from_whom = "0000:0000:0000:0000"
		var = "zozo"
		message = "MESSAGE#{dyn_len_var(var)}"
		to_whom = "0000:0000:0000:0001"
		packet = form_packet(to_whom, message, from_whom)
		parse_packet(packet)
		assert_equal(to_whom, @to_whom_mac)
		assert_equal(message, @recived_message)
		assert_equal(from_whom, @from_whom_mac)
		assert_equal("", packet)
	end

end

