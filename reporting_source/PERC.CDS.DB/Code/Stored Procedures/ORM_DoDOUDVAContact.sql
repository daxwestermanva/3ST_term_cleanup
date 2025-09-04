

/********************************************************************************************************************
DESCRIPTION: Create past and future appt table to use for all projects. Most recent visit in VA for DoD OUD cohort.
AUTHOR:		 Tolessa Gurmessa
CREATED:	 02/14/2024
This code is adopted from [Code].[Present_Appointments] 
							
********************************************************************************************************************/
CREATE PROCEDURE [Code].[ORM_DoDOUDVAContact] 
AS
BEGIN

---------------------------------
-- Create vertical lookup table for stop codes
---------------------------------
DROP TABLE IF EXISTS #LookUp_StopCode
CREATE TABLE #LookUp_StopCode (
	StopCodeSID bigint
	,StopCode varchar(100)
	,StopCodeName varchar(100)
	,ApptCategory varchar(25)
	,Flag BIT
	,Sta3n smallint
	)
INSERT INTO #LookUP_StopCode
SELECT StopCodeSID
	  ,StopCode
	  ,StopCodeName
	  ,ApptCategory
	  ,Flag
	  ,Sta3n
FROM (
	SELECT StopCodeSID
		  ,StopCode
		  ,StopCodeName
		  ,Sta3n
		  ,AnyRecentED			= CAST(1 as smallint) --Any Past Appt including urgent care and ED
		  ,AnyRecent			= Any_Stop --PastAppt (ANY) --Excludes Emergency Dept and Urgent Care
		  ,EDRecent				= EmergencyRoom_Stop --Emergency Dept and Urgent Care --ED and UC -- EmergencyRoom_Stop = 1 also includes 102	ADMITTING/SCREENING
		  ,ClinRelevantRecent	= ClinRelevant_Stop --PAST APPT Clinically Relevant (includes hand picked relevant appts)
		  ,PCRecent				= PC_Stop --PAST APPT Primary Care
		  ,PainRecent			= Pain_Stop --PAST APPT Pain Clinic
		  ,MHRecent				= MHOC_MentalHealth_Stop --PAST APPT MH Specialty
		  ,HomelessRecent		= MHOC_Homeless_Stop
		  ,PeerRecent			= PeerSupport_Stop
		  ,OtherRecent			= Other_Stop --PAST APPT Other (non-MH, PC, or Pain) /*these match, but might not match intention*/
	FROM [LookUp].[StopCode] WITH(NOLOCK)
	) lkup
UNPIVOT (Flag FOR ApptCategory IN (AnyRecentED		
								   ,AnyRecent			
								   ,EDRecent				
								   ,ClinRelevantRecent	
								   ,PCRecent				
								   ,PainRecent			
								   ,MHRecent
								   ,HomelessRecent
								   ,PeerRecent
								   ,OtherRecent	)
	) upvt
WHERE Flag=1

--Align ED definition with original code
DELETE #LookUp_StopCode WHERE ApptCategory='EDRecent' AND StopCode=102
--Don't use stop codes for Cerner MH visits
DELETE #Lookup_StopCode WHERE Sta3n = 200 AND ApptCategory IN ('MHRecent','HomelessRecent')

CREATE CLUSTERED INDEX CIX_LookUpStop ON #LookUp_StopCode (StopCodeSID)

-----------------------------------
--Cerner Activity types - use for visits
--------------------------------
/*MHOC MH, MHOC Homeless, MHOC GMH, MHOC HBPC, MHOC PTSD, MHOC PCT, MHOC SUD, MHOC TSES, MHOC PRRC, MHOC MHICM, MHOC PCMHI, MHOC RRTP, Reach_Homeless, 
Reach_MH, MHRecent (STORM), WHole Health
*/
DROP TABLE IF EXISTS #LookUp_ActivityTypesMill
CREATE TABLE #LookUp_ActivityTypesMill (
	 ItemID bigint
	,AttributeValue varchar(100)
	,List varchar(100)
	,ApptCategory varchar(25)
	,Flag BIT
	)
INSERT INTO #LookUp_ActivityTypesMill
SELECT ItemID
	  ,AttributeValue
	  ,List
	  ,ApptCategory
	  ,Flag
