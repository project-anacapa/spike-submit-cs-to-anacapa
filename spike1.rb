#!/usr/bin/env ruby

require 'optparse'
require 'octokit'

# This will hold the options we parse
options = {}

options[:count]=1

OptionParser.new do |parser|

  parser.on("-c", "--com", "Use github.com instead of github.ucsb.edu") do |v|
    options[:com] = v
  end
  
end.parse!

# This items should be the same for all students

puts "Hello Spike"
if !options[:com]
	Octokit.configure do |c|
	  c.api_endpoint = "https://github.ucsb.edu/api/v3/"
	end
end

client = Octokit::Client.new(:access_token => ENV["GITHUB_PERSONAL_ACCESS_TOKEN"])
user = client.user
puts user.login
