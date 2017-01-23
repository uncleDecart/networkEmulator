require 'Qt4'
require 'time'
require 'optparse'
require_relative "packet_parser"

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
									  
	DEFAULT_MAC = "0000:0000:0000:0000"
	WIDE_MAC = "0000:0000:0000:0000" 
	
	signals 'send(const QString&)'
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
		@requestConnection = true
		@timing_table << @@Attributes.new(node.attributes.mac_address, Time.now)	
		
		send_message(node.attributes.mac_address, @@connection_request_exp.source)
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
			#puts "CUR_ROUTE"
			#puts "from :#{cur_route.from}"
			#puts "to   :#{cur_route.to}"
			direction = (cur_route.from.mac_address == @attributes.mac_address)? cur_route.from : cur_route.to	
			#puts "direction #{direction}" unless direction.nil?
		end
		@packet_count = (cur_route.nil?)? 0 : direction.packet_count
		update_routes(packet_key, @attributes.mac_address, @packet_count, true)
		tmp = dyn_len_var(packet_key.to_s + dyn_len_var(@packet_count))
		send_message(mac, (@@sending_exp.source + tmp + message))
	end
	# Всегда формируем ключ пакета по ноде, которой передаём  
	def form_packet_key(nodeTo)
		@key
	end

	def recive(packet)
		parse_packet(packet)
		if @to_whom_mac == @attributes.mac_address || @to_whom_mac == WIDE_MAC 
			case @recived_message
				when @@connection_request_exp
					@timing_table << @@Attributes.new(@from_whom_mac, Time.now)
					@waitForConfirmingConnection = true
					
					if @available_connection
						send_message(@from_whom_mac, @@connection_available_exp.source)
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
					# Второй уровень обработки
					@message_key = cut_dyn_len_var(@recived_message)
					@packet_count = cut_dyn_len_var(@message_key).to_i
					cur_route = find_route(@message_key.to_i)
					forwarding_mac = find_direction(cur_route).mac_address
					
					if cur_route.nil? || cur_route.from.forwarding_confirmed == false
						update_routes(@message_key.to_i, @from_whom_mac, @packet_count, false)
					end
					
					cur_route = find_route(@message_key.to_i)
					#direction = find_direction(cur_route)
					direction = (cur_route.from.mac_address == @attributes.mac_address)? 
											 cur_route.from : cur_route.to	
					#puts "#{@attributes.mac_address}"
					#puts "have directions"
					#puts "from :#{cur_route.from}"
					#puts "to   :#{cur_route.to}"
					#puts "find"
					#puts direction
					direction.packet_count += 1 if direction.forwarding_confirmed
					
					@recived_message.slice!(@@sending_exp.source)
					if  @message_key.to_i == @key && !cur_route.from.forwarding_confirmed
						if $options[:debug]
							#puts "#{@attributes.mac_address} THATS FOR ME!"
							#puts @recived_message
						end
						cur_route.from.forwarding_confirmed = false
						forward_message(@from_whom_mac)
					else
						unless cur_route.from.forwarding_confirmed
							#cur_route - указатель на элемент @routes
							cur_route.from.forwarding_confirmed = true
							forward_message(forwarding_mac)
						else
							cur_route.from.forwarding_confirmed = false 
						end
					end
			end
		elsif @@sending_exp.match(@recived_message)
			@message_key = cut_dyn_len_var(@recived_message)
			@packet_count = cut_dyn_len_var(@message_key).to_i
			cur_route = find_route(@message_key.to_i)
			unless cur_route.nil?
				direction = (cur_route.from.mac_address == @attributes.mac_address)? 
										 cur_route.from : cur_route.to	
				if !direction.nil? && direction.forwarding_confirmed
					direction.packet_count += 1 if direction.forwarding_confirmed
					direction.forwarding_confirmed = false   
					#puts "#{@attributes.mac_address}"
					#puts "have directions (packet not for me)"
					#puts "from :#{cur_route.from}"
					#puts "to   :#{cur_route.to}"
					#puts "find"
					#puts direction
				end
			end																		  
		end
	end	
	def self.elements
		@@Nodes
	end
	def print_connected_devices
		@connected_devices.each {|d| puts d.to_s}
	end
	def print_routes
		@routes.each do |r| 
			puts "from :#{r.from}"
			puts "to   :#{r.to}"
		end
	end
	
	protected 

	def send_message(to_whom, message)
		packet = form_packet(to_whom, message, @attributes.mac_address)
		puts "#{Time.now.strftime "%H:%M:%S"}@sending:#{packet}" if $options[:debug]
	  sleep($options[:sending_delay].to_i)	
		emit send(packet) 
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

	def forward_message(mac)
		tmp = dyn_len_var(@message_key.to_s + dyn_len_var(@packet_count))
		mes = @@sending_exp.source + tmp + @recived_message
		send_message(mac, mes)
	end
	def find_route(id)
		@routes.each do |route|
			return route if route.id == id
		end
		nil
	end
	def update_routes(key, mac, packet_count = 0, forwarding_confirmed = true)
		containsRoute = false
		@routes.each do |route|
			if route.id == key
				#return unless route.from.empty? || route.to.empty?
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

end

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
