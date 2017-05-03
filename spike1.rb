#!/usr/bin/env ruby

require 'optparse'
require 'octokit'

# This will hold the options we parse
options = {}

options[:count]=1

OptionParser.new do |parser|

  parser.on("-c", "--count COUNT", Integer, "Repeat the message COUNT times") do |v|
    options[:count] = v
  end
  
end.parse!

# This items should be the same for all students

puts "Hello Spike"

client = Octokit::Client.new(:access_token => ENV["GITHUB_PERSONAL_ACCESS_TOKEN"])
user = client.user
puts user.login