FROM (
	SELECT ItemID
		  ,AttributeValue
		  ,List
		  ,AnyRecentED			= 1--CAST(1 as smallint) --Any Past Appt including urgent care and ED
	    --,AnyRecent			= AnyRecent_Stop --PastAppt (ANY) --Excludes Emergency Dept and Urgent Care --ED and urgent care from utulization table
	    --,EDRecent			= EmergencyRoom_Stop --Emergency Dept and Urgent Care --ED and UC -- EmergencyRoom_Stop = 1 also includes 102	ADMITTING/SCREENING
	    --,ClinRelevantRecent	= ClinRelevantRecent_Stop --PAST APPT Clinically Relevant (includes hand picked relevant appts) -- still need these defined
	    --,PCRecent			= PCRecent_Stop --PAST APPT Primary Care --still need defined
	    --,PainRecent			= PainRecent_Stop --PAST APPT Pain Clinic --still need defined
	      ,MHRecent				= CASE WHEN List = 'MHOC_MH' THEN 1 ELSE 0 END--PAST APPT MH Specialty --s
		  ,HomelessRecent		= CASE WHEN List = 'MHOC_Homeless' THEN 1 ELSE 0 END
	    --,OtherRecent		= OtherRecent_Stop --still need defined
	FROM [LookUp].[ListMember] WITH(NOLOCK)
	WHERE Domain = 'ActivityType' 
	) lkup
UNPIVOT (Flag FOR ApptCategory IN (AnyRecentED		
								   --,AnyRecent			
								   --,EDRecent				
								   --,ClinRelevantRecent	
								   --,PCRecent				
								   --,PainRecent			
								   ,MHRecent	
								   ,HomelessRecent)			
								   --,OtherRecent	)
	) upvt
WHERE Flag=1

---------------------------------
-- PAST OUTPATIENT VISITS
---------------------------------
	DROP TABLE IF EXISTS #VistaSIDs
	SELECT 
		 v.MVIPersonSID
		,v.PatientSID
		,v.VisitSID
		,v.VisitDateTime
		,v.Sta3n
		,v.PrimaryStopCodeSID
		,v.SecondaryStopCodeSID
		,v.DivisionSID
	INTO #VistaSIDs
	FROM [App].[vwOutpatWorkload_StatusShowed] v WITH(NOLOCK)
	INNER JOIN SUD.Cohort AS s 
	  ON v.MVIPersonSID = s.MVIPersonSID AND OUD_DoD = 1


	DROP TABLE IF EXISTS #PastAppointmentVista;
	SELECT
		 v.MVIPersonSID
		,v.PatientSID
		,v.VisitSID
		,v.VisitDateTime
		,v.Sta3n
		,d.ChecklistID
		,a.StopCode AS PrimaryStopCode
		,a.StopCodeName AS PrimaryStopCodeName
		,b.StopCode AS SecondaryStopCode
		,b.StopCodeName AS SecondaryStopCodeName
		,CASE WHEN b.ApptCategory IN ('MHRecent','HomelessRecent','PainRecent','PCRecent','PeerRecent','EDRecent') 
			THEN b.ApptCategory ELSE a.ApptCategory END AS ApptCategory
	INTO #PastAppointmentVista
	FROM #VistaSIDs v WITH(NOLOCK)
	INNER JOIN #LookUp_StopCode AS a WITH(NOLOCK) on a.StopCodeSID=v.PrimaryStopCodeSID
	LEFT JOIN #LookUp_StopCode AS b WITH(NOLOCK) on b.StopCodeSID=v.SecondaryStopCodeSID
	LEFT JOIN [LookUp].[DivisionFacility] d WITH(NOLOCK) on v.DivisionSID=d.DivisionSID

	DELETE FROM #PastAppointmentVista
	WHERE SecondaryStopCode = '697'

	DROP TABLE IF EXISTS #VistaSIDs;
