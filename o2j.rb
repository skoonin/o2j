# Oomnitza -> JSS Sync App
# by shawnk
#
# v1, 03-2017
#
# This app will either: 
# + for computers "decommissioned" in Oomnitza it will delete that computer from JSS
# + for computers that are NOT assigned to a user in Oomnitza, they will have their assigned user in JSS changed to "unassigned"
#


require 'HTTParty'
require 'logger'
require 'dotenv/load'

puts "Running o2j sync, please wait this may take a few minutes. Results will be shown once complete and logged."

# logging options
o2j_log = Logger.new("o2j_full.log", 6, 50240000)
o2j_log.datetime_format = '%Y-%m-%d %H:%M:%S'
o2j_log.formatter = proc do |severity, datetime, progname, msg|
   "#{datetime} -- :  #{msg}\n"
end

#logging variables
missing_in_jss = []
unassigned_in_jss = []
deleted_from_jss = []
assigned_in_oomnitza = []
unassigned_in_oomnitza = []
decommissioned_in_oomnitza = []
not_computer = []


# primary variables
jss_base_api_url = "https://jss.tumblrhq.com:8443/JSSResource"
jss_auth = {username: ENV['jss_auth_username'], password: ENV['jss_auth_pwd'] }

om_api_url = "https://tumblr.oomnitza.com/api/v3"
om_api_key = ENV['om_api_key']
om_auth_header = { Authorization2: om_api_key }
om_asset_fields = "serial_number,status,asset_type"


# Get all assets from Oomnitza (JSON) to get total count and set iterate variable
om_assets = HTTParty.get("#{om_api_url}/assets?fields=#{om_asset_fields}", headers: om_auth_header)
total_count = om_assets.headers['x-total-count'].to_i
current_count = 0

o2j_log.info{ "==================================================================================================================" }
o2j_log.info{ "Begining o2j (oomnitiza to jss) sync." }
o2j_log.info{ "==================================================================================================================" }

# get assets from oomnitza, skipping previous 100

o2j_log.info{ "Getting assets from Oomnitza and syncing with JSS." }

while current_count < total_count
	
	om_assets = HTTParty.get("#{om_api_url}/assets?fields=#{om_asset_fields}&SKIP=#{current_count}", headers: om_auth_header)
	
	#create variables and loop over 
	om_assets.each do |asset|
		serialnumber = asset["serial_number"]
		status = asset["status"]
		asset_type = asset["asset_type"]

		# setting the variables needed for logging
		logging_asset_fields = [ serialnumber, status, asset_type ]

		# Get Serial Number Asset from JSS (computer)
		if asset_type  == "Laptop" || asset_type == "Desktop"
			jss_asset = HTTParty.get("#{jss_base_api_url}/computers/serialnumber/#{serialnumber}", verify: false, basic_auth: jss_auth)
			# check if JSS returns a computer, if not mark it appropriately in the logs. 
			if jss_asset.code == 404													
				if status == "Decommissioned"
					o2j_log.info{ "#{serialnumber} is decommissioned in Oomnitza, but has already been deleted from JSS" }
					missing_in_jss << logging_asset_fields
					decommissioned_in_oomnitza << logging_asset_fields
				else
					if status == "Assigned"
						o2j_log.warn{ "WARN: #{serialnumber} is not in JSS BUT is ASSIGNED Oomnitza (this is potentially bad)" }
						missing_in_jss << logging_asset_fields
					else
						o2j_log.warn{ "WARN: #{serialnumber} is not in JSS and is NOT DECOMMISSIONED in Oomnitza (this is potentially bad)" }
						unassigned_in_oomnitza << logging_asset_fields
						missing_in_jss << logging_asset_fields
					end
				end
			# if computer is in JSS, do the thing you should do and log it
			else jss_asset.code == 200
				if jss_asset.dig('computer','location','username').nil?
					jss_username = "Username Not found"
				else
					jss_username = jss_asset.dig('computer','location','username')
				end
				if status == "Assigned"
					o2j_log.info { "#{serialnumber} is assigned, no action needed" }
					assigned_in_oomnitza << logging_asset_fields 
				elsif status == "Decommissioned"
					o2j_log.info{ "#{serialnumber} is decommissioned in Oomnitza and will be deleted" }
					decommissioned_in_oomnitza << logging_asset_fields
					HTTParty.delete("#{jss_base_url}/computers/serialnumber/#{serialnumber}", verify: false, basic_auth: jss_auth)
					deleted_from_jss << logging_asset_fields
					o2j_log.info{ "--> UPDATE: #{serialnumber} is now deleted from JSS." }						
				else status != "Assigned"
					o2j_log.info{ "#{serialnumber} is NOT assigned in Oomnitza" }
					unassigned_in_oomnitza << logging_asset_fields
					#check if it is unassigned in jss already, if not then unassign it.
					if jss_username == "Unassigned"
						o2j_log.info{ "--> NO-UPDATE: #{serialnumber} is already unassigned in JSS." }
					else
						HTTParty.put("#{jss_base_url}/computers/serialnumber/#{serialnumber}", 
			 					body: "<computer>x<location><username>Unassigned</username><realname>Unassigned</realname><real_name>Unassigned</real_name><department></department></location></computer>", 
			 					headers: { 'Content-Type' => 'text/xml' }, 
			 					verify: false, basic_auth: jss_auth)
				 		o2j_log.info{ "--> UPDATE: #{serialnumber} is now unassigned in JSS." }
						unassigned_in_jss << logging_asset_fields
					end
				end
			end
		else
			if serialnumber.to_s.length < 1
				o2j_log.warn{ "WARN: This is not a computer. It is actually a #{asset_type} and will be skipped. It is also missing a serial number." }
				not_computer << serialnumber
			else
				o2j_log.info{ "SN: #{serialnumber} is not a computer. It is actually a #{asset_type} and will be skipped." }
				not_computer << serialnumber
			end
		end
	end
	current_count+=100 #due to oomnitza API limit of 100 records per request


