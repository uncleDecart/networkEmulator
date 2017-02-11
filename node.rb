require 'Qt4'
require 'time'
require 'optparse'
require_relative "packet_parser"
require_relative "sending_enviroment"

# Сделать только функцию шифровки и так проверять
# Возможно дешифровка менее затратна по ресурсам 

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
#		СДЕЛАТЬ ОДНУ СТРУКТУРУ, В КОТОРОЙ БУДЕТ ХРАНИТСЯ ВСЁ(?)
#
#		Маршруты
#			Полудуплексное соединение
#			Дуплексное соединение
#			Естественный отбор пакетов
#				id для пакетов
#				принимаю только первый успешно прешедший
#		Периоды активности устройства

# Надо сделать легкозаменяемую "слоёную" структуру, чтобы
# если что можно было легко заменить любой компонент

$options = {}

OptionParser.new do |opt|
  opt.on("-d", "--debug") { |o| $options[:debug] = o }
	opt.on("-sd", "--sending-delay") { |o| $options[:sending_delay] = o}
end.parse!

class Node < Qt::Object

	include PacketParser
	include Sending
									  
	DEFAULT_MAC = "0000:0000:0000:0000"
	WIDE_MAC = "0000:0000:0000:0000" 
	
	signals 'state_changed(const QString&, const QString&)', 'push_text(const QString&)'
	slots 'recive(const QString&)'

	attr_reader :attributes, :recived_message, :connected_devices, :routes

	# Объединить эти структуры в одну?
	@@Attributes = Struct.new(:mac_address, :time)
	@@Route = Struct.new(:id, :from, :to) 
	@@Neighbour = Struct.new(:mac_address, :packet_count, :forwarding_confirmed) do
		def empty?
			(mac_address == WIDE_MAC)? true : false
		end
	end
		
	@@Nodes = []

	def initialize(mac = DEFAULT_MAC, key = 0, parent = nil)
		super parent
	
		@to_whom_mac = nil 
		@recived_message = nil 
		@from_whom_mac = nil 

		@attributes = @@Attributes.new mac, Time.new 
		@key = key

		@timing_table = []
		@connected_devices = [] 
		@routes = []

		@available_connection = true
		@requestConnection = false
		@waitForConfirmingConnection = false
		

		@@Nodes << self unless mac == nil 
	end
	
	def connect_to(node)
        unless connected?(node.attributes.mac_address)
			@requestConnection = true
			@timing_table << @@Attributes.new(node.attributes.mac_address, Time.now)	
			
			send_message(node.attributes.mac_address, 
												 @@connection_request_exp.source)
		end
	end
	def send_message_to(node, message)
		packet_key = form_packet_key(node)
		cur_route = find_route(packet_key)	
		if device_connected(node.attributes.mac_address)
			mac = node.attributes.mac_address
		elsif !cur_route.nil?
			mac = (cur_route.from.mac_address == @attributes.mac_address)?
			 	cur_route.to.mac_address : cur_route.from.mac_address 
		else
			mac = WIDE_MAC
		end
		unless cur_route.nil?
			direction = (cur_route.from.mac_address == @attributes.mac_address)?
			 						 cur_route.from : cur_route.to	
		end
		if cur_route.nil?
			@packet_count = 1
		else
			direction.packet_count += 1 unless direction.mac_address == WIDE_MAC
			@packet_count = direction.packet_count
		end
		update_routes(packet_key, @attributes.mac_address, @packet_count, true)
		tmp = dyn_len_var(packet_key.to_s + dyn_len_var(@packet_count))
		send_message(mac, (@@sending_exp.source + tmp + message))
	end
	def form_packet_key(nodeTo)
		@key
	end

	def recive(packet)
        emit state_changed(self.attributes.mac_address.to_s, "reciving")
        #sleep(0.5) # for graph mode
        parse_packet(packet)
		if @to_whom_mac == @attributes.mac_address || @to_whom_mac == WIDE_MAC 
			case @recived_message
				when @@connection_request_exp
                    unless connected?(@from_whom_mac)
                        @timing_table << @@Attributes.new(@from_whom_mac, Time.now)
                        @waitForConfirmingConnection = true
                        
                        if @available_connection
                            send_message(@from_whom_mac, @@connection_available_exp.source)
                        end
                    end
				when @@connection_available_exp
					connection_duration = calculate_connection_duration(@from_whom_mac) 
					if !device_connected @from_whom_mac && (@requestConnection) && 
						 !connection_duration.nil?
						@connected_devices << @@Attributes.new(@from_whom_mac, 
															   connection_duration) 
						send_message(@from_whom_mac, @@connection_confirmed_exp.source)
						@requestConnection = false
					end
				when @@connection_confirmed_exp
					connection_duration = calculate_connection_duration(@from_whom_mac) 
					if !device_connected @from_whom_mac && @waitForConfirmingConnection &&
					 	 !connection_duration.nil?
						@connected_devices << @@Attributes.new(@from_whom_mac, 
																connection_duration) 
						@waitForConfirmingConnection = false 
					end
				when @@sending_exp
					@message_key = cut_dyn_len_var(@recived_message)
					packet_count = cut_dyn_len_var(@message_key).to_i
					cur_route = find_route(@message_key.to_i)
					forwarding_mac = find_direction(cur_route).mac_address
					
					unless cur_route.nil?
						direction = (cur_route.from.mac_address == @attributes.mac_address)?
											 cur_route.from : cur_route.to
						
						if direction.packet_count == packet_count && 
							 !direction.forwarding_confirmed && 
							 direction.mac_address != WIDE_MAC #send deny? 
							return
						end
					end
					
					if (cur_route.nil? || direction.forwarding_confirmed == false) 
						update_routes(@message_key.to_i, @from_whom_mac, packet_count,false)
					end
				
					cur_route = find_route(@message_key.to_i)
					direction = (cur_route.from.mac_address == @attributes.mac_address)? 
											 cur_route.from : cur_route.to	
				
					@recived_message.slice!(@@sending_exp.source)
                    puts "AMIGO #{packet_count} cmp to #{direction.packet_count}"
					if	@message_key.to_i == @key && !direction.forwarding_confirmed &&
                        packet_count > direction.packet_count
                        
                        direction.forwarding_confirmed = true
						print "#{@attributes.mac_address} THATS FOR ME!"
						print @recived_message
						forward_message(@from_whom_mac, packet_count)
					else
						unless direction.forwarding_confirmed
							direction.forwarding_confirmed = true
							forward_message(forwarding_mac, packet_count)
						else
							direction.forwarding_confirmed = false 
						end
					end
			end
		elsif @@sending_exp.match(@recived_message)
			@message_key = cut_dyn_len_var(@recived_message)
			packet_count = cut_dyn_len_var(@message_key).to_i
			cur_route = find_route(@message_key.to_i)
			unless cur_route.nil?
				direction = (cur_route.from.mac_address == @attributes.mac_address)? 
										 cur_route.from : cur_route.to	
				if !direction.nil? && direction.forwarding_confirmed
					direction.forwarding_confirmed = false   
				end
			end																		  
		end
        emit state_changed(self.attributes.mac_address.to_s, "online")
	end	
	def self.elements
		@@Nodes
	end
	def print_connected_devices
		@connected_devices.each {|d| print d.to_s}
	end
	def print_routes
		@routes.each do |r| 
			print "from :#{r.from}"
			print "to   :#{r.to}"
		end
	end
	
	def to_s
		res = "Mac :  #{@attributes.mac_address}\n" + 
					"Devices :\n"
		@connected_devices.each {|d| res += d.to_s + "\n"}
		res += "Routes : \n"	
		
		@routes.each do |r| 
			res += "from :#{r.from}\n" + "to   :#{r.to}\n"
		end
		res
	end

