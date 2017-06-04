# spike-submit-cs-to-anacapa
SPIKE of converting submit.cs data into github organization and repos formatted for Anacapa Grader

## How to Run:

**NOTE:** Before running make sure to create an organization on github for the the destination of the course data and make clholoien an owner.

- Clone repository
- Run either:
	- ./processCourse {course_name} {course_org} 
		- To extract the course data from  https://github.ucsb.edu/submit-cs-conversion/submit-cs-json/{course_name}.json and put it into the organization specified by course_org.  
		- This way of calling ./processCourse will NOT add student submissions to course organization

	- ./processCourse -s {course_name} {course_org}
		- To do the same as above except it will add all student repos.



