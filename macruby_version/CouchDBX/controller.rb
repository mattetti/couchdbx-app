# controller.rb
# CouchDBX
#
# Created by Matt Aimonetti on 12/2/09.
# Copyright 2009 m|a agile. All rights reserved.

class Controller

  attr_accessor :start_button, :browse_button
  attr_accessor :task, :stream_in, :stream_out
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
    @task          = NSTask.alloc.init
    launchCouchDB
  end
  
  def start(sender)
    task.isRunning ? stop : launchCouchDB
  end
  
  def browse(sender)
    openFuton
  end
  
  def launchCouchDB
    puts "launchCouchDB"
    browse_button.enabled = true
    start_button.setImage NSImage.imageNamed("stop.png")
    start_button.label = "stop"

    @stream_in  = NSPipe.alloc.init
    @stream_out = NSPipe.alloc.init
    @task       = NSTask.alloc.init
    
    couchdbx_path = "#{NSBundle.mainBundle.resourcePath}/couchdbx-core"
    task.currentDirectoryPath = couchdbx_path
    launch_path = "#{couchdbx_path}/couchdb/bin/couchdb"
    task.launchPath = launch_path
    raise "couchdbx-core missing, expected to be found at: #{launch_path}" unless File.exist?(launch_path)
    
    task.arguments = ['-i']
    task.standardInput  = stream_in
    task.standardOutput = stream_out
    
    fh = stream_out.fileHandleForReading
    nc = NSNotificationCenter.defaultCenter
    nc.addObserver(self, selector: "dataReady:", name: NSFileHandleReadCompletionNotification, object: fh)
    nc.addObserver(self, selector: "taskTerminated:", name: NSTaskDidTerminateNotification, object: task)
                   
    task.launch
    outputView.string = "Starting CouchDB...\n"
    fh.readInBackgroundAndNotify
    sleep(1)
    openFuton
  end
  
  def stop
    puts "stop"
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
    task, stream_in, stream_out = nil, nil, nil
    NSNotificationCenter.defaultCenter.removeObserver(self)
  end
  
  def openFuton
    webView.textSizeMultiplier = 1.3
    url = NSURL.URLWithString("http://127.0.0.1:5984/_utils/")
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
