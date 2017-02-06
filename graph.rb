require 'Qt'
require_relative 'emulator'
require_relative 'topology_widget'

class QtApp < Qt::Widget 

	slots 'update_log(const QString &)', 'start_emulation()'

	attr_accessor :quit_button, :start_button

	def initialize
		super
		
		setup_emulator
		initUI

		resize 500, 250
		#move 300, 300
		show
	end

	def initUI

		@menubar = Qt::MenuBar.new(self)
		@menubar.setObjectName('menubar')
		@menuFile = Qt::Menu.new(@menubar)
		@menuFile.setObjectName('menuFile')
		@menuFile.setTitle('File')
		@menuHelp = Qt::Menu.new(@menubar)
		@menuHelp.setObjectName('menuHelp')
		@menuHelp.setTitle('&Help')
		@actionNew = Qt::Action.new(self)
		@actionNew.setObjectName('actionNew')
		@actionNew.setText('New')
		@actionExit = Qt::Action.new(self)
		@actionExit.setObjectName('actionExit')
		@actionExit.setText('Exit')
		@actionAbout = Qt::Action.new(self)
		@actionAbout.setObjectName('actionAbout')
		@actionAbout.setText('About')
		@menubar.addAction(@menuFile.menuAction())
		@menubar.addAction(@menuHelp.menuAction())
		@menuFile.addAction(@actionNew)
		@menuFile.addAction(@actionExit)
		@menuHelp.addAction(@actionAbout)
		 
		hbox = Qt::HBoxLayout.new
		vbox = Qt::VBoxLayout.new 
		vbox1 = Qt::VBoxLayout.new
		vbox2 = Qt::VBoxLayout.new
		group = Qt::HBoxLayout.new
		
		@widget = TopologyWidget.new self
		@log_text_box = Qt::TextEdit.new self
		@log_text_box.setEnabled true 
		@log_text_box.setText "LOG "
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

		vbox1.addWidget @log_text_box
		#vbox1.addStretch 1
		vbox1.addWidget @quit_button, 0, Qt::AlignRight

		hbox.addLayout vbox
		hbox.addLayout vbox1

		vbox2.addWidget @menubar, 0, Qt::AlignLeft
		vbox2.addLayout hbox

		setLayout vbox2

		Qt::Object.connect(@widget, SIGNAL('node_changed(const QString &)'),
											 @node_text_box, SLOT('setText(const QString &)'))
	end
	
	def start_emulation
		run_emulation
	end
	def update_log(mes)
		@log_text_box.append(mes)
	end

end


app = Qt::Application.new ARGV
qt = QtApp.new


Node.elements.each do |node|
	Qt::Object.connect(node, SIGNAL('push_text(const QString&)'), 
										 qt, SLOT('update_log(const QString&)') )
end

Qt::Object.connect(qt.start_button, SIGNAL('clicked()'),
									 qt, SLOT('start_emulation()'))
Qt::Object.connect(qt.quit_button, SIGNAL('clicked()'), app, SLOT('quit()'))

app.exec