---------------------------------
-- Cerner PAST OUTPATIENT VISITS
---------------------------------


	DROP TABLE IF EXISTS #PastAppointmentMill
	SELECT 
		 c.MVIPersonSID
		,c.PersonSID
		,c.EncounterSID
		,c.TZDerivedVisitDateTime
		,ch.ChecklistID
		,c.Location
		,ActivityType=a.AttributeValue
		,ActivityTypeCodeValueSID=a.ItemID
		,sc.StopCode
		,sc.StopCodeName
		,c.EncounterType
		,c.MedicalService
		,c.UrgentCareFlag as UrgentCare
		,c.EmergencyCareFlag as EmergencyCare
		,CASE WHEN c.UrgentCareFlag = 1 or c.EmergencyCareFlag = 1 then 'EDRecent'
		 WHEN c.UrgentCareFlag <> 1 and c.EmergencyCareFlag <> 1 and a.ApptCategory IN ('MHRecent','HomelessRecent') then a.ApptCategory
			  ELSE sc.ApptCategory END VisitCategory
		,ISNULL(a.ApptCategory,sc.ApptCategory) AS ApptCategory --for validation
	INTO #PastAppointmentMill
	FROM [Cerner].[FactUtilizationOutpatient] c WITH(NOLOCK)
	INNER JOIN SUD.Cohort AS s 
	  ON c.MVIPersonSID = s.MVIPersonSID AND OUD_DoD = 1
	INNER JOIN [LookUp].[ChecklistID] ch WITH (NOLOCK)
		ON c.StaPa = ch.StaPa
	LEFT JOIN #LookUp_ActivityTypesMill as a 
		ON a.ItemID = c.ActivityTypeCodeValueSID
	LEFT JOIN (SELECT usc.EncounterSID, lsc.StopCode, lsc.StopCodeName, lsc.ApptCategory 
				FROM [Cerner].[FactUtilizationStopCode] usc WITH (NOLOCK)
				INNER JOIN #LookUp_StopCode lsc
				ON lsc.StopCodeSID = usc.CompanyUnitBillTransactionAliasSID) sc
		ON c.EncounterSID = sc.EncounterSID
	WHERE sc.StopCode IS NOT NULL OR c.ActivityType IS NOT NULL


	--Combine Vista and Mill
	DROP TABLE IF EXISTS #PastAppointment
	SELECT DISTINCT p.*
	INTO #PastAppointment 
	FROM (
		SELECT MVIPersonSID
		  ,PatientSID
		  ,VisitSID
		  ,VisitDateTime
		  ,Sta3n
		  ,ChecklistID
		  ,PrimaryStopCode
		  ,PrimaryStopCodeName
		  ,SecondaryStopCode
		  ,SecondaryStopCodeName
		  ,ActivityType=CAST(NULL as varchar)
		  ,ActivityTypeCodeValueSID=CAST(NULL as int)
		  ,ApptCategory
		  ,MostRecent_SID=ROW_NUMBER() OVER(PARTITION BY PatientSID,ApptCategory ORDER BY VisitDateTime DESC)
		FROM #PastAppointmentVista v
			UNION ALL 
		SELECT c.MVIPersonSID
		  ,c.PersonSID
		  ,c.EncounterSID
		  ,c.TZDerivedVisitDateTime
		  ,Sta3n = 200
		  ,c.ChecklistID 
		  ,PrimaryStopCode=StopCode
		  ,PrimaryStopCodeName=StopCodeName
		  ,SecondaryStopCode=CAST(NULL as varchar)
		  ,SecondaryStopCodeName=CAST(NULL as varchar)
		  ,c.ActivityType
		  ,c.ActivityTypeCodeValueSID
		  ,c.VisitCategory as ApptCategory
		  ,MostRecent_SID=ROW_NUMBER() OVER(PARTITION BY PersonSID,ChecklistID,VisitCategory ORDER BY TZDerivedVisitDateTime DESC)
		FROM #PastAppointmentMill c
		) as p
		WHERE MostRecent_SID=1

	DROP TABLE IF EXISTS #PastAppointmentMill
	DROP TABLE IF EXISTS #PastAppointmentVista;

	/**********************************************Flag Most Recent*************************************************/		
	DROP TABLE IF EXISTS #MostRecentVisits;
	SELECT DISTINCT MVIPersonSID
		,VisitDateTime
		,Sta3n
		,MostRecent_ICN
		,ChecklistID
	INTO #MostRecentVisits
	FROM (
		SELECT MVIPersonSID
			  ,VisitDateTime
			  ,Sta3n
			  ,MostRecent_ICN=ROW_NUMBER() OVER(PARTITION BY MVIPersonSID ORDER BY VisitDateTime DESC)
			  ,ChecklistID
		FROM #PastAppointment
		) a
	WHERE  MostRecent_ICN=1

EXEC [Maintenance].[PublishTable] 'ORM.DoDOUDVAContact','#MostRecentVisits'

DROP TABLE IF EXISTS #PastAppointment;


END