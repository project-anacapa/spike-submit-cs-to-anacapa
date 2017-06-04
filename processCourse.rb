#!/usr/bin/env ruby
require_relative 'extractCourseData'
require 'octokit'


# This will hold the options we parse
options = {}

options[:count]=1

OptionParser.new do |parser|

  parser.on("-c", "--com", "Use github.com instead of github.ucsb.edu") do |v|
    options[:com] = v
  end

  parser.on("-s", "--student", "Add student submissions for this course") do |v|
  	options[:student] = v
  end

end.parse!


if !options[:com]
	Octokit.configure do |c|
	  c.api_endpoint = "https://github.ucsb.edu/api/v3/"
	end
end

if options[:student]
	add_submissions = true
else
	add_submissions = false
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

course_name = ARGV[0]
course_org = ARGV[1]

CE = CourseExtractor.new(client, course_name, course_org, add_submissions)
CE.Process_Course()
