/*******************************************************************************
TITLE: hash_pii_java.ado
AUTHOR(S): Daniel Cohen 
DESCRIPTION: Defines function to generate SHA-256 hashes from email 
             addresses (in Java). 
SOURCE: https://www.statalist.org/forums/forum/general-stata-discussion/
        general/1664054-sha256-hashing-function-in-stata
DATE LAST MODIFIED: APR 2024
FILE(S) USED: N/A
*******************************************************************************/

/*******************************************************************************
define Stata function that can be called in pre_build.do.
*******************************************************************************/

cap program drop hash_pii_java
program hash_pii_java
	version 17
	args amerispeak_id 
	
	java: hash_all(`amerispeak_id');
end 

/*******************************************************************************
write java back-end code for actual hashing.
*******************************************************************************/

java: 

import com.stata.sfi.*;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.nio.charset.StandardCharsets;
import java.math.BigInteger;

MessageDigest md = MessageDigest.getInstance("SHA-256");

void hash_all(int amerispeak_id) {
	if (amerispeak_id == 1) {
		hash("amerispeak_id", "amerispeak_id_hashed");
	}
}

void hash(String VarName, String VarNameSHA256) {
	Integer orgstrvar = Data.getVarIndex(VarName);
	Integer newstrvar = Data.getVarIndex(VarNameSHA256);
	
	for (long n = 1;  n <= Data.getObsTotal(); n++) {

		String text = Data.getStr​(orgstrvar,n);
				
		md.update(text.getBytes(StandardCharsets.UTF_8));
		byte[] digest = md.digest();
		
		Data.storeStrf​(newstrvar, n, String.format("%064x", new BigInteger(1, digest)));
	}
}

end 

