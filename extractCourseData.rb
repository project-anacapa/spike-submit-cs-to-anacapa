#!/usr/bin/env ruby

require 'optparse'
require 'octokit'
require 'logger'
require 'json'
require 'date'
require_relative 'modifySpec'


# This will hold the options we parse
options = {}

def Add_All_Members(client, org_name)
	members = ["ncbrown", "pconrad", "gareth", "connor00"]
	begin
		org = client.organization(org_name)
	rescue
		puts "Could not get org"
		exit()
	end

	puts org.id

end

def Process_All_Courses(client)
	# puts "Process All Courses"

	courses = []

	for course in courses
		course_json, sha_list = Get_Course(client, org)

		Create_Sha_Files(client, org, sha_list)

		Process_Course(client, org, course_json)
	end
end


def Process_Course(client, org_name, old_course_spec)
	# puts "Process Course"

	#Github does not support organizations with underscores...
	org_name = org_name.tr('_', '-')

	user = client.user
	puts user.login

	user_in_org = true

	if client.organization_member?(org_name, user.login)
		puts "User IS part of the organization - " + org_name
	else
		puts "User is NOT part of the organization - " + org_name
		# Course process Not Successful
		return false
	end

	proj_num = 0
	for project in old_course_spec["projects"]

		# Change to Assignment_lab00
		# proj_repo_fullname =  "#{org_name}/#{project["name"]}"

		if proj_num >= 10 
			repo_name =  "assignment-lab#{proj_num}"
		else
			repo_name =  "assignment-lab0#{proj_num}"
		end

		proj_repo_fullname =  "#{org_name}/#{repo_name}"

		new_proj_spec, execution_files, expected_files, build_files  = Modify_Spec(proj_repo_fullname, project)

		# Create Project Repo
		if ! Does_Repo_Exist( client, proj_repo_fullname )	

			client.create_repository( repo_name , {  
				:organization => org_name,
				:private => true
			} )			
			# puts "Created repo #{repo_name}."
		else
			# puts "#{repo_name}" + " already exists."
		end

		spec_json, spec_sha = Get_Spec(client, proj_repo_fullname)
		# puts JSON.pretty_generate(spec_json)

		if spec_json == {}
			# puts "Creating assignment_spec.json"
			Add_Proj_Spec(client, proj_repo_fullname, new_proj_spec)
		else
			# puts "Updating assignment_spec.json"
			Update_Proj_Spec(client, proj_repo_fullname, new_proj_spec, spec_sha)
		end

		# Update Expected Files
		for file_sha in execution_files

			file_path = ".anacapa/execution_files/#{file_sha}.xml"
			Add_Sha_Files(client, proj_repo_fullname, file_path, file_sha)

		end

		# Update Execution Files
		for file_sha in expected_files

			file_path = ".anacapa/expected_output/#{file_sha}.xml"
			Add_Sha_Files(client, proj_repo_fullname, file_path, file_sha)
			
		end

		# Update Build Files
		for file_sha in build_files

			file_path = ".anacapa/build_files/#{file_sha}.xml"
			Add_Sha_Files(client, proj_repo_fullname, file_path, file_sha)
			
		end

		# spec_json, spec_sha = Get_Spec(client, proj_repo_fullname)
		# puts JSON.pretty_generate(spec_json)

		proj_num += 1
		
	end

	# Course processed successfully
	return true
end


def Add_Sha_Files(client, proj_repo_fullname, file_path, file_sha)
	# Check if file exists...?	
	file = Get_File(client, proj_repo_fullname, file_path)

	if file != nil
		Update_File(client, proj_repo_fullname, file_path, file_sha, file.sha)
	else
		Add_File(client, proj_repo_fullname, file_path, file_sha)
	end
end

def Does_Repo_Exist(client, proj_repo_fullname)
	# puts "Does Repo Exist? #{proj_repo_fullname}"

	existed  = true
	begin 
		proj_repo = client.repo(proj_repo_fullname)
		# puts "Yes"
	rescue
		# puts "No"
		existed = false
	end
	return existed
end


def Get_File(client, proj_repo_fullname, file_path)
	# puts "Does File Exist? #{file_path}"

	begin 
		file = client.contents( proj_repo_fullname,
			:path => file_path )
		# puts "Yes"
	rescue
		file = nil
		# puts "No"
	end
	return file
end


def Get_Spec(client, proj_repo_fullname)
	# puts "Get Spec"

	begin
		spec = client.contents( proj_repo_fullname,
			:path => ".anacapa/assignment_spec.json"
			)
		return JSON.parse(Base64.decode64(spec.content)), spec.sha
	rescue 
		return {}
	end
end


def Add_Proj_Spec(client, proj_repo_fullname, proj_json)
	# puts "Add Proj Spec"

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
	# puts "Update Proj Spec"

	File.open("bin/random_assignment_spec.json", "w") do |file|
    	file.puts JSON.pretty_generate(proj_json)
  	end

	client.update_contents( 
		proj_repo_fullname, 
		".anacapa/assignment_spec.json", 
		"Update Assignment_Spec JSON file for each project repo.",
		sha, 
		{ :file => "bin/random_assignment_spec.json" } )
end


def Add_File(client, proj_repo_fullname, file_path, file_name)
	# puts "Add File"
	
	type = ""

	if file_path.include? "execution"
		type = "execution"
	elsif file_path.include? "expected"
		type = "expected"
	elsif file_path.include? "build"
		type = "build"
	end

	if (File.exist?("bin/sha_files/#{file_name}"))

		client.create_contents( 
	  		proj_repo_fullname, 
			file_path, 
			"Add file in #{type} directory to each project repo.",
			{ :file => "bin/sha_files/#{file_name}.xml" } )
	else
		puts "WARNING: File not found: #{file_name}"
	end
end


def Update_File(client, proj_repo_fullname, file_path, file_name, sha)
	# puts "Update File"

	type = ""

	if file_path.include? "execution"
		type = "Execution"
	elsif file_path.include? "expected"
		type = "Expected"
	elsif file_path.include? "build"
		type = "Build"
	end

	if (File.exist?("bin/sha_files/#{file_name}"))
		client.update_contents( 
			proj_repo_fullname, 
			file_path, 
			"Update file in #{type} directory." ,
			sha, 
			{ :file => "bin/sha_files/#{file_name}.xml" } )
	else
		puts "WARNING: File not found: #{file_name}"
	end
end



def Get_Course(client, course)
	# puts "Get Course"

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
	# puts "Create Sha Files"
	if sha_list != []
		for file in sha_list
			begin
				sha_file = client.contents( "submit-cs-conversion/submit-cs-json",
					:path => "#{course}/SHA/#{file.name}"
					)
				sha_file = Base64.decode64(sha_file.content)
			rescue 
				puts "WARNING: Unable to create Sha. #{file.name}"
			end

			File.open("bin/sha_files/#{file.name}.xml", "w") do |file|
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
puts "What course would you like to extract from?"
org = gets
org = org.chomp

course_json, sha_list = Get_Course(client, org)

Create_Sha_Files(client, org, sha_list)

Process_Course(client, org, course_json)

Add_All_Members(client, org)




