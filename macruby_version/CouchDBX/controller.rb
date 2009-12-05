# controller.rb
# CouchDBX
#
# Created by Matt Aimonetti on 12/2/09.
# Copyright 2009 m|a agile. All rights reserved.
require 'instance_config'

class Controller

  attr_accessor :start_button, :browse_button
  attr_accessor :task, :stream_in, :stream_out
  attr_accessor :selected_instance, :instance_selector, :instance_configs
  attr_accessor :tasks
  attr_accessor :outputView, :webView
  
  def applicationShouldTerminateAfterLastWindowClosed(app)
    true
  end
  
  def windowWillClose(notification)
    stop
  end
  
  def awakeFromNib
    puts "loading code now that the nib loaded"
    browse_button.enabled = false
    resources_path = NSBundle.mainBundle.resourcePath.fileSystemRepresentation
    @instance_configs = Dir.glob(resources_path + '/couchdbx-core/couchdb/etc/couchdb/local*.ini').map do |file|
      
      conf = InstanceConfig.new(file)
      item = NSMenuItem.alloc.initWithTitle("port #{conf.port}", action: "change_instance:", keyEquivalent:'')
      instance_selector.addItem(item)
      {:file => file, :url => conf.url, :port => conf.port, :task => NSTask.alloc.init }
    end
    
    launchCouchDB
  end
  
  def change_instance(sender)
    port = sender.title[/port (.*)/, 1]
    config = instance_configs.find{|iconfig| iconfig[:port] == port}
    @selected_instance = config
    url = NSURL.URLWithString("#{config[:url]}/_utils")
    webView.mainFrame.loadRequest NSURLRequest.requestWithURL(url)
    puts "switched to #{webView.mainFrameURL}"
  end
  
  def start(sender)
    task.isRunning ? stop : launchCouchDB
  end
  
  def browse(sender)
    openFuton
  end
  
  def launchCouchDB
    puts "launchCouchDB"
        
    instance_configs.map{|config| fire_task(config) }

    browse_button.enabled = true
    start_button.setImage NSImage.imageNamed("stop.png")
    start_button.label = "stop"
    openFuton
  end
  
  def fire_task(config)
    return if config[:task].isRunning
    
    config[:task] = NSTask.alloc.init if config[:started]
    couchdbx_path = "#{NSBundle.mainBundle.resourcePath}/couchdbx-core"
    config[:task].currentDirectoryPath = couchdbx_path
    launch_path = "#{couchdbx_path}/couchdb/bin/couchdb"
    config[:task].launchPath = launch_path
    raise "couchdbx-core missing, expected to be found at: #{launch_path}" unless File.exist?(launch_path)
    config[:task].arguments      = ['-i', '-a', config[:file]]
  
    pi = NSPipe.alloc.init
    po = NSPipe.alloc.init
    config[:task].standardInput  = pi
    config[:task].standardOutput = po 
    file_handle = po.fileHandleForReading 
    file_handle.readInBackgroundAndNotify
    
    config[:task].launch
      
    if config[:file] =~ /local.ini/
      @task = config[:task]
      @stream_in = pi
      @stream_out = po                 
      nc = NSNotificationCenter.defaultCenter
      nc.addObserver(self, selector: "dataReady:", name: NSFileHandleReadCompletionNotification, object: file_handle)
      nc.addObserver(self, selector: "taskTerminated:", name: NSTaskDidTerminateNotification, object: config[:task])
    end
    
    config[:started] = true
    
  end
  
  
  def stop
    writer = stream_in.fileHandleForWriting
    writer.writeData "q().\n".dataUsingEncoding(NSUTF8StringEncoding)
    writer.closeFile
  
    browse_button.enabled = false
    start_button.image = NSImage.imageNamed("start.png")
    start_button.label = "start"
  end
  
  def taskTerminated(notification)
    cleanup
  end
  
  def cleanup  
    NSNotificationCenter.defaultCenter.removeObserver(self)
  end
  
  def openFuton
    webView.textSizeMultiplier = 1.3
    url = NSURL.URLWithString("#{instance_configs.first[:url]}/_utils/")
    request = NSURLRequest.requestWithURL(url)
	  webView.mainFrame.loadRequest request
  end
  
  def appendData(data)
    s = NSString.alloc.initWithData(data, encoding: NSUTF8StringEncoding)
    ts = outputView.textStorage
    range = NSMakeRange(ts.length, 0)
    ts.replaceCharactersInRange(range, withString:s)
    outputView.scrollRangeToVisible(range, 0)
  end
  
  
  def dataReady(notification)
    data = notification.userInfo[NSFileHandleNotificationDataItem]
    appendData(data) if data
    stream_out.fileHandleForReading.readInBackgroundAndNotify if task
  end

end
