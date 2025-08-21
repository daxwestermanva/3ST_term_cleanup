
-- ==========================================================================================
-- Authors:		Catherine Barry, Grace Chung
-- Create date: 12/14/2023
-- Description: eCSRE1 for Oracle Health (CERNER) site tool
--				Includes: All positive C-SSRS in the past 6 months from today's date, including facility, namelocation and date/time; and a CSRE within 24 hours, if it exists
--				Created because Oracle Health (CERNER sites) do not currently have a tool that identifies info for eCSRE1 (RM MIRECC tool is only available for VistA sites as of FY23Q4)
--			NOTE: This output will  NOT exactly match the results in the eCSRE1 metric because the METRIC IDENTIFIES FACILITY BASED ON HOMESTATION;	CNB validated this
--Modifications:
--				2024-12-12 CNB updated to refine CSRE data pull and joins
--				2024-02-08 CNB updated to view past 1 month of data
--              2024-02-27	GC change csre.healthfactordatetime from varchar to smalldatetime format for report data type consistency 
--				2024-04-12 CNB	Update to include location details
--              2024-04-22  GC  Added EDIPI column to report 
--              2024-04-23  GC  Updated location source and added EncounterTypeClass and Encountersid
--              2024-05-09  GC Added patient DOB column 
--				2024-05-09	CNB updated Veteran query to use PriorityGroup (matches other CDS/Measure requirements) instead of Veteran
--              2024-05-14  GC  Added unauthenticate cases for the new sub report 
--				2024-05-20  CNB Add location and encounterclass to the unauthenticated sub report
--              2024-05-22  GC Added PatientICN to unauthenticated 
--				2024-06-14	CNB Updated timeframe to past 6 months to align with changes in RM MIRECC's data view to past 6 months
--              2024-07-03  GC  Updated six months back logic to getdate()-183 instead 
--              2024-09-23  GC Commented out unauthenticated forms section because both authenticated and unauthenticated forms will be in the same file 
--				2024-11-14	CNB	Updated code related to w/in 24 hours and >24 hours; the date diff hh code was rounding oddly; now use minutes (24 hours = 1440 minutes)
--				2025-02-19	CNB Updated code to include and identify 'Unable to Screen' a new option to the CSRE Powerform as of 2/11/25. Note that these will be metric fallouts. 
--              2025-03-12  GC  Include non-veterans in the report 
--              2025-03-17  GC  Update Non-Veteran value to "Other" 
--              2025-04-22  GC  Exclude test patients from Common.MasterPatient
-- ==========================================================================================

CREATE PROCEDURE [Code].[OracleH_QI_CSRE1PatientInfo]

AS
BEGIN

--Step 1: Find all completed C-SSRS results in timeframe

--Update to include location info
DROP TABLE IF EXISTS #CSSRS
SELECT distinct 
p.Encountersid
,sc.EncounterTypeClass
, CASE WHEN sc.LocationNurseUnit='*Implied NULL*' THEN sc.Location ELSE sc.LocationNurseUnit END AS Location
, mha.MVIPersonSID
, checklistid
, SurveyName
, SurveyGivenDatetime
, display_CSSRS
INTO #CSSRS
FROM OMHSP_Standard.MentalHealthAssistant_v02 as mha WITH (NOLOCK)
INNER JOIN Cerner.FactPowerForm p  WITH (NOLOCK) ON mha.SurveyAdministrationSID = p.DocFormActivitySID
INNER JOIN Cerner.EncMillEncounter sc WITH (NOLOCK) ON p.EncounterSID = sc.EncounterSID
where sta3n=200 --order by SurveyGivenDatetime desc
	and  SurveyGivenDateTime  >= getdate()-183 --six months back
	AND display_CSSRS IN (0,1)

--Step 2: Find all new and updated CSREs in timeframe
DROP TABLE IF EXISTS #CSREa
SELECT distinct MVIPersonSID, HealthFactorDateTime
INTO #CSREa
FROM OMHSP_Standard.HealthFactorSuicPrev WITH (NOLOCK)
WHERE HealthFactorDateTime >= getdate()-183 --six months back
	AND (List IN ('CSRE_NewEvaluation_HF','CSRE_UpdatedEvaluation_HF') )
		--or category = 'CSRE' and list like '%acute%'
		--or category = 'CSRE' and list like '%Chronic%')
		--28078
		--28531 



--find cases where there was more than 1 CSRE in the SAME DAY; use the EARLIEST one
DROP TABLE IF EXISTS #CSRE
SELECT TOP 1 WITH TIES mvipersonsid, healthfactordatetime
INTO #CSRE
FROM #CSREa
ORDER BY ROW_NUMBER() OVER(
    PARTITION BY mvipersonsid, CAST(healthfactordatetime AS Date) 
    ORDER BY CAST(healthfactordatetime AS Time))


	--Find all Unable to screen (these will be fallouts but we still want to differentiate them from other fallouts)
	DROP TABLE IF EXISTS #CSREun
	SELECT distinct MVIPersonSID, HealthFactorDateTime
	INTO #CSREun
	FROM OMHSP_Standard.HealthFactorSuicPrev WITH (NOLOCK)
	WHERE HealthFactorDateTime >= getdate()-183 --six months back
		AND (List IN ('CSRE_UnableToComplete'))
	

	--find cases where there was a completed CSRE and an Unable to complete in the SAME Day or within 24 hours - use the Completion
		DROP TABLE IF EXISTS #CSREcomp
		
		select TOP 1 WITH TIES mvipersonsid, healthfactordatetime, type
		INTO #CSREComp
		from (select *, type = 'Complete'  from #CSRE
		Union all
		select *, type = 'Unable' from #CSREun
		) as a
		ORDER BY ROW_NUMBER() OVER(
			PARTITION BY mvipersonsid, CAST(healthfactordatetime AS Date) 
			ORDER BY type) -- Completes will show up first, if they exist, which is desired - they can be earlier or later

			--select top 100 * from #CSREcomp order by mvipersonsid, healthfactordatetime

