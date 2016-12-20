require 'Qt4'
require 'time'
require_relative "packetParser"

# При connection request передаем радиус. По сути он не нужен
# Но единство пакетов 

# Сделать только функцию шифровки и так проверять
# Возможно дешифровка менее затратна по ресурсам 

#Сделать таблицу подключений 
#Организовано все должно быть итеративным путем
#т.е. проходим по каждой ноде и включаем и выключаем
#её. 
#Посмотреть GNU GPL
#
#Таблица подключений
#	Согласование часов КРИТИЧНО ПРИНИМАЕМ, ЧТО ЧАСЫ У ВСЕХ СОГЛАСОВАНЫ
#		Критичность длительности передачи. 
#		Если у нас длина передачи 1мс, а работа устройства 2мс. То при 
#		установлении времени пакет задержится на 1мс, и следовательно
#		отожрёт эт
#
#
#		ФАКАП С ФЛАГОМ waitForRecivingPacket


class Node < Qt::Object

	include PacketParser
									  
	DEFAULT_MAC = "0000:0000:0000:0000"
	WIDE_MAC = "0000:0000:0000:0000" 
	DEFAULT_RADUIS = 0
	
	signals 'send(const QString&)'
	slots 'recive(const QString&)'

	attr_reader :attributes, :recived_message

	@@Attributes = Struct.new(:mac_address, :time)
	@@Route = Struct.new(:id, :mac_address)

	@@Nodes = []

	@@PacketsAmount = 0


	def initialize(mac = DEFAULT_MAC, parent = nil)
		super parent

		@attributes = @@Attributes.new mac, Time.new 

		@timing_table = Array.new
		@connected_devices = Array.new
		@routes = Array.new
		@sendedPackets = Array.new

		@availableConnection = true
		@requestConnection = false
		@waitForRecivingPacket = true
		@waitForConfirmingConnection = false
		
		@@Nodes << self unless mac == nil
	end
	
	def self.elements
		@@Nodes
	end
	
	def connectTo node
		@requestConnection = true
		@timing_table << @@Attributes.new(node.attributes.mac_address, Time.now)	
		sendMessage node.attributes.mac_address, @@connection_request_exp.to_s
	end
	def sendMessageTo node, message
		if deviceConnected node.attributes.mac_address
			mac = node.attributes.mac_address
		else
			mac = WIDE_MAC
		end
		packetKey = dynamicLengthVariable formPacketKey(node)
		sendMessage mac, (@@sending_exp.to_s + packetKey + message)
	end
	# Всегда формируем ключ пакета по ноде, которой передаём  
	def formPacketKey nodeTo
		return nodeTo.attributes.mac_address.tr(':', '').to_i
	end

	def decodeKey key
		res = key.to_s
	   	(16 - res.length).times do
			res.prepend('0')
		end
		3.times do |i|
			res.insert(4 + 5 * i, ':')
		end
		return res
	end

	def recive packet
		#puts "recived : #{packet}"
		
		#Плохо реализован parsePacket
		#возможно реализовать пакет, в котором
		#фиксировано кол-во битов для разных полей
		#но как быть с переменными динамической длины
		parsePacket packet
		if (@recived_mac == @attributes.mac_address) or (@recived_mac == DEFAULT_MAC)
			case @recived_message
				when @@connection_request_exp
					@timing_table << @@Attributes.new(@from_mac, Time.now)
					@waitForConfirmingConnection = true
					sendMessage @from_mac, @@connection_available_exp.to_s if @availableConnection
				when @@connection_available_exp
					connection_duration = calculateConnectionDuration @from_mac 
					if !deviceConnected @from_mac and (@requestConnection) and !connection_duration.nil?
						@connected_devices << @@Attributes.new(@from_mac, connection_duration) 
						sendMessage @from_mac, @@connection_confirmed_exp.to_s
						@requestConnection = false
					end
				when @@connection_confirmed_exp
					connection_duration = calculateConnectionDuration @from_mac 
					if !deviceConnected @from_mac and @waitForConfirmingConnection and !connection_duration.nil?
						@connected_devices << @@Attributes.new(@from_mac, connection_duration) 
						@waitForConfirmingConnection = false 
					end
				when @@sending_exp
					@recived_message.slice! @@sending_exp.to_s
					# Второй уровень обработки 
					@message_key = cutDynamicLengthVariable @recived_message
					if @waitForRecivingPacket
						if  (@message_key.to_i) == (formPacketKey(self).to_i)
							updateRoutes
							puts "THATS FOR ME! #{decodeKey @message_key} == #{self.attributes.mac_address}"
							puts @recived_message
						else
							@waitForRecivingPacket = false
							forwardMessage
						end
					else
						@waitForRecivingPacket = true	
					end
				else 
					#puts "ILLEGAL"
			end
		end
	end	

	def printMessage
		puts "recived message : #{@recived_message}" 
	end

	def printConnectedDevices
		@connected_devices.each {|d| puts d.to_s}
	end
	def printRoutes
		@routes.each {|r| puts r.to_s}
	end
	
	protected 

	def sendMessage toWhom, message
		packet = formPacket toWhom, message
		puts "#{Time.now.strftime "%H:%M:%S"} @ sending : #{packet}"
	   	#sleep(1)	
		emit send packet 
	end

	def calculateConnectionDuration mac
		return nil if @timing_table.empty?
		res = nil
		@timing_table.delete_if do |element|
  			if element.mac_address = mac
				res = (Time.now.to_i - element.time.to_i)  
    			true 
  				#break пробегает по всей таблице!!1 плохо, с брейком не удаляет!!1
			end
		end
		return res
	end	
	
	def forwardMessage
		#routeMac = findRoute @message_key.to_i
		#updateRoutes
		routeMac = WIDE_MAC
		sendMessage routeMac, (@@sending_exp.to_s + dynamicLengthVariable(@message_key) + @recived_message)
	end
	def findRoute id
		@routes.each do |route|
			return route.mac_address if route.id == id
		end
		return WIDE_MAC
	end
	def updateRoutes
		containsRoute = false
		@routes.each do |route|
			if route.id == @message_key.to_i
				route.mac_address = @from_mac
				containsRoute = true
				break
			end
		end
		@routes << @@Route.new(@message_key.to_i, @from_mac) unless containsRoute
	end

	def deviceConnected mac
		@connected_devices.each do |device|
			return true if device.mac_address == mac	
		end	
		return false	
	end

	def packetSendConfirmation
		res = false
		@sendedPackets.delete_if do |element|
			if element == @from_mac
				res = true  
				true 
				#break пробегает по всей таблице!!1 плохо, с брейком не удаляет!!1
			end
		end
		return res
	end