protected 

	def send_message(to_whom, message)
		packet = form_packet(to_whom, message, @attributes.mac_address)
		print "#{Time.now.strftime "%H:%M:%S"}@sending:#{packet}"
        emit state_changed(self.attributes.mac_address.to_s, "sending")
		send_to_env(packet)
        emit state_changed(self.attributes.mac_address.to_s, "online")
	end
	
	def calculate_connection_duration(mac)
		return nil if @timing_table.empty?
		res = nil
		@timing_table.delete_if do |element|
  			if element.mac_address = mac
				res = Time.now.to_i - element.time.to_i  
    			true 
  				#break пробегает по всей таблице!!1 плохо, с брейком не удаляет!!1
			end
		end
		res
	end	

	def find_direction(route)
		unless route.nil?
			if (route.from.mac_address != @from_whom_mac && 
			 	 	route.from.mac_address != @attributes.mac_address) ||
				 	route.from.forwarding_confirmed
				route.from
			else
				route.to
			end
		else
			@@Neighbour.new(WIDE_MAC, 0, false)
		end
	end

	def forward_message(mac, packet_count)
		tmp = dyn_len_var(@message_key.to_s + dyn_len_var(packet_count))
		mes = @@sending_exp.source + tmp + @recived_message
		send_message(mac, mes)
	end
	def find_route(id)
		@routes.each do |route|
			return route if route.id == id
		end
		nil
	end
	def connected?(addr)
		return false if @connected_devices.empty?
		@connected_devices.each do |d|
			return true if d.mac_address == addr 
		end
		return false
	end
	def update_routes(key, mac, packet_count = 0, forwarding_confirmed = true)
		containsRoute = false
		@routes.each do |route|
			if route.id == key
				if route.from.empty?
					route.from = @@Neighbour.new
					neighbour = route.from
				elsif route.from.mac_address == mac
					neighbour = route.from
				else
					route.to = @@Neighbour.new
					neighbour = route.to
				end
				neighbour.mac_address = mac if neighbour.mac_address.nil?
				unless forwarding_confirmed.nil?
					neighbour.forwarding_confirmed = forwarding_confirmed
				end
				neighbour.packet_count = packet_count
				containsRoute = true
				break
			end
		end
		from = @@Neighbour.new(mac, packet_count, forwarding_confirmed)
		@routes << @@Route.new(key, from, @@Neighbour.new(WIDE_MAC, 0, false)) unless containsRoute
	end

	def device_connected(mac)
		@connected_devices.each do |device|
			return true if device.mac_address == mac	
		end	
		false	
	end

	def print(mes)
		puts mes.to_s if $options[:debug]
		emit push_text(mes.to_s)
	end

end

def connect_nodes(nodeA, nodeB)
	SendingEnviroment.instance.connect_nodes(nodeA, nodeB)
	#connect_nodes_signals(nodeA,nodeB) 
end
def connect_nodes_signals(nodeA, nodeB)
	Qt::Object.connect(nodeA, SIGNAL('send(const QString&)'),nodeB, 
										 SLOT('recive(const QString&)'))
	Qt::Object.connect(nodeB, SIGNAL('send(const QString&)'),nodeA, 
										 SLOT('recive(const QString&)'))
end


def print_stat
	Node.elements.each do |node|
		print("=" * 25 + "\n")
		print node.to_s
	end

end

