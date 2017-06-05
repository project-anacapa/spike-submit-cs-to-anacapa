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

  parser.on("-s", "--students", "ONLY Add the LAST student submissions for this course") do |v|
  	options[:students] = v
  end

	parser.on("-sf", "--studentsFirst", "ONLY Add the FIRST student submissions for this course") do |v|
  	options[:studentsFirst] = v
  end

  parser.on("-si", "--studentsNext", "ONLY Add the NEXT student submissions for this course") do |v|
  	options[:studentsNext] = v
  end


  parser.on("-a", "--assignments", "ONLY Add professor assignments for this course") do |v|
  	options[:assignments] = v
  end

end.parse!


if !options[:com]
	Octokit.configure do |c|
	  c.api_endpoint = "https://github.ucsb.edu/api/v3/"
	end
end

add_submissions = true
add_assignments = true

which_sub = "LAST"

if options[:students]
	add_assignments = false


elsif options[:assignment]
	add_submissions = false

elsif options[:studentsFirst]
	add_assignments = false
	which_sub = "FIRST"

elsif options[:studentsNext]
	add_assignments = false
	which_sub = "NEXT"
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

CE = CourseExtractor.new(client, course_name, course_org, add_assignments, add_submissions, which_sub)
CE.Process_Course()
