

# returns the new assignment spec json given the assignment spec
def Modify_Spec(proj_repo_fullname, old_hash)

	# puts "Modify_Spec"
	expected_sha_files = Array.new
	execution_sha_files = Array.new
	build_sha_files = Array.new
	new_hash = Hash.new

	#Assignment Name
	new_hash["assignment_name"] = old_hash["name"]
	#Deadline
	new_hash["deadline"] = Time.now.strftime("%Y-%m-%dT21:33:00-08:00")
	
	#Group Size
	new_hash["maximum_group_size"] = old_hash["group_max"]

	if old_hash.key?("status")
		#Ready
		if old_hash["status"] == "ready"
			new_hash["ready"] = true
		else
			new_hash["ready"] = false
		end
	else
		new_hash["ready"] = false
	end

	#Starter Repo ?
	# new_hash["starter_repo"] = proj_repo_fullname
	new_hash["expected_files"] = Array.new
	#Testables
	new_hash["testables"] = Array.new

	for testable in old_hash["testables"]

		testable_hash = Hash.new

		#Testname
		testable_hash["test_name"] = testable["name"]
		
		#Executable
		if testable["make_target"] != nil
			testable_hash["build_command"] = "make " + testable["make_target"]
		end
		
		#Execution Files
		for file in testable["execution_files"]
			execution_sha_files << file["sha1"]
		end

		for file in testable["build_files"]
			build_sha_files << file["file_hex"]
		end

		for file in testable["expected_files"]
			if ! new_hash["expected_files"].include? file["name"]
				new_hash["expected_files"] << file["name"]
			end
		end

		#Test Cases
		testable_hash["test_cases"] = Array.new
		for test_case in testable["test_cases"]
			test_case_hash = Hash.new

			#Command
			test_case_hash["command"] = test_case["args"]
			#Diff source
			test_case_hash["diff_source"] = test_case["source"]

			# if test_case.key?("")
			# 	test_case_hash["expected"] = 
			# else 
			test_case_hash["expected"] = test_case["expected"]["sha1"]
			# end
			#Hide Expected
			if test_case.key?("hide_expected")
				test_case_hash["hide_expected"] = test_case["hide_expected"]
			else
				test_case_hash["hide_expected"] = false
			end
			#Kind
			test_case_hash["kind"] = test_case["output_type"]
			#Points
			if test_case.key?("points")
				test_case_hash["points"] = test_case["points"]
			else
				test_case_hash["points"] = 100
			end
			#Timeout
			if test_case.key?("timeout")
				test_case_hash["timeout"] = test_case["timeout"]
			end
			#Add Test Case
			testable_hash["test_cases"] << test_case_hash
			#Add expected output file
			expected_sha_files << test_case["expected"]["sha1"]
		end

		new_hash["testables"] << testable_hash
	end

	return new_hash, execution_sha_files, expected_sha_files, build_sha_files

end


