# spike-submit-cs-to-anacapa
SPIKE of converting submit.cs data into github organization and repos formatted for Anacapa Grader

This no longer is just a spike but rather a fully working edition of the course extraction from the old submit system to the new anacapa system.

##How to Run:
**NOTE:** Before running make sure to create an organization on github for the the destination of the course data.

- Open console and run, processCourse.rb
- Give response to the first promt of the course given the format found on https://github.ucsb.edu/submit-cs-conversion/submit-cs-json, and press enter.
- Give the destination organization name for the course, and press enter.  There will be a warning and the program will exit, if the organization does not exist.
- There may be warnings of files that were not found.  This is from the sha1 files given in the https://github.ucsb.edu/submit-cs-conversion/submit-cs-json old course json is requesting files that were not found in the SHA folder in course/SHA.
- At the end there will be a message printed out regarding if the course was processed successfully or not.


**NOTE:**  There may be some warning messages printed out saying a file was not found, and this is because a sha1 in the course_json to extract from, was not found. 

**Files:**
- extractCourseDataWrapper.rb: is a wrapper around the octokit function calls and primarily is the file that holds the most weight for this task.  

- modifySpec.rb: takes the old course hash and creates a new hash based on the mapping based on the new submit.cs system.

- processCourse.rb: has the commandline interface and makes calls to the wrapper file.

