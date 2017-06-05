#!/usr/bin/env ruby

require 'optparse'
require 'octokit'
require 'logger'
require 'json'
require 'date'


class CourseExtractor

	def initialize(client, course_name, course_org, add_assignments, add_submissions, which_sub)
		@client = client
		@course_name = course_name
		@course_org = course_org
		@add_assignments = add_assignments
		@add_submissions = add_submissions
		@which_sub = which_sub
	end	


	def Process_Course()

		if !Does_Org_Exist()
			STDERR.puts "WARNING: Course organization does not exist."
			return
		end

		if !Check_Membership()
			return
		end

		old_course_spec = Get_Course()

		if old_course_spec.empty?
			return
		end

		# proj_num = 0



		for project in old_course_spec["projects"]

			lab_name = project["name"].gsub(/\W+/, '_')

			if lab_name.length > 15
				lab_name = "p#{project["id"]}"
			end

			repo_name =  "assignment-#{lab_name}"

			if @add_assignments
				proj_repo_fullname = Init_Repo(repo_name)

				Update_Proj_Spec(proj_repo_fullname, Modify_Spec(proj_repo_fullname, project) )
			end


			proj_id = project["id"]

			if @add_submissions
				Add_Student_Submissions(proj_id, lab_name)
			end

			# proj_num += 1
			puts " "
		end
	end


