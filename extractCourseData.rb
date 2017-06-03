#!/usr/bin/env ruby

require 'optparse'
require 'octokit'
require 'logger'
require 'json'
require 'date'


class CourseExtractor

	def initialize(client, course_name, course_org)
		@client = client
		@course_name = course_name
		@course_org = course_org
	end	


	def Process_Course()

		if !Does_Org_Exist()
			STDERR.puts "WARNING: Course organization does not exist."
			return
		end

		old_course_spec = Get_Course()

		if old_course_spec.empty?
			return
		end

		proj_num = 0
		for project in old_course_spec["projects"]

			if proj_num >= 10 
				repo_name =  "assignment-lab#{proj_num}"
			else
				repo_name =  "assignment-lab0#{proj_num}"
			end

			proj_repo_fullname = Init_Repo(repo_name)

			Update_Proj_Spec(proj_repo_fullname, Modify_Spec(proj_repo_fullname, project) )

			proj_num += 1
		end
	end


	def Modify_Spec(proj_repo_fullname, old_hash)

		new_hash = Hash.new
		new_hash["assignment_name"] = old_hash["name"]
		new_hash["deadline"] = Time.now.strftime("%Y-%m-%dT21:33:00-08:00")
		new_hash["maximum_group_size"] = old_hash["group_max"]

		if old_hash.key?("status")

			if old_hash["status"] == "ready"
				new_hash["ready"] = true
			else
				new_hash["ready"] = false
			end
		else
			new_hash["ready"] = false
		end

		
		new_hash["expected_files"] = Array.new
		new_hash["testables"] = Array.new

		for testable in old_hash["testables"]

			testable_hash = Hash.new
			testable_hash["test_name"] = testable["name"]
			
			if testable["make_target"] != nil
				testable_hash["build_command"] = "make " + testable["make_target"]
			end
			
			if testable.include? "execution_files_json"
				for file in testable["execution_files_json"]
					Extract_and_Save_File(proj_repo_fullname, file["file_hex"], ".anacapa/test_data/#{file["name"]}")
				end
			elsif testable.include? "execution_files"
				for file in testable["execution_files"]
					Extract_and_Save_File(proj_repo_fullname, file["sha1"], ".anacapa/test_data/#{file["sha1"]}")
				end
			end

			if testable.include? "build_files_json"
				for file in testable["build_files_json"]
					Extract_and_Save_File(proj_repo_fullname, file["file_hex"], ".anacapa/build_data/#{file["name"]}")
				end
			elsif testable.include? "build_files"
				for file in testable["build_files"]
					Extract_and_Save_File(proj_repo_fullname, file["file_hex"], ".anacapa/build_data/#{file["name"]}")
				end
			end
				

			for file in testable["expected_files"]
				# only add distinct file names to this
				if ! new_hash["expected_files"].include? file["name"]
					new_hash["expected_files"] << file["name"]
				end
			end

			#Test Cases
			testable_hash["test_cases"] = Array.new

			for test_case in testable["test_cases"]

				test_case_hash = Hash.new
				test_case_hash["command"] = test_case["args"]
				test_case_hash["diff_source"] = test_case["source"]
				test_case_hash["expected"] = test_case["expected"]["sha1"]
				test_case_hash["kind"] = test_case["output_type"]
	
				if test_case.key?("hide_expected")
					test_case_hash["hide_expected"] = test_case["hide_expected"]
				else
					test_case_hash["hide_expected"] = false
				end

				
				if test_case.key?("points")
					test_case_hash["points"] = test_case["points"]
				else
					test_case_hash["points"] = 100
				end


				if test_case.key?("timeout")
					test_case_hash["timeout"] = test_case["timeout"]
				end

				testable_hash["test_cases"] << test_case_hash

				Extract_and_Save_File(proj_repo_fullname, test_case["expected"]["sha1"], ".anacapa/expected_output/#{test_case["expected"]["sha1"]}")
			end

			new_hash["testables"] << testable_hash
		end

		return new_hash
	end


	def Does_Org_Exist()

		begin
			org = @client.organization(@course_org)
			return true
		rescue
			return false
		end
	end


	def Init_Repo(repo_name)
		
		proj_repo_fullname =  "#{@course_org}/#{repo_name}"

		if ! Does_Repo_Exist(proj_repo_fullname)	
			begin
				@client.create_repository( repo_name , {  
					:organization => @course_org,
					:private => true
				})	
			rescue
				STDERR.puts "WARNING: Unable to CREATE repository #{proj_repo_fullname}"
			end
		end

		return proj_repo_fullname
	end


	def Does_Repo_Exist(proj_repo_fullname)
		begin 
			proj_repo = @client.repo(proj_repo_fullname)
			return true
		rescue
			return false
		end
	end


	def Update_Proj_Spec(proj_repo_fullname, new_proj_spec)

		old_proj_spec = Get_File(proj_repo_fullname, ".anacapa/assignment_spec.json")

		if old_proj_spec == nil

			begin
			  	@client.create_contents( 
			  		proj_repo_fullname, 
					".anacapa/assignment_spec.json", 
					"Add Assignment_Spec JSON File to each project repo.",
					JSON.pretty_generate(new_proj_spec) )
			rescue
				STDERR.puts "WARNING: Unable to ADD assignment_spec.json"
			end
		else

			begin
				@client.update_contents( 
					proj_repo_fullname, 
					".anacapa/assignment_spec.json", 
					"Update Assignment_Spec JSON file for each project repo.",
					old_proj_spec.sha, 
					JSON.pretty_generate(new_proj_spec) )
			rescue
				STDERR.puts "WARNING: Unable to UPDATE assignment_spec.json"
			end
		end
	end


	def Extract_and_Save_File(proj_repo_fullname, sha_file_name, file_path)

		begin
			file_contents = Base64.decode64( @client.contents( "submit-cs-conversion/submit-cs-json",
				:path => "#{@course_name}/SHA/#{sha_file_name}"
				).content )
		rescue 
			STDERR.puts "WARNING: Unable to FIND #{sha_file_name} at submit-cs-conversion/submit-cs-json/#{@course_name}/SHA/#{sha_file_name}"
			return
		end

		file = Get_File(proj_repo_fullname, file_path)

		if file == nil
			begin
				@client.create_contents( 
			  		proj_repo_fullname, 
					file_path, 
					"Add #{file_path} in #{proj_repo_fullname}.",
					file_contents)
			rescue 
				STDERR.puts "WARNING: Unable to ADD #{file_path} using: #{sha_file_name}."
			end
		else
			begin
				@client.update_contents( 
					proj_repo_fullname, 
					file_path, 
					"Update #{file_path} in #{proj_repo_fullname}" ,
					file.sha, 
					file_contents )

			rescue
				STDERR.puts "WARNING: Unable to UPDATE #{file_path} using: #{sha_file_name}"
			end
		end
	end

	def Get_Course()

		begin
			course_json = JSON.parse( Base64.decode64( @client.contents( 
				"submit-cs-conversion/submit-cs-json",
				:path => "#{@course_name}.json").content))
			return course_json
		rescue 
			STDERR.puts "WARNING: Could not GET course at submit-cs-conversion/submit-cs-json/#{@course_name}.json"
			return {}
		end
	end


	def Get_File(proj_repo_fullname, file_path)

		begin 
			file = @client.contents( proj_repo_fullname,
				:path => file_path )
		rescue
			file = nil
		end

		return file
	end



	# if @client.organization_member?(@course_org, @client.user.login)
	# 		puts "User IS part of the organization - " + @course_org
	# 	else
	# 		puts "User is NOT part of the organization - " + @course_org
	# 		return
	# 	end

end


