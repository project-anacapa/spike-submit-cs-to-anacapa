#!/usr/bin/env ruby

require 'optparse'
require 'octokit'
require 'logger'
require 'json'
require 'date'
require 'modifySpec'




# https://github.com/project-anacapa/course-github-org-tool/blob/feature/assignment-view/app/jobs/checkout_assignment_job.rb
# https://github.com/project-anacapa/course-github-org-tool/blob/development/app/controllers/assignments_controller.rb


# This will hold the options we parse
options = {}


course_json = %{
	{
		"org_name" : "clholoien-testorg-1",
		"projects":[
			{"name" : "lab24"},
			{"name" : "lab01"},
			{"name" : "lab02", "type" : "string" },
			{"name" : "lab03"},
			{"name" : "lab04"}
		]
	}
}



def Add_Expected_Output()

end


def Add_Build_Files()

end


def Process_Course(org_name, course_info, client)

	# See whether course_info["org_name"] is an organization that user has access to.

	# For each of the projects, determine if there already exists a project with this particular name.

	# e.g. lab00 or lab01 => 
	# if doesn't exist create it.
	# For each of those repos see if there is a folder .anacapa/assignment_spec.json

	user = client.user
	puts user.login
	# course_info = JSON.parse(course_json)

	# org_name = course_info["name"]
	# org_name = "clholoien-testorg-1"

	user_in_org = true

	if client.organization_member?(org_name, user.login)
		puts "User IS part of the organization - " + org_name
	else
		puts "User is NOT part of the organization - " + org_name
	end

	proj_num = 0
	for project in course_info["projects"]


		proj_repo_fullname =  "#{org_name}/#{project["name"]}"

		if ! Does_Exist( client, proj_repo_fullname )	

			client.create_repository( project["name"] , {  
				:organization => org_name,
				:private => true
			} )			
			puts "Created repo " + project["name"] + "."
		else
			puts project["name"] + " already exists."
		end

		spec_json, spec_sha = Get_Spec(client, proj_repo_fullname)
		puts JSON.pretty_generate(spec_json)

		if spec_json == {}
			puts "Creating assignment_spec.json"
			Init_Proj_Spec(client, proj_repo_fullname, project)
		else
			puts "Updating assignment_spec.json"
			Update_Proj_Spec(client, proj_repo_fullname, project, spec_sha)
		end

		spec_json, spec_sha = Get_Spec(client, proj_repo_fullname)
		puts JSON.pretty_generate(spec_json)
		
	end
end


def Does_Exist(client, proj_repo_fullname)
	existed  = true
	begin 
		proj_repo = client.repo(proj_repo_fullname)
	rescue
		existed = false
	end
	return existed
end


def Get_Spec(client, proj_repo_fullname)
	begin
		spec = client.contents( proj_repo_fullname,
			:path => ".anacapa/assignment_spec.json"
			)
		return JSON.parse(Base64.decode64(spec.content)), spec.sha
	rescue 
		return {}
	end
end


def Init_Proj_Spec(client, proj_repo_fullname, proj_json)

	File.open("bin/random_assignment_spec.json", "w") do |file|
    	file.puts JSON.pretty_generate(proj_json)
  	end

  	client.create_contents( 
  		proj_repo_fullname, 
		".anacapa/assignment_spec.json", 
		"Add Assignment_Spec JSON File to each project repo.",
		{ :file => "bin/random_assignment_spec.json" } )
end


def Update_Proj_Spec(client, proj_repo_fullname, proj_json, sha)

	File.open("bin/random_assignment_spec.json", "w") do |file|
    	file.puts JSON.pretty_generate(proj_json)
  	end

	client.update_contents( 
		proj_repo_fullname, 
		".anacapa/assignment_spec.json", 
		"Update Assignment_Spec JSON File to each project repo.",
		sha, 
		{ :file => "bin/random_assignment_spec.json" } )
end




def Get_Assignment_Json(client, course)

	begin
		course_json = client.contents( "submit-cs-conversion/submit-cs-json",
			:path => "#{course}.json")
		course_json = JSON.parse(Base64.decode64(course_json.content))
	rescue 
		course_json = {}
	end

	begin
		course_sha_list = client.contents( "submit-cs-conversion/submit-cs-json",
			:path => "#{course}/SHA/" )
	rescue
		course_sha_list = []
	end

	return course_json, course_sha_list
end


def Create_Sha_Files(client, course, sha_list)
	if sha_list != []
		for file in sha_list
			begin
				sha_file = client.contents( "submit-cs-conversion/submit-cs-json",
					:path => "#{course}/SHA/#{file.name}"
					)
				sha_file = Base64.decode64(sha_file.content)
			rescue 
				puts "Sha unsuccessful."
			end

			File.open("bin/sha_files/#{file.name}", "w") do |file|
    			file.puts sha_file
  			end
		end
	end
end


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

course_json, sha_list = Get_Assignment_Json(client, "SANDBOX_CH")
Create_Sha_Files(client, "SANDBOX_CH", sha_list)
puts JSON.pretty_generate(course_json)
process_course("clholoien-testorg-1", course_json, client)

# puts JSON.pretty_generate(course_json)