end

# Full Run results here. 
o2j_log.info{ "" }
o2j_log.info{ "::::: RESULTS :::::" }
o2j_log.info{ "#{assigned_in_oomnitza.count} assigned from Oomnitza, no action taken" }
o2j_log.info{ "#{decommissioned_in_oomnitza.count} decommissioned in Oomnitza" }
o2j_log.info{ "#{unassigned_in_oomnitza.count} unassigned in Oomnitza" }
o2j_log.info{ "#{deleted_from_jss.count} were deleted from JSS" }
o2j_log.info{ "#{missing_in_jss.count} missing from JSS, already deleted" }
o2j_log.info{ "#{unassigned_in_jss.count} were unassigned in JSS" }
o2j_log.info{ "#{not_computer.count} were not computers" }
o2j_log.info{ "#{total_count} total assets processed" }
o2j_log.info{ "::::: END :::::" }
o2j_log.info{ "" }

# export results to separate log files
	
# missing in jss log
	missing_log = Logger.new("o2j_missing_in_jss.log", 'weekly')
	missing_log.datetime_format = '%Y-%m-%d %H:%M:%S'
	missing_log.formatter = proc do |severity, datetime, progname, msg|
   		"#{datetime} -- :  #{msg}\n"
	end
	
	missing_log.info{ "================================================" }
	missing_log.info{ "[ Not found in JSS ]" }
	missing_in_jss.each { |serialnumber, status, asset_type| missing_log.info{ "Serial Number (#{serialnumber}) was not in JSS, but it was in Oomnitza and marked as (#{status})" } }
o2j_log.info{ "EXPORTED: o2j_missing_in_jss.log" }

# deleted from jss log
	deleted_log = Logger.new("o2j_deleted_from_jss.log", 0, 50240000)
	deleted_log.datetime_format = '%Y-%m-%d %H:%M:%S'
	deleted_log.formatter = proc do |severity, datetime, progname, msg|
   		"#{datetime} -- :  #{msg}\n"
	end
	
	deleted_log.info{ "================================================" }
	deleted_log.info{ "[ Deleted from JSS ]" }
	deleted_from_jss.each { |serialnumber, status, asset_type| missing_log.info{ "Serial Number (#{serialnumber}) was removed from JSS" } }
o2j_log.info{ "EXPORTED: o2j_deleted_from_jss.log" }

	
# unassigned in jss log
	unassigned_log = Logger.new("o2j_unassigned_in_jss.log", 'weekly')
	unassigned_log.datetime_format = '%Y-%m-%d %H:%M:%S'
	unassigned_log.formatter = proc do |severity, datetime, progname, msg|
   		"#{datetime} -- :  #{msg}\n"
	end
	
	unassigned_log.info{ "================================================" }
	unassigned_log.info{ "[ Deleted from JSS ]" }
	unassigned_in_jss.each { |serialnumber, status, asset_type| unassigned_log.info{ "Serial Number (#{serialnumber}) was unassigned in JSS" } }
o2j_log.info{ "EXPORTED: o2j_unassigned_in_jss.log" }

o2j_log.info{ "o2j sync complete." }


# Full Run results to print to console. 
puts ""
puts "::::: RESULTS :::::" 
puts "#{assigned_in_oomnitza.count} assigned from Oomnitza, no action taken" 
puts "#{decommissioned_in_oomnitza.count} decommissioned in Oomnitza" 
puts "#{unassigned_in_oomnitza.count} unassigned in Oomnitza" 
puts "#{deleted_from_jss.count} were deleted from JSS" 
puts "#{missing_in_jss.count} missing from JSS, already deleted" 
puts "#{unassigned_in_jss.count} were unassigned in JSS" 
puts "#{not_computer.count} were not computers" 
puts "#{total_count} total assets processed" 
puts "::::: END :::::" 
puts "o2j sync complete. Please enjoy."
puts ""
