# spike-submit-cs-to-anacapa
SPIKE of converting submit.cs data into github organization and repos formatted for Anacapa Grader

## How to Run:

**NOTE:** Before running make sure to create an organization on github for the the destination of the course data and make clholoien an owner.

- Clone repository
- Run either:
	- ./processCourse {course_name} {course_org} 
		- To extract the course data from  https://github.ucsb.edu/submit-cs-conversion/submit-cs-json/{course_name}.json, put it into the organization specified by course_org AND add all student submissions to course organization

	- ./processCourse -s {course_name} {course_org}
		- To extract the course data from  https://github.ucsb.edu/submit-cs-conversion/submit-cs-json/{course_name}.json and put it into the organization specified by course_org

	- ./processCourse -a {course_name} {course_org}
		- To add all student submissions to course organization