end

class Observer < Node

	attr_reader :table

	@@ObserverAttr = Struct.new(:mac_address, :amount_of_messages, :total_message_len)
	
	def initialize
		super nil, nil
		@table = []
	end

	def recive packet
		len = packet.length 
		parsePacket packet
		match = find @from_mac
		if match == nil then
			@table << @@ObserverAttr.new(@from_mac, 1, len)
		else
			match.amount_of_messages += 1
			match.total_message_len += len
		end
	end

	private

	def find mac
		unless @table.empty?
			@table.each do |element|
				return element if element.mac_address == mac
			end
		end
		return nil
	end

end


def connect_nodes nodeA, nodeB
	Qt::Object.connect(nodeA, SIGNAL('send(const QString&)'),nodeB, SLOT('recive(const QString&)'))
	Qt::Object.connect(nodeB, SIGNAL('send(const QString&)'),nodeA, SLOT('recive(const QString&)'))
end

def printStat
	Node.elements.each do |node|
		puts "=" * 25
		puts "Mac :  #{node.attributes.mac_address}"
		puts "Devices : "
		node.printConnectedDevices
		puts "Routes : "
		node.printRoutes
		puts "=" * 25
	end
end

observer = Observer.new

nodeA = Node.new "0000:0000:0000:0001" 
nodeB = Node.new "0000:0000:0000:0002"
nodeC = Node.new "0000:0000:0000:0003"
nodeD = Node.new "0000:0000:0000:0004"

Node.elements.each do |node|
	connect_nodes node, observer 
end

connect_nodes nodeA, nodeB
connect_nodes nodeB, nodeC
connect_nodes nodeC, nodeD

nodeA.connectTo nodeB
nodeB.connectTo nodeC
nodeC.connectTo nodeD

nodeA.sendMessageTo nodeC, "YANKIES"
nodeC.sendMessageTo nodeA, "BAZINGA"

#printStat

puts "Observer stat"
observer.table.each do |element|
	puts element
end