#  proj_id is the key for the hash given the old {course_name}.json file...
	def Add_Student_Submissions(proj_id, lab_name)

		course_sub_repo = "#{@course_name}_submissions"

		if !Does_Repo_Exist("submit-cs-conversion/#{course_sub_repo}")
			STDERR.puts "WARNING: submit-cs-conversion/#{course_sub_repo} does not exist." 
			return
		end

		begin
			all_proj = JSON.parse(Base64.decode64( @client.contents( "submit-cs-conversion/#{course_sub_repo}",
				:path => "#{@course_name}.json"
				).content ))
		rescue Exception => e
			STDERR.puts "WARNING: Unable to FIND #{@course_name}.json at submit-cs-conversion/#{course_sub_repo}/#{@course_name}.json"
			STDERR.puts e.message, e.backtrace.inspect

			return
		end


		proj = all_proj["#{proj_id}"]

		if proj == nil
			STDERR.puts "WARNING: Unable to find submissions for #{lab_name}"
			return
		end


		puts "Adding Student Submissions for #{lab_name}"

		proj.each do |sub_type, submissions|

			if sub_type == "consenting_users_with_solo_submissions" 

				submissions.each do |user, subs|

					Add_One_Submission(user, subs, course_sub_repo, lab_name)
				end

			elsif sub_type == "consenting_users_with_group_submissions"

				submissions.each do |user, subs|

					Add_One_Submission(user, subs, course_sub_repo, lab_name)

				end

			end
		end
	end


	def Add_One_Submission(user, subs, course_sub_repo, lab_name)
		umail = user.split("@umail.ucsb.edu")
		username = umail[0]
		repo_name = "#{lab_name}-#{username}"

		if Github_User(username)

			sub_repo_fullname = Init_Repo(repo_name)
			Add_Collaborator(sub_repo_fullname, username)

			if @which_sub == "FIRST"
				sub_to_send = subs[0]
				puts "FIRST - SUB"

			elsif @which_sub == "NEXT"
				next_index = Get_Sub_Index(sub_repo_fullname, subs)
				sub_to_send = subs[ next_index ]
				puts "NEXT - SUB: #{next_index}"

			else #LAST SUB
				puts "LAST - SUB"
				sub_to_send = subs[-1]
			end

			Create_Or_Update_File(sub_repo_fullname, ".anacapa/submission.json", JSON.pretty_generate(sub_to_send))


			Create_Or_Update_File(sub_repo_fullname, "ReadMe.md", "https://submit.cs.ucsb.edu/submission/#{sub_to_send["id"]}")

			for file in sub_to_send["files"]
				if file.include? "sha"
					sha_file_path = "#{@course_name}/SHA/#{file["sha"]}"
				elsif file.include? "sha1"
					sha_file_path = "#{@course_name}/SHA/#{file["sha1"]}"
				elsif file.include? "file_hex"
					sha_file_path = "#{@course_name}/SHA/#{file["file_hex"]}"
				else
					STDERR.puts "WARNING SHA file not found."
					return
				end

				Extract_and_Save_File(sub_repo_fullname, "#{file["filename"]}", "#{course_sub_repo}", sha_file_path)
			end
		end
	end


	def Get_Sub_Index(repo_fullname, subs)

		file = Get_File(repo_fullname, ".anacapa/submission.json")

		if file != nil

			file_contents = JSON.parse( Base64.decode64( file.content ) )

			cur_id = file_contents["id"]

			index = 0

			for sub in subs
				if cur_id == sub["id"]
					break
				end
				index += 1 
			end

			if subs[index] == subs[-1]
				return index
			else
				return index + 1
			end

		else
			puts "FILE = NIL"

			return 0;

		end

	end


	def Modify_Spec(proj_repo_fullname, old_hash)

		puts "Modifying Spec for #{proj_repo_fullname}"

		new_hash = Hash.new
		new_hash["assignment_name"] = old_hash["name"]
		new_hash["deadline"] = Time.now.strftime("%Y-%m-%dT21:33:00-08:00")
		new_hash["maximum_group_size"] = old_hash["group_max"]
		new_hash["expected_files"] = Array.new
		new_hash["testables"] = Array.new

		if old_hash.key?("status")

			if old_hash["status"] == "ready"
				new_hash["ready"] = true
			else
				new_hash["ready"] = false
			end
		else
			new_hash["ready"] = false
		end

		for file in old_hash["expected_files"]
			new_hash["expected_files"] << file["name"]
		end

		if old_hash.include?"execution_files_json"

			for file in old_hash["execution_files_json"]
				Extract_and_Save_File(proj_repo_fullname, ".anacapa/test_data/#{file["name"]}","submit-cs-json", "#{@course_name}/SHA/#{file["file_hex"]}")
			end

		end

		if old_hash.include? "build_files_json"

			for file in old_hash["build_files_json"]
				Extract_and_Save_File(proj_repo_fullname,".anacapa/build_data/#{file["name"]}","submit-cs-json", "#{@course_name}/SHA/#{file["file_hex"]}")
			end

		end

		if old_hash.include? "makefile"
			Extract_and_Save_File(proj_repo_fullname, ".anacapa/build_data/makefile", "submit-cs-json", "#{@course_name}/SHA/#{old_hash["makefile"]["file_hex"]}")
		end


		for testable in old_hash["testables"]

			testable_hash = Hash.new
			testable_hash["test_name"] = testable["name"]
			testable_hash["test_cases"] = Array.new
			
			if testable["make_target"] != nil
				testable_hash["build_command"] = "make " + testable["make_target"]
			end

			for test_case in testable["test_cases"]

				test_case_hash = Hash.new
				test_case_hash["name"] = test_case["name"]
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

				Extract_and_Save_File(proj_repo_fullname, ".anacapa/expected_outputs/#{test_case["expected"]["sha1"]}","submit-cs-json", "#{@course_name}/SHA/#{test_case["expected"]["sha1"]}")
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

		puts "Initializing Repo: #{repo_name}"

		proj_repo_fullname =  "#{@course_org}/#{repo_name}"

		if ! Does_Repo_Exist(proj_repo_fullname)	
			begin
				@client.create_repository( repo_name , {  
					:organization => @course_org,
					:private => true
				})	
			rescue Exception => e
				STDERR.puts "WARNING: Unable to CREATE repository #{proj_repo_fullname}"
				STDERR.puts e.message, e.backtrace.inspect

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
			rescue Exception => e
				STDERR.puts "WARNING: Unable to ADD assignment_spec.json"
				STDERR.puts e.message, e.backtrace.inspect

			end
		else

			begin
				@client.update_contents( 
					proj_repo_fullname, 
					".anacapa/assignment_spec.json", 
					"Update Assignment_Spec JSON file for each project repo.",
					old_proj_spec.sha, 
					JSON.pretty_generate(new_proj_spec) )
			rescue Exception => e
				STDERR.puts "WARNING: Unable to UPDATE assignment_spec.json"
				STDERR.puts e.message, e.backtrace.inspect

			end
		end
	end


	def Extract_and_Save_File(proj_repo_fullname, file_path, source_repo, sha_file_path)

		begin
			file_contents = Base64.decode64( @client.contents( "submit-cs-conversion/#{source_repo}",
				:path => "#{sha_file_path}"
				).content )
		rescue 
			STDERR.puts "WARNING: Unable to FIND submit-cs-conversion/#{source_repo}/#{sha_file_path}"
			return
		end


		Create_Or_Update_File(proj_repo_fullname, file_path, file_contents)

	end


	def Create_Or_Update_File_Helper(repo_fullname, file_path, file_contents)


		file = Get_File(repo_fullname, file_path)

		if file == nil
			begin
				@client.create_contents( 
			  		repo_fullname, 
					file_path, 
					"Add #{file_path} in #{repo_fullname}.",
					file_contents)
			rescue Exception => e
				STDERR.puts "WARNING: Unable to ADD #{file_path}."
				STDERR.puts e.message, e.backtrace.inspect
				raise e
			end
		else
			begin
				@client.update_contents( 
					repo_fullname, 
					file_path, 
					"Update #{file_path} in #{repo_fullname}" ,
					file.sha, 
					file_contents)
			rescue Exception => e
				STDERR.puts "WARNING: Unable to UPDATE #{file_path}"
				STDERR.puts e.message, e.backtrace.inspect
				raise e
			end
		end

	end


	def Create_Or_Update_File(repo_fullname, file_path, file_contents)

		num_tries = 0
		max_tries = 3
		done  = false

		while num_tries < max_tries && !done
			begin
				Create_Or_Update_File_Helper(repo_fullname, file_path, file_contents)
				done = true
				if num_tries > 0
					STDERR.puts "SUCCEEDED!"
				end
			rescue
				sleep(0.1)
				num_tries += 1
				if num_tries < max_tries
					STDERR.puts "Retrying..."
				else
					STDERR.puts "GIVING UP!"
				end
			end
		end
	end


	def Get_Course()

		begin
			course_json = JSON.parse( Base64.decode64( @client.contents( 
				"submit-cs-conversion/submit-cs-json",
				:path => "#{@course_name}.json").content))
			return course_json
		rescue  Exception => e
			STDERR.puts "WARNING: Could not GET course at submit-cs-conversion/submit-cs-json/#{@course_name}.json"
			STDERR.puts e.message, e.backtrace.inspect
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


	def Check_Membership()
		if @client.organization_member?(@course_org, @client.user.login)
			return true
		else 
			STDERR.puts "WARNING: #{@client.user.login} is NOT an owner of the organization - " + @course_org
			STDERR.puts "Check that you have an env.sh file with a personal access token that has repo access permission"
			return false
		end
	end


	def Github_User(username)
		begin
			@client.user(username)
			return true
		rescue Exception => e
			STDERR.puts "WARNING: User #{username} is not user on github.ucsb.edu"
			STDERR.puts e.message, e.backtrace.inspect
			return false
		end
	end


	def Add_Collaborator(repo_fullname, username)
		begin
			@client.add_collaborator(repo_fullname, username)
		rescue Exception => e
			STDERR.puts "WARNING: Unable to add #{username} as a collaborator to #{repo_fullname}"
			STDERR.puts e.message, e.backtrace.inspect
		end
	end

end


