Oomnitza -> JSS Sync App

**This is now deprecated since we no longer use Oomnitza**

v1, 03-02-2015

This app will sync changes made in Oomnitza to JSS (JAMF/Casper). It is designed to be run as a cron job. 

+ Gems required: HTTParty, dotenv
+ Ruby version 2.3 minimum required.

When run it will:

+ DELETE computers FROM JSS when they are marked as "decommissioned" in Oomnitza
+ UNASSIGN computers IN JSS that are NOT assigned to a user in Oomnitza


The app outputs it's actions into a few logs: 

+ o2j_full.log - This is the full output of the program.  It will keep the last 6 logs and cycle them at 50MB
+ o2j_missing_in_jss.log - This shows what is missing in JSS and what it's state is in Oomnitza (if it is not decommisioned, it is bad)
+ o2j_deleted_from_jss.log - This lists all computers deleted from JSS.  This log is never replaced. 
+ o2j_unassigned_in_jss.log - This lists all computers that had their users changed to UNASSIGNED in JSS. 