/* Step 3: Create final table
			Join to create table with all positive C-SSRS in past timeframe 
				Includes facility, date and name of C-SSRS, and timinng of CSRE or if CSRE didn't occur*/
	
	DROP TABLE IF EXISTS #stage
	select s.* ,CSRE_d=1
			,case when CSRETimeframe='Same Day' then 1 else 0 end as CSRE_n
	INTO #stage
	from (
	select
	    Encountersid
		,EncounterTypeClass

	    , m.mvipersonsid
		, m.PatientName
		, m.dateofbirth 
		, m.LastFour
		, m.patienticn
		, m.EDIPI 
		, cl.VISN
		, cs.checklistid
		, cl.ADMPARENT_FCDM
		, cs.SurveyName
		, cs.surveygivendatetime as CSSRS_Date
		, location
		, RN_CSSRS = ROW_NUMBER () OVER(
				PARTITION BY cs.mvipersonsid, cs.surveygivendatetime 
				ORDER BY cs.surveygivendatetime, csre.healthfactordatetime)
		, cast(csre.healthfactordatetime as smalldatetime) as CSRE_Date
		,  m.DateOfDeath_Combined as DateofDeath
		, CSRETimeframe = case when csre.type = 'Complete' and cast(cs.surveygivendatetime  as date) = cast(csre.healthfactordatetime as date) then 'Same Day'
							when csre.type  = 'Complete' and datediff(mi, cs.surveygivendatetime , csre.healthfactordatetime) <= 1440 and csre.healthfactordatetime is not null then 'W/in 24 hrs next day'
							when csre.type = 'Complete'  and datediff(mi, cs.surveygivendatetime , csre.healthfactordatetime) > 1440 and csre.healthfactordatetime is not null  then 'More than 24 hrs'
							when csre.type  is null and csre.healthfactordatetime is null then 'No CSRE'
							when csre.type = 'Unable' then 'No CSRE Unable to Screen'
							else '' end
		, csre.Type
		, Case when ISNumeric(m.PriorityGroup) = 1 and m.PriorityGroup > 0 then 'Veteran'
		       else 'Other'
			   end as Veteran_Status 

	from #CSSRS as cs
	INNER JOIN Common.MasterPatient as m WITH (NOLOCK)
		on cs.mvipersonsid=m.mvipersonsid
	left join 
	(
		Select MVIPersonsid, healthfactordatetime,type 
		from #CSREComp
		) as csre
	
	on cs.mvipersonsid=csre.mvipersonsid 
			and cast(csre.healthfactordatetime as date) >= cast(cs.surveygivendatetime as date) --and dateadd(hour, 24, cs.surveygivendatetime)
	Left join lookup.checklistid as cl WITH (NOLOCK)
		on cs.checklistid = cl.checklistid
	where cs.display_CSSRS = 1 and
		cl.IOCDate IS NOT NULL	--only include cases where the CSSRS was administered in an Oracle Health Site (indicated by IOC date is not null)
		and m.TestPatient = 0
		--and m.DateOfDeath_Combined is null --do not remove individuals who have died since most would have qualified for the metric and this is meant to be a QI tool
		and m.MVIPersonSID > 0
		--and m.PriorityGroup <>-1 include all patients 
		) as s
		where RN_CSSRS=1 --this retains the earlier CSRE in cases where there were 2 CSRE dates after a single CSSRS
	
	order by s.mvipersonsid

	--select top 10 * from #stage

	Drop table if exists #CSRE1PatientInfo
	select Encountersid
	, EncounterTypeClass
	, mvipersonsid
	, patienticn, EDIPI
	, patientname
	, DateOfBirth
	, lastfour
	, VISN
	,checklistid
	, ADMPARENT_FCDM
	, surveyname
	, CSSRS_Date
	, [location] CSSRS_location
		--, locationsid
		--, plgrouptype as CSSRS_PLocType
		--, ParentLocation as pCSSRS_PLOcation
		--, clgrouptype as CSSRS_CLocType
	, CSRE_Date
	, CSRETimeframe
	, Veteran_Status 
			
	into #CSRE1PatientInfo  --select * from #CSRE1PatientInfo where patientname like 'comb%'
	from #stage   

--*********************************************************************************************************************
EXEC [Maintenance].[PublishTable] '[OracleH_QI].[CSRE1PatientInfo]','#CSRE1PatientInfo'


END