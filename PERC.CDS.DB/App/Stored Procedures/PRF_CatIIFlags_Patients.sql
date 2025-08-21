

/*
######################################################################################################################################################
  ____      _     ___ ___   _____ _               ____       _   _            _       
 / ___|__ _| |_  |_ _|_ _| |  ___| | __ _  __ _  |  _ \ __ _| |_(_) ___ _ __ | |_ ___ 
| |   / _` | __|  | | | |  | |_  | |/ _` |/ _` | | |_) / _` | __| |/ _ \ '_ \| __/ __|
| |__| (_| | |_   | | | |  |  _| | | (_| | (_| | |  __/ (_| | |_| |  __/ | | | |_\__ \
 \____\__,_|\__| |___|___| |_|   |_|\__,_|\__, | |_|   \__,_|\__|_|\___|_| |_|\__|___/
                                          |___/                                       
######################################################################################################################################################
######################################################################################################################################################
Object Name:	App.CatIIFlags_Patients
Developer(s):	Williams, Lance
Create Date:	2024-08-14	
Description:	Creates source data to be used in SSRS report for patients with Cat II Flags assigned
Execution:		
######################################################################################################################################################
REVISON LOG:
======================================================================================================================================================
Date		Developer			Description
------------------------------------------------------------------------------------------------------------------------------------------------------
2024-08-14	Williams, Lance		Compiled Procedure
2024-09-24	Williams, Lance		Still in development, not complete
2025-01-15	Williams, Lance		Changed which flag description to use, added date of death, included the SPatient table to be able to pull data on
									test patients. Added case statements for PatientName, SSN, and TestPatientFlag.
######################################################################################################################################################
######################################################################################################################################################
*/

CREATE   PROCEDURE [App].[PRF_CatIIFlags_Patients] 
--****************************************************************************************************************************************************
--*** Parameters that are passed in to the procedure																							   ***
--****************************************************************************************************************************************************
	 @ChecklistID varchar(500)
	,@User varchar(100) 
	,@PtFlag varchar(max)
	,@VISN varchar(500)
--****************************************************************************************************************************************************
		
AS
BEGIN

SET NOCOUNT ON

--****************************************************************************************************************************************************
--*** Creates the table variable to store the facility list																		   ***
--****************************************************************************************************************************************************
DECLARE @FacilityList TABLE (ChecklistID VARCHAR(500))
DECLARE @FlagList TABLE (Flag VARCHAR(max))
DECLARE @VISNList TABLE (VISN VARCHAR(500))

-- Add values to the table variable
INSERT @FacilityList SELECT value FROM string_split(@ChecklistID, ',')
INSERT @FlagList SELECT value FROM string_split(@PtFlag, ',')
INSERT @VISNList SELECT value FROM string_split(@VISN, ',')

--****************************************************************************************************************************************************
--*** Builds the first CTE to gather just the required SIDS and definitions																		   ***
--****************************************************************************************************************************************************
DROP TABLE IF EXISTS #TIUDoc

SELECT
	LocalPatientRecordFlagSID,
	LocalPatientRecordFlagDescription
INTO #TIUDoc
FROM PRF.ActiveCatII_Counts
GROUP BY LocalPatientRecordFlagSID, LocalPatientRecordFlagDescription
--****************************************************************************************************************************************************
--*** Builds the second CTE to gather all required patient and flag information																	   ***
--****************************************************************************************************************************************************
SELECT
	clid.VISN,
	clid.Facility,
	CASE 
		WHEN mp.PatientName is null THEN sp.PatientName
		WHEN mp.PatientName is not null THEN mp.PatientName
	END AS PatientName,	
	CASE 
		WHEN mp.PatientSSN is null THEN Left(sp.PatientSSN,3)+'-'+Substring(sp.PatientSSN,4,2)+'-'+Substring(sp.PatientSSN,6,4)
		WHEN mp.PatientSSN is not null THEN Left(mp.PatientSSN,3)+'-'+Substring(mp.PatientSSN,4,2)+'-'+Substring(mp.PatientSSN,6,4)
	END AS PatientSSN,
	c2p.LocalPatientRecordFlagSID,
	c2p.LocalPatientRecordFlag,	
	tiu.LocalPatientRecordFlagDescription,	
	c2p.LastActionDateTime,	
	c2p.LastAction,	-- We should format this to be a little friendlier to read
	CASE 
		WHEN mp.MVIPersonSID IS NOT NULL THEN mp.DateOfDeath_Combined 
		ELSE sp.DeathDateTime 
	END AS DateOfDeath_Combined,
	CASE
		WHEN mp.PossibleTestPatient = 1 THEN 'Y'
		WHEN mp.TestPatient = 1 THEN 'Y'
		WHEN sp.TestPatientFlag ='Y' THEN 'Y'
		ELSE 'N'
	END AS PossibleTestPatient
FROM
	PRF.ActiveCatII_Patients  AS c2p WITH (NOLOCK)  -- We will need all the data from this table, but some will only be for joining purposes
	-- Pulls in the patient data
		LEFT JOIN Common.MasterPatient AS mp WITH (NOLOCK) ON (c2p.MVIPersonSID = mp.MVIPersonSID)
	--Pulls in the facility data
		JOIN [LookUp].ChecklistID AS clid WITH (NOLOCK) ON (c2p.OwnerChecklistID = clid.ChecklistID)
	--Pulls in the TIU Definitions
		JOIN #TIUDoc AS tiu WITH (NOLOCK) ON (c2p.LocalPatientRecordFlagSID = tiu.LocalPatientRecordFlagSID)
	--Pulls in info on test patients
		LEFT JOIN SPatient.SPatient as sp WITH (NOLOCK) ON (c2p.PatientSID = sp.PatientSID)
	-- Checks to see what stations a user has access
		INNER JOIN (SELECT Sta3n from [App].[Access] (@User)) as acs on LEFT(clid.ChecklistID,3) = acs.sta3n
		INNER JOIN @VISNList as v ON v.VISN = clid.VISN
		INNER JOIN @FacilityList as fc ON fc.ChecklistID = clid.ChecklistID
		INNER JOIN @FlagList as fid ON fid.Flag = c2p.LocalPatientRecordFlag
--****************************************************************************************************************************************************
END
--######################################################################################################################################################
--### END OF PROCEDURE																																 ###
--######################################################################################################################################################