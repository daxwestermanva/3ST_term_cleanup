

/****** Object:  StoredProcedure [Code].[MHA_CSSRS_EDUC]    Script Date: 9/15/2021 11:58:13 AM ******/

/*	Created by:		Catherine Barry
	Validated by:	Liam Mina
	Creates:		App.MHA_CSSRS_EDUC
	Goal: 
		1.	Identify patients who have a C-SSRS administered during an ED/UC visit, defined as occurring within EDIS Time in (VSSC will join on their data with this information)
		OR within 60 minutes prior or after as long as the C-SSRS occurs in an ED/UC stop code and/or in an ED/UC Note template
		2.  VSSC will use this code to identify EDSC =1 cases to include as ED/UC administered C-SSRS in the SPED & ED/UC RISK ID report

	Notes:		This code identifies cases where the C-SSRS is administered in the ED/UC
		AND it differentiates those cases and cases where a patient was administered a C-SSRS within 60 minutes of the ED/UC in a NON-ED setting

	Modifications:
	--	2021-05-27 - LM - Updated reference to MentalHealthAssistant_v02
	--	2021-05-28 - LM - Fixing PDW references; formatting
	--	2021-07-20 - LM - Identify Cerner ED visits by standardized ED/UC Triage PowerForm
	--	2021-09-13 - LM - Removed deleted TIU documents
	--  2021-09-14 - BW - Enclave Refactoring - Counts Confirmed.
	--	2024-03-26 - LM - Limit MHA data to past 2 years now that it contains 5 years of data (previously 2, and before that 3)

*/

CREATE PROCEDURE [Code].[MHA_CSSRS_EDUC]
AS
BEGIN

/*Starting from Step 9 */

DECLARE @PastTwoYears DATE = DateAdd(day,-731,getdate()) 
DECLARE @Today DATE = DateAdd(day,1,getdate())

	/* Step 9: */
DROP TABLE IF EXISTS #MHA_pat
SELECT mha.*
	,c.ADMPARENT_FCDM
	,spat.patientsid
	,spat.patientssn
	,spat.patientname
INTO #MHA_pat
FROM  [OMHSP_Standard].[MentalHealthAssistant_v02] AS mha WITH(NOLOCK) 
INNER JOIN [Lookup].[ChecklistID] AS c  WITH(NOLOCK)
	ON mha.ChecklistID = c.ChecklistID
INNER JOIN [SPatient].[SPatient] AS spat  WITH(NOLOCK)
	ON mha.patienticn=spat.patienticn
	AND spat.sta3n = c.sta3n 
WHERE (surveyname LIKE '%SSRS%' OR surveyname ='ED/UC Triage')
	AND display_CSSRS <> -1 --there are some I9+C-SSRS; this excludes the rows that are responses for the I9
	AND mha.SurveyGivenDatetime >= @PastTwoYears
UNION ALL
SELECT mha.*
	,c.ADMPARENT_FCDM
	,spat.personsid
	,spat.SSN
	,spat.NameFullFormatted
FROM  [OMHSP_Standard].[MentalHealthAssistant_v02] AS mha WITH(NOLOCK)
INNER JOIN [Lookup].[ChecklistID] AS c  WITH(NOLOCK)
	ON mha.ChecklistID = c.ChecklistID
INNER JOIN [Cerner].[FactPatientDemographic] AS spat  WITH(NOLOCK)
	ON mha.MVIPersonSID=spat.MVIPersonSID
WHERE (surveyname LIKE '%SSRS%' OR surveyname ='ED/UC Triage')
	AND display_CSSRS <> -1 --there are some I9+C-SSRS; this excludes the rows that are responses for the I9
	AND mha.SurveyGivenDatetime >= @PastTwoYears
	 
	--select count(*) from #MHA_pat

/* Step 10: Get limited TIU notes - only ED/UCC Triage notes (as inclusively as I can identify them by standard title AND tiudocument name) */
DROP TABLE IF EXISTS #EDUCC_TRIAGE
SELECT dt.tiudocumentdefinition
		,t.sta3n
		,t.EntryDateTime
		,t.VisitSID
		,t.patientsid
		,st.TIUStandardTitle
		,spat.patienticn
		,ED_TIUNote = 1
INTO #EDUCC_TRIAGE
FROM [TIU].[TIUDocument] AS t WITH(NOLOCK)
INNER JOIN [Dim].[TIUDocumentDefinition] AS dt  WITH(NOLOCK)
	ON t.TIUDocumentDefinitionSID=dt.TIUDocumentDefinitionSID AND t.sta3n=dt.sta3n
INNER JOIN [Dim].[TIUStandardTitle] AS st  WITH(NOLOCK)
	ON dt.TIUStandardTitleSID=st.TIUStandardTitleSID
INNER JOIN [Dim].[TIUStatus] ts WITH (NOLOCK)
	ON t.TIUStatusSID = ts.TIUStatusSID
INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] AS spat  WITH(NOLOCK)
	ON spat.PatientPersoNSID = t.PatientSID
WHERE (st.TIUStandardTitle LIKE '%EMERG%DEP%' OR st.TIUStandardTitle LIKE '%URGENT%Care%')
	AND dt.TIUDocumentDefinition NOT LIKE 'ZZ%'
	AND t.entrydatetime BETWEEN @PastTwoYears AND @Today
	AND t.DeletionDateTime IS NULL
	AND ts.TIUStatus IN ('Completed','Amended','Uncosigned','Undictated') --notes with these statuses populate in CPRS/JLV. Other statuses are in draft or retracted and do not display.

UNION ALL

SELECT t.DocFormDescription
        ,Sta3n=200
        ,t.TZFormUTCDateTime
        ,t.EncounterSID
        ,t.PersonSID
        ,TIUStandardTitle=NULL
        ,mp.PatientICN
        ,ED_TIUNote = 1
FROM [Cerner].[FactPowerForm] AS t WITH(NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientICN] AS mp WITH(NOLOCK) 
	ON mp.MVIPersonSID=t.MVIPersonSID
WHERE DocFormDescription = 'ED/UC Triage'
	AND t.TZFormUTCDateTime BETWEEN @PastTwoYears AND @Today

	--select count(*) from #EDUCC_TRIAGE;


/*Step 11: Get limited Outpatient visit data for later join 
			If this only includes stop codes 130 and 131, it won't be able to find ED notes completed in other stop codes, 
			so don't limit to only ED/UC stop codes here*/

DROP TABLE IF EXISTS #Voutpat
SELECT VisitDateTime
		,VisitSID
		,LocationSID
		,PatientSID
		,Sta3n
		,PrimaryStopCodeSID
		,SecondaryStopCodeSID
INTO #VOutpat
FROM [Outpat].[Visit] WITH(NOLOCK)
WHERE VisitDateTime BETWEEN @PastTwoYears AND @Today

UNION ALL 
SELECT TZDerivedVisitDateTime
        ,EncounterSID
        ,LocationSID=-9999
        ,PersonSID
        ,sta3n=200
        ,PrimaryStopCodeSID=NULL
        ,SecondaryStopCodeSID=NULL
FROM [Cerner].[FactUtilizationOutpatient] WITH(NOLOCK)
WHERE EncounterType='Emergency'
AND TZDerivedVisitDateTime BETWEEN @PastTwoYears AND @Today

	--select count(*) from #VOutpat


/* Step 12a: Find details about ED Stop code, TIU standard title for all C-SSRS; 
		Be aware that multiple Notes with an ED standard title may be attached to a given ED visit AND each will be included here even if the C-SSRS was not embedded within each particular note.
		This is addressed in step 12b*/
DROP TABLE IF EXISTS #EDvis
SELECT DISTINCT mha.patienticn
		,mha.patientsid
		,mha.patientssn
		,mha.patientname
		,mha.patientpersonsid
		,mha.mvipersonsid
		,mha.checklistid
		,mha.ADMPARENT_FCDM
		,mha.LocationSID
		,mha.sta3n
		,mha.SurveyGivenDateTime
		,mha.SurveyName
		,mha.display_CSSRS /*1 = positive C-SSRS; 0 = negative C-SSRS; -99 = unable to respond C-SSRS*/
		,ov.visitdatetime
		,ov.visitsid AS outpatvisitsid
		,et.tiudocumentdefinition
		,et.TIUStandardTitle
		,et.ED_TIUNote
		,pc.StopCode AS PrimaryStopCode
		,sc.StopCode AS SecondaryStopCode
INTO #EDVis
FROM #MHA_pat AS mha
LEFT JOIN #VOutpat AS ov   WITH(NOLOCK)
	ON mha.patientsid=ov.patientsid AND mha.sta3n=ov.sta3n
	AND mha.locationsid = ov.locationsid and cast(mha.SurveyGivenDatetime as date) = cast(ov.visitdatetime as date)
LEFT JOIN #EDUCC_TRIAGE AS et  WITH(NOLOCK)
	ON et.visitsid=ov.visitsid AND et.sta3n=ov.Sta3n AND et.patientsid=ov.PatientSID
LEFT JOIN [Dim].[StopCode] AS pc WITH(NOLOCK)
	ON pc.StopCodeSID=ov.PrimaryStopCodeSID
LEFT JOIN [Dim].[StopCode] AS sc  WITH(NOLOCK)
	ON sc.StopCodeSID=ov.SecondaryStopCodeSID

		--select count(*) from #EDVis


/* Step 12b:Identify C-SSRS that occurred during ED visits by flagging cases 
	WHERE C-SSRS occurred in ED Stop code or at a visit with an ED TIU standard title; 
	find the max EDSC for a given patient/surveygivendatetime - e.g. case where there is a 0 and a 1 for the same surveygivendatetime, choose 1 */
DROP TABLE IF EXISTS #edv2
SELECT patienticn, mvipersonsid, patientpersonsid, checklistid, sta3n, locationsid, surveygivendatetime, display_CSSRS, surveyname, max(EDSC) as EDSC
INTO #EDV2
FROM (
	SELECT DISTINCT [MVIPersonSID]
		,[PatientICN]
		,[PatientPersonSID]
		,[Sta3n]
		,[ChecklistID]
		,[LocationSID]
		,[SurveyGivenDatetime]
		,[SurveyName]
		,[display_CSSRS]
		,EDSC = CASE WHEN ED_TIUNote =1 OR PrimaryStopCode IN (130,131) OR SecondaryStopCode IN (130,131) OR SurveyName='ED/UC Triage'
			THEN 1 ELSE 0 END
		FROM #EDVis
		) AS a
GROUP BY patienticn, mvipersonsid, patientpersonsid, checklistid, sta3n, locationsid, surveygivendatetime, display_CSSRS, surveyname
;
	   
	----examine
	--select top 1000 * from #EDV2 order by patienticn, SurveyGivenDatetime
	----select count(*) from #EDV2 --7694025


	
--/*************************************************/

--DROP TABLE IF EXISTS #t1
--SELECT sped.InstitutionName --spedstation
--			, sped.patienticn
--			, sped.patientname
--			, sped.timein, sped.timeout --sped.edislogsid
--			, sped.dispDesc
--			, sped.CSSRS_Results
--			, ed.display_CSSRS
--			, sped.cssrs
--			, ed.SurveyGivenDatetime
--			, ed.edsc
--			, sped.csre_Datetime, sped.CSRE_Acute_level, sped.CSRE_Chronic_level
--			--, sped.safetyPlanDuringEDvisit, sped.patientdeclinedsafetyplanduringedvisit, sped.lastsafetyplan, sped.patientdeclinedlastsafetyplan
--			--,sped.DOM_BSinday, sped.DOM_BsOutDay, sped.DOM_BedSectionName
--			,sped.icdcodes
--INTO #t1
--from [App].[VSSC_Out_DOEx_SPEDCohort] as sped
--LEFT JOIN #edv2 as ed
--	ON sped.patienticn=ed.patienticn 
--		AND cast(sped.CSSRS as smalldatetime) = cast(ed.SurveyGivenDatetime as smalldatetime) --Match on C-SSRS given datetime
----SPED patients
--	--where sped.dispDesc='Home'
-- --     and (sped.CSRE_Chronic_Level='Chronic-Intermediate' or sped.CSRE_Chronic_Level = 'Chronic-High'
-- --                    or sped.CSRE_Acute_Level='Acute-Intermediate' or sped.CSRE_Acute_Level = 'Acute-High')
-- --                               and sped.DOM_BedSectionName is null;
----examine
--	--select * from #t1 
--	--select * from #t1 where CSSRS_Results='-' and display_CSSRS =1--0 patients display for SPED patients, this is good
--	--select * from #t1 where CSSRS_Results='+' and display_CSSRS =0--0 patients display, this is good
--	--select * from #t1 where surveygivendatetime <> cssrs--0 patients display, this is good
--	select * from #t1 --look for examples of cases where the patient was eligible in original code per a positive C-SSRS that was NOT completed in the ED
--			where CSRE_Datetime not between timein and timeout and edsc=0 
--				and cssrs not between timein and timeout
--			order by timeout desc


/*************************************************/
	EXEC [Maintenance].[PublishTable] 'App.MHA_CSSRS_EDUC','#edv2'

	END