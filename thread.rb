require 'Qt'
require_relative 'emulator'
require_relative 'topology_widget'

class QtApp < Qt::Widget 

	slots 'start_emulation()', 'stop_emulation()', 'update()'

	attr_accessor :quit_button, :start_button, :stop_button

	def initialize
		super
		
		setup_emulator
		initUI

		resize 1920, 1080
		show
	end

	def start_emulation()
		@process_thread = Thread.new { run_emulation }
	end
	def stop_emulation()
        Thread.kill @process_thread
	end

	def initUI

		hbox = Qt::HBoxLayout.new
		vbox = Qt::VBoxLayout.new 
		vbox1 = Qt::VBoxLayout.new
		vbox2 = Qt::VBoxLayout.new
		group = Qt::HBoxLayout.new
		
		@widget = TopologyWidget.new self
		@log = Qt::TextEdit.new self
		@log.setEnabled true 
		@log.setText "LOG "
		@node_text_box = Qt::TextEdit.new self
		@node_text_box.setEnabled false
		@node_text_box.setText "NODE STATS"
		@quit_button = Qt::PushButton.new "Quit", self
		@start_button = Qt::PushButton.new "Start", self
		@stop_button = Qt::PushButton.new "Stop", self

		group.addWidget @start_button, 0, Qt::AlignLeft
		group.addWidget @stop_button, 0, Qt::AlignLeft

		vbox.addWidget @widget
		vbox.addStretch 1
		vbox.addWidget @node_text_box
		vbox.addLayout group

		vbox1.addWidget @log
		vbox1.addWidget @quit_button, 0, Qt::AlignRight

		hbox.addLayout vbox
		hbox.addLayout vbox1

		vbox2.addWidget @menubar, 0, Qt::AlignLeft
		vbox2.addLayout hbox

		setLayout vbox2
		
		Node.elements.each do |node|
			Qt::Object.connect(node, SIGNAL('push_text(const QString&)'),
							   @log, SLOT('append(const QString&)'))
            Qt::Object.connect(node, SIGNAL('state_changed(const QString&, const QString&)'),
                               @widget, SLOT('change_node_state(const QString, const QString&)'))
		end

		Qt::Object.connect(@widget, SIGNAL('node_changed(const QString &)'),
											 @node_text_box, SLOT('setText(const QString &)'), 
											 Qt::DirectConnection)


	
	end
	

end

app = Qt::Application.new ARGV
qt = QtApp.new

Qt::Object.connect(qt.quit_button, SIGNAL('clicked()'), app, SLOT('quit()'))
Qt::Object.connect(qt.start_button, SIGNAL('clicked()'), qt, SLOT('start_emulation()'))
Qt::Object.connect(qt.stop_button, SIGNAL('clicked()'), qt, SLOT('stop_emulation()'))

app.exec
