version 17

/*******************************************************************************
TITLE: pre_build.do
AUTHOR(S): Daniel Cohen 
DESCRIPTION: Reads in raw SSB survey data and removes PII & unnecessary fields. 
DATE LAST MODIFIED: APR 2024
FILE(S) USED: 
    - [ssb/input/data_with_PII/FB Full Launch/] survey1_fulllaunch.csv
    - [ssb/input/data_with_PII/FB Full Launch/] survey2_fulllaunch.csv
*******************************************************************************/

clear all

/*******************************************************************************
Hash email addresses so they can be used for linking later w/o PII.

FUNC NAME: hash_PII
FUNC ARGUMENT(S): N/A
FUNC RESULT(S): Hashes email addresses. 
*******************************************************************************/

capture program drop hash_PII
program define hash_PII
	syntax, email(int) phone(int)
	
	if (`email' == 1) {
		* convert email to lowercase for hashing 
		replace contactemail = lower(contactemail)
		
		* generate new variables to store hashed email 
		gen str64 contactemail_hashed = ""
	}
	
	if (`phone' == 1) {
		* convert phone # to digits-only for hashing 
		moss contactphone, match("([0-9]+)") regex
		replace contactphone = _match1 + _match2 + _match3
		
		* generate new variables to store hashed email 
		gen str64 contactphone_hashed = ""
	}

	* conduct SHA-256 hashing in Java
	
	hash_pii_java `email' `phone'
	
end


/*******************************************************************************
Run functions on Part 1 data and export resulting dataset. 
*******************************************************************************/

cap program drop clean_anonymize_part1_data
program define clean_anonymize_part1_data

	* import data 
	import delimited "$rootdir/ssb/input/data_with_PII/FB Full Launch/survey1_fulllaunch.csv", ///
	clear varnames(1) bindquotes(strict)

	* drop the two extra rows on the csv (there may be a way to do this when 
	* exporting from qualtrics)
	drop in 1/2

	* remove any survey previews that may have made it through
	drop if status == "Survey Preview"

	* hash PII (both email and phone)
	hash_PII, email(1) phone(1)

	* remove unnecessary metadata fields 
	drop startdate status ipaddress durationinseconds recordeddate ///
		 responseid recipientlastname recipientfirstname recipientemail ///
		 externalreference locationlatitude locationlongitude ///
		 distributionchannel userlanguage q_recaptchascore q_relevantidduplicate ///
		 q_relevantidduplicatescore q_relevantidfraudscore ///
		 q_relevantidlaststartdate consent us_address firstname email ///
		 phone address_* targetage targeteduc source contactemail contactphone ///
		 part1paymentamount _count _match* _pos*

	* export semi-processed data 
	qui compress
	save "$rootdir/ssb/input/survey1", replace

end 

clean_anonymize_part1_data


/*******************************************************************************
Run functions on Part 2 data and export resulting dataset. 
*******************************************************************************/

cap program drop clean_anonymize_part2_data
program define clean_anonymize_part2_data

	* import data 
	import delimited "$rootdir/ssb/input/data_with_PII/FB Full Launch/survey2_fulllaunch.csv", ///
	clear varnames(1)

	* drop the two extra rows on the csv (there may be a way to do this when 
	* exporting from qualtrics)
	drop in 1/2

	* remove any survey previews that may have made it through
	drop if status == "Survey Preview"

	* hash PII (just email address since phone # not collected in part 2)
	hash_PII, email(1) phone(0)

	* drop response from one identified bot 
	drop if contactemail_hashed == "bac82438ac810b8377e7440be452a0215ecb48208a20d2434ff7d860ddbc95ef"

	* remove unnecessary metadata fields 
	drop startdate status ipaddress durationinseconds recordeddate ///
		 responseid recipientlastname recipientfirstname recipientemail ///
		 externalreference locationlatitude locationlongitude ///
		 distributionchannel userlanguage hunt_version thanks q954 ship_* ///
		 randomseed contactemail ship shipprob email mturkcode

	* export semi-processed data 
	qui compress
	save "$rootdir/ssb/input/survey2", replace

end 

clean_anonymize_part2_data

