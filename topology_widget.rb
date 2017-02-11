require 'Qt'
require_relative 'node'
require_relative 'sending_enviroment'

class NodeRepresentation
	attr_accessor :x, :y, :node_addr, :color
	
	def initialize(*args)
		@x,@y, @node_addr, @color = args
	end
end

PANEL_HEIGHT = 450
PANEL_WIDTH = 650

class TopologyWidget < Qt::Widget 

	signals 'node_changed(const QString &)'
	slots 'node_reciving()', 'change_node_state(const QString&, const QString&)'

	def initialize(parent) 
			super(parent)
			
			@NodesCoordinates = []		

			@@online_color = Qt::Color.new 0, 103, 51
			@@sending_color = Qt::Color.new 255, 185, 199
            @@reciving_color = Qt::Color.new 255, 255, 184
            @@colors = {"online" => @@online_color,
                        "sending" => @@sending_color,
                        "reciving" => @@reciving_color}

			@line_color = Qt::Color.new 0, 0, 0

			@parent = parent

			@node_radius = 60
			@space = 15
			
			set_geometry(0, PANEL_HEIGHT/2)
			
			setMinimumHeight PANEL_HEIGHT
			setMinimumWidth PANEL_WIDTH
	end
	
	def paintEvent event

			painter = Qt::Painter.new self
			
			drawWidget painter
			painter.end
	end

	def drawWidget painter
		painter.setPen @line_color
		painter.setBrush Qt::Brush.new @line_color
		unless @NodesCoordinates.nil? 
			SendingEnviroment.instance.dependences.each do |dep|
				dep_coords = get_coords(dep.node)
				dep.connected_nodes.each do |cn|
					unless get_coords(cn) == nil
						painter.drawLine(dep_coords.x + @node_radius/2, 
										 dep_coords.y + @node_radius/2,
										 get_coords(cn).x + @node_radius/2,
										 get_coords(cn).y + @node_radius/2)
					end
				end
			end	
			
			@NodesCoordinates.each do |coord|
                painter.setPen coord.color 
                painter.setBrush Qt::Brush.new coord.color 
				painter.drawEllipse  coord.x, coord.y, @node_radius, @node_radius
			end
			
		end
	end
	def get_coords(node)
		@NodesCoordinates.each do |c|
			return c if c.node_addr.attributes.mac_address == node.attributes.mac_address 
		end	
		return nil
	end
	def set_geometry(x, y)
		SendingEnviroment.instance.dependences.each do |dep|
			set_coords(x, y, dep.node)	
			n =	dep.connected_nodes.length
			l = (@node_radius + @space) * n 
			i = 0
			x += @node_radius + @space
			dep.connected_nodes.each do |cn|
				set_coords(x, y - l/2 + (@node_radius + @space) * (n - i), cn)
				i += 1	
			end
		end	
	end
	def set_coords(x, y, node)
		unless contains_node_coordinate(node) || node.attributes.mac_address == nil
			@NodesCoordinates << NodeRepresentation.new(x, y, node, @@colors["online"]) 
			x += @node_radius + @space 
		end
	end
	def contains_node_coordinate(node)
		@NodesCoordinates.each do |c|
			return true if c.node_addr == node
		end
		return false
	end

	def mousePressEvent(event)
		@choosing = true if (event.button() == Qt::LeftButton)
	end

	def mouseMoveEvent(event)
		select_node(event.pos()) if ((event.buttons() & Qt::LeftButton) && 
									  @choosing)
	end

	def mouseReleaseEvent(event)
		if (event.button() == Qt::LeftButton && @choosing)
			select_node(event.pos())
			@choosing = false
		end
	end
	def select_node pos
		@NodesCoordinates.each do |coord|
			if (pos.x >= coord.x && pos.x <= (coord.x + @node_radius + @space)) && 
			   (pos.y >= coord.y && pos.y <= (coord.y + @node_radius + @space))
                emit node_changed coord.node_addr.to_s
			end
		end	
	end

    def change_node_state(mac, state)
        return if @@colors[state].nil?
        @NodesCoordinates.each do |coord|
            if (coord.node_addr.attributes.mac_address == mac)
                coord.color = @@colors[state]
                break
            end
        end
        self.update()
    end

end
