# controller.rb
# CouchDBX
#
# Created by Matt Aimonetti on 12/2/09.
# Copyright 2009 m|a agile. All rights reserved.
require 'instance_config'
require 'mr_task'

class Controller

  attr_accessor :start_button, :browse_button
  attr_accessor :stream_in, :stream_out
  attr_accessor :selected_instance, :instance_selector, :instance_configs
  attr_accessor :outputView, :webView
  
  def awakeFromNib
    puts "loading code now that the nib loaded"
    browse_button.enabled = false
    @logging_started = false
    resources_path = NSBundle.mainBundle.resourcePath.fileSystemRepresentation
    @instance_configs = Dir.glob(resources_path + '/couchdbx-core/couchdb/etc/couchdb/local*.ini').map do |file|
      
      conf = InstanceConfig.new(file)
      item = NSMenuItem.alloc.initWithTitle("port #{conf.port}", action: "change_instance:", keyEquivalent:'')
      instance_selector.addItem(item)
      {:file => file, :url => conf.url, :port => conf.port, :task => nil }
    end
    @selected_instance = @instance_configs.first
    
    launchCouchDB
  end
  
  def change_instance(sender)
    port = sender.title[/port (.*)/, 1]
    config = instance_configs.find{|iconfig| iconfig[:port] == port}
    @selected_instance = config
    url = NSURL.URLWithString("#{config[:url]}/_utils")
    webView.mainFrame.loadRequest NSURLRequest.requestWithURL(url)
    puts "switched to #{webView.mainFrameURL}"
    update_start_button_status
  end
  
  def start(sender)
    if task
      task.running? ? stop : launchCouchDB
    else
      fire_task(selected_instance)
      switch_start_button
    end
  end
  
  def browse(sender)
    openFuton
  end
  
  def launchCouchDB
    instance_configs.map{|config| fire_task(config) }
    switch_start_button
    openFuton
  end
  
  def fire_task(config)
    return if config[:task] && config[:task].running?    
    couchdbx_path = "#{NSBundle.mainBundle.resourcePath}/couchdbx-core"
    launch_path = "#{couchdbx_path}/couchdb/bin/couchdb"
    raise "couchdbx-core missing, expected to be found at: #{launch_path}" unless File.exist?(launch_path)
    
    args = ['-i', '-a', config[:file]]
    task = MrTask.new(launch_path, from_directory: couchdbx_path).on_output do |output|
      log("#{config[:port]}: #{output}")
    end
    task.launch(args)
    config[:task] = task    
  end
  
  def stop
    selected_instance[:task].kill do
       log("#{selected_instance[:port]}: closed")
    end
    selected_instance[:task] = nil
    update_start_button_status('stop')
  end
  
  def stop_all
    instance_configs.each{|config| config[:task].kill; config[:task] = nil}
  end
  
  def task
    selected_instance[:task]
  end
  
  def switch_start_button
    label = start_button.label == "stop" ? "start" : "stop"
    update_start_button_status(label)
  end
  
  def update_start_button_status(label=nil)
    if label.nil? && task && task.running?
      label = "stop"
    elsif label.nil?
      label = "start"
    end
    start_button.setImage NSImage.imageNamed("#{label}.png")
    start_button.label = label
    browse_button.enabled = (label == 'start')
  end
  
  def taskTerminated(notification)
    # cleanup
  end
  
  def openFuton
    webView.textSizeMultiplier = 1.3
    url = NSURL.URLWithString("#{instance_configs.first[:url]}/_utils/")
    request = NSURLRequest.requestWithURL(url)
	  webView.mainFrame.loadRequest request
  end
  
  def log(data_string)
    ts = outputView.textStorage
    range = NSMakeRange(ts.length, 0)
    ts.replaceCharactersInRange(range, withString:data_string)
    outputView.scrollRangeToVisible(range, 0)
  end
  
  # Application settings
  def applicationShouldTerminateAfterLastWindowClosed(app); true; end
  def windowWillClose(notification); stop_all; end

end
