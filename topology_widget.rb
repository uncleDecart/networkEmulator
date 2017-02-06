require 'Qt'
require_relative 'node'

class Point
	attr_accessor :x, :y, :node_addr
	
	def initialize(*args)
		@x,@y, @node_addr = args
	end
end

PANEL_HEIGHT = 150
PANEL_WIDTH = 450

class TopologyWidget < Qt::Widget 

	signals 'node_changed(const QString &)'
	slots 'node_reciving()'

	def initialize(parent) 
			super(parent)
			
			@NodesCoordinates = []		

			@online_color = Qt::Color.new 0, 103, 51
			@ofline_color = Qt::Color.new 255, 255, 184

			@line_color = Qt::Color.new 0, 0, 0

			@parent = parent

			@node_radius = 60
			@space = 15
			
			set_geometry
			
			setMinimumHeight PANEL_HEIGHT
			setMinimumWidth PANEL_WIDTH
	end

	
	def paintEvent event

			painter = Qt::Painter.new self
			
			drawWidget painter
			painter.end
	end

	def drawWidget painter
		painter.setPen @online_color
		painter.setBrush Qt::Brush.new @online_color
		unless @NodesCoordinates.nil? 
			for i in 0 .. @NodesCoordinates.length - 2
				painter.drawLine(@NodesCoordinates[i].x, 
												 @NodesCoordinates[i].y + @node_radius/2,
											   @NodesCoordinates[i + 1].x,
												 @NodesCoordinates[i + 1].y + @node_radius/2)
			end
			@NodesCoordinates.each do |coord|
				painter.drawEllipse  coord.x, coord.y, @node_radius, @node_radius
			end
			
			painter.setPen @line_color
			painter.setBrush Qt::Brush.new @line_color
		end
	end

	def set_geometry
		i = 0
		j = 0
		Node.elements.each do |node|
			@NodesCoordinates << Point.new((@node_radius + @space) * i,
																		 (@node_radius + @space) * j, node) 
			i += 1
		end	
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
			@choosing = false;
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

end
