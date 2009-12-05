# instance_config.rb
# CouchDBX
#
# Created by Matt Aimonetti on 12/3/09.
# Copyright 2009 m|a agile. All rights reserved.

class InstanceConfig
  
  attr_reader :ip, :port
  
  def initialize(file_path)
    file_content = NSString.stringWithContentsOfFile(file_path, encoding:NSUTF8StringEncoding, error:nil)
    @ip   = (file_content[/^\s*bind_address\s*=(.*)/, 1] || '127.0.0.1').strip
    @port = (file_content[/^\s*port\s*=(.*)/, 1] || '5984').strip
  end
  
  def url
    "http://#{ip}:#{port}"
  end

end


