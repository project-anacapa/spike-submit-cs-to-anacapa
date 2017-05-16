#!/usr/bin/env ruby

require 'optparse'
require 'octokit'
require 'logger'

require 'json'



# https://github.com/project-anacapa/course-github-org-tool/blob/feature/assignment-view/app/jobs/checkout_assignment_job.rb
# https://github.com/project-anacapa/course-github-org-tool/blob/development/app/controllers/assignments_controller.rb



# This will hold the options we parse
options = {}


course_json = %{
	{
		"org_name" : "clholoien-testorg-1",
		"projects":[
			{"name" : "lab00"},
			{"name" : "lab01"},
			{"name" : "lab02"}
		]
	}
}


def process_course(course_json, client)

	user = client.user
	course_info = JSON.parse(course_json)

	# See whether course_info["org_name"] is an organization that user has access to.
	org_name = course_info["org_name"]

	user_in_org = true

	# Check if user has access to this organization.
	if client.organization_member?(org_name, user.login)
		puts "User is part of the organization - " + org_name
	else
		puts "User is NOT part of the organization - " + org_name
	end

	for project in course_info["projects"]


		proj_name = project["name"]
		proj_repo_fullname =  "#{org_name}/#{proj_name}"

		existed  = true
		begin 
			proj_repo = client.repo(proj_repo_fullname)
		rescue
			existed = false
		end

		if ! existed	
			client.create_repository( proj_name , {  
				:organization => org_name,
				:private => true # change this to true when we know that private repos are feasible.
			} )			
			puts "Created repo " + proj_name + "."
			proj_repo = client.repo(proj_repo_fullname)
		else
			puts proj_name + " already exists."
		end

		begin
			spec = client.contents( proj_repo_fullname,
				:path => ".anacapa/assignment_spec.json"
				)
			spec = JSON.parse(Base64.decode64(spec.content))
		rescue 
			spec = {}
		end

		if spec.empty?
			puts "empty"
		else
			puts "NOT empty"
		end

	end

	# For each of the projects, determine if there already exists a project with this particular name.

	# e.g. lab00 or lab01 => 
	# if doesn't exist create it.
	# For each of those repos see if there is a folder .anacapa/assignment_spec.json


	
end


# def create_project(user, project_name)

# end


options[:count]=1

OptionParser.new do |parser|

  parser.on("-c", "--com", "Use github.com instead of github.ucsb.edu") do |v|
    options[:com] = v
  end
  
end.parse!

# This items should be the same for all students

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
process_course(course_json, client)

