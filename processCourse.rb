#!/usr/bin/env ruby
require_relative 'extractCourseDataWrapper'
require 'octokit'


# This will hold the options we parse
options = {}

options[:count]=1

OptionParser.new do |parser|

  parser.on("-c", "--com", "Use github.com instead of github.ucsb.edu") do |v|
    options[:com] = v
  end
  
end.parse!


if !options[:com]
	Octokit.configure do |c|
	  c.api_endpoint = "https://github.ucsb.edu/api/v3/"
	end
end

if ENV["GITHUB_PERSONAL_ACCESS_TOKEN"]
	token = ENV["GITHUB_PERSONAL_ACCESS_TOKEN"]
else
	puts "Looks like you forgot to do '. env.sh'"
	exit
end

client = Octokit::Client.new(:access_token => token, 
							:api_endpoint => "https://github.ucsb.edu/api/v3/"
							)

puts "What course would you like to extract from? (Format seen on https://github.ucsb.edu/submit-cs-conversion/submit-cs-json)"
org = gets
org = org.chomp

puts "What is the organization name for the course on the new anacapa system?"
org_dest = gets
org_dest = org.chomp

course_json, sha_list = Get_Course(client, org)

Create_Sha_Files(client, org, sha_list)

if Process_Course(client, org_dest, course_json)
	puts "Course processed successfully"
else
	puts "Course NOT processed successfully."
end


