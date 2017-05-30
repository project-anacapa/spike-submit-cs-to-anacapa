# spike-submit-cs-to-anacapa
SPIKE of converting submit.cs data into github organization and repos formatted for Anacapa Grader

How to Run:
- Open console and run, extractCourseData.rb
- Type name of course using the folder name on https://github.ucsb.edu/submit-cs-conversion/submit-cs-json, and please confirm that there is infact an organization on https://github.ucsb.edu/ + course, where the course has all "_" changed to "-".  
- If there is not an organization there will be a message sent to the terminal saying, user not part of organization. 
-So an organization will have to be created on https://github.ucsb.edu/ with the naming convention of the course name on https://github.ucsb.edu/submit-cs-conversion/submit-cs-json, but with swapping all underscores with dashes.

NOTE:  There may be some warning messages printed out saying a file was not found, and this is because a sha1 in the course_json to extract from, was not found. 

The file, modifySpec.rb, takes the old course hash and creates a new hash based on the mapping based on the new submit.cs system.
