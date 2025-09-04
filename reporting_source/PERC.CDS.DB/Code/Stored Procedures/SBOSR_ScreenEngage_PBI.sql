
-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	5/18/2023
-- Description:	Dataset for information related to screening, evaluation and care engagement 
--				in the Suicide Behavior and Overdose Summary Report. One to Many relationship with 
--				[App].[SBOSR_SDVDetails_PBI] in the report. To be used in PowerBI visuals (Clinical/Case 
--				Factors).
--
--				No row duplication expected in this dataset.	
--				
-- Modifications:
-- 06-08-2023 CW  Declare time variables to use throughout report; Remove [Outpat].[Visit] and 
--				  [Cerner].[FactUtilizationOutpatient] from appt temp tables; Update #MostRecent to pull in both
--				  past and future appointments in single row; Add 'CSRE_LethalMeansFirearmsYes' in #Firearm
-- 07-13-2023 CW  Adding in most recent Safety Plan
-- 08-02-2023 CW  Expanding access to opioids cohort to include rx as well as health factors
-- 01-08-2024 CW  Updating criteria for 'BHIP' team (2/2 changes made to Present.Providers); leaving the 
--				  variable name as 'BHIP' so the report doesn't break
-- 02-14-2024 CW  Updating data source for SP2 Clin consults
-- 09-04-2024 CW  Adding column to indicate most recent SP 2.0 request date
-- =======================================================================================================
CREATE PROCEDURE [Code].[SBOSR_ScreenEngage_PBI]

AS
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @PastYear     Date		SET @PastYear=DATEADD(year,-1,GETDATE()) 
	DECLARE @NextYear	  Date		SET @NextYear=DATEADD(year,1,GETDATE()) 
    DECLARE @Past90Days   Date		SET @Past90Days=DATEADD(d,-90,GETDATE())  
   
	DROP TABLE IF EXISTS #Cohort
	SELECT DISTINCT MVIPersonSID, PatientKey
	INTO #Cohort
	FROM SBOSR.SDVDetails_PBI

	--CSSRS Positive Past Year
	DROP TABLE IF EXISTS #CSSRS 
	SELECT DISTINCT
		 c.MVIPersonSID
		,CSSRSPositivePastYear=1
	INTO #CSSRS
	FROM #Cohort c
	INNER JOIN OMHSP_Standard.MentalHealthAssistant_v02 m WITH (NOLOCK)
		ON c.MVIPersonSID=m.MVIPersonSID
	WHERE SurveyGivenDatetime >= @PastYear AND
		  display_CSSRS=1;
	
	--CSRE High Risk Past Year
	DROP TABLE IF EXISTS #CSRE
	SELECT 
		 MVIPersonSID
		,CASE WHEN AcuteRisk='High' OR ChronicRisk='High' THEN 1 ELSE 0 END AS CSREHighPastYear
		,CSREPastYear=1
	INTO #CSRE
	FROM (
			SELECT
				 c.MVIPersonSID
				,ISNULL(h.AcuteRisk,'Unknown') AS AcuteRisk
				,ISNULL(h.ChronicRisk,'Unknown') AS ChronicRisk
			FROM #Cohort AS c
			INNER JOIN [OMHSP_Standard].[CSRE] AS h WITH (NOLOCK) 
				ON c.MVIPersonSID = h.MVIPersonSID
			WHERE (h.AcuteRisk IS NOT NULL OR h.ChronicRisk IS NOT NULL) AND
			ISNULL(h.EntryDateTime,h.VisitDateTime) >= @PastYear
		 ) Src;

	--Safety Plan Completed Past Year (Indicator) and most Recent Safety Plan
	DROP TABLE IF EXISTS #SafetyPlan
	SELECT *, CASE WHEN SafetyPlanDate >= @PastYear THEN 1 ELSE 0 END SafetyPlanPastYear
	INTO #SafetyPlan
	FROM (
	SELECT
		c.MVIPersonSID
		,MAX(CAST(sp.SafetyPlanDateTime as DATE)) as SafetyPlanDate
	FROM #Cohort c
	INNER JOIN OMHSP_Standard.SafetyPlan sp WITH (NOLOCK)
		ON c.MVIPersonSID=sp.MVIPersonSID
	WHERE sp.SP_RefusedSafetyPlanning_HF=0
	GROUP BY c.MVIPersonSID) Src

	--Access to Firearms
	DROP TABLE IF EXISTS #Firearm
	SELECT DISTINCT
		 c.PatientKey
		,h.MVIPersonSID
		,FirearmAccess=1
	INTO #Firearm
	FROM #Cohort c
	INNER JOIN [OMHSP_Standard].[HealthFactorSuicPrev] h
		ON c.MVIPersonSID=h.MVIPersonSID
	WHERE h.HealthFactorDateTime >= @PastYear AND h.List IN ('SP_FirearmAccessYes_HF', 'CSRE_LethalMeansFirearmsYes')

	--Access to Opioids	(Rx and HFs)
	DROP TABLE IF EXISTS #Opioids
	SELECT DISTINCT
		 c.PatientKey
		,c.MVIPersonSID
		,OpioidAccess=1
	INTO #Opioids
	FROM #Cohort c
	LEFT JOIN [OMHSP_Standard].[HealthFactorSuicPrev] h
		ON c.MVIPersonSID=h.MVIPersonSID
	LEFT JOIN ORM.PatientDetails s 
		ON c.MVIPersonSID=s.MVIPersonSID
	WHERE (h.HealthFactorDateTime >= @PastYear AND h.List='SP_OpioidAccessYes_HF')
	OR (s.OpioidForPain_Rx=1 AND s.Hospice=0) 
	
	--PC info
	DROP TABLE IF EXISTS #PC 
	SELECT
		 MVIPersonSID
		,CASE WHEN PCDate >= @Past90Days THEN 1 ELSE 0 END as PCLast3Mo
		,PCLastYr=1
	INTO #PC
	FROM (
			SELECT
				 AP.MVIPersonSID
				,AP.VisitDateTime as PCDate
			FROM #Cohort c
			INNER JOIN Present.AppointmentsPast AP WITH(NOLOCK)
				ON AP.MVIPersonSID=c.MVIPersonSID
			WHERE AP.ApptCategory IN ('PCRecent')
		 ) Src;

	--Mental Health info
	DROP TABLE IF EXISTS #MH
	SELECT
		 MVIPersonSID
		,CASE WHEN MHDate >= @Past90Days THEN 1 ELSE 0 END as MHLast3Mo
		,MHLastYr=1
	INTO #MH
	FROM (
			SELECT
				 AP.MVIPersonSID
				,AP.VisitDateTime as MHDate
			FROM #Cohort c
			INNER JOIN Present.AppointmentsPast AP WITH(NOLOCK)
				ON AP.MVIPersonSID=c.MVIPersonSID
			WHERE AP.ApptCategory IN ('MHRecent')
		 ) Src;

	--Referred to SP 2.0 within past year and last date of referral
	DROP TABLE IF EXISTS #SP2
	SELECT DISTINCT
		 c.MVIPersonSID
		,c.PatientKey
		,MAX(CAST(con.RequestDate AS DATE)) RequestDate
		,SP2LastYr=CASE WHEN con.RequestDate >= @PastYear AND (C_Sent=1 OR C_Received=1) THEN 1 ELSE 0 END
	INTO #SP2
	FROM [PDW].[NEPEC_MHICM_DOEx_TH_Consult_AllFacilities] con WITH(NOLOCK)
	INNER JOIN Common.MVIPersonSIDPatientPersonSID m WITH(NOLOCK)
		ON con.PatientSID=m.PatientPersonSID
	INNER JOIN #Cohort c
		ON c.MVIPersonSID=m.MVIPersonSID
	GROUP BY c.MVIPersonSID,c.PatientKey,con.RequestDate,con.C_Sent,con.C_Received;

	--Active COMPACT episode
	DROP TABLE IF EXISTS #COMPACT
	SELECT 
		 c.MVIPersonSID
		,c.PatientKey
		,ActiveEpisode
	INTO #COMPACT
	FROM COMPACT.Episodes e
	INNER JOIN #Cohort c
		ON e.MVIPersonSID=c.MVIPersonSID
	WHERE ActiveEpisode=1;

    DROP TABLE IF EXISTS #MostRecent
    SELECT 
         p.MVIPersonSID
        ,past.PrimaryStopCodeName AS MostRecentApptStop
        ,future.PrimaryStopCodeName AS NextApptStop
    INTO #MostRecent
    FROM #Cohort AS p 
    LEFT JOIN ( SELECT TOP 1 WITH TIES 
					 MVIPersonSID
					,ISNULL(PrimaryStopCodeName,AppointmentType) AS PrimaryStopCodeName
					,PrimaryStopCode
					,SecondaryStopCode
					,AppointmentDatetime
					,PastFuture = 2
                    FROM [Present].[AppointmentsFuture] WITH (NOLOCK)
                    WHERE NextAppt_ICN=1 
                        AND ApptCategory IN ('PCFuture','MHFuture','HomelessFuture','PainFuture','PeerFuture','OtherFuture')
						AND AppointmentDatetime <= @NextYear
                    ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY AppointmentDateTime)
                ) future ON future.MVIPersonSID=p.MVIPersonSID                                                      
    LEFT JOIN ( SELECT TOP 1 WITH TIES 
					 MVIPersonSID
					,PrimaryStopCodeName
					,PrimaryStopCode
					,SecondaryStopCode
					,VisitDatetime
					,PastFuture = 1
                FROM [Present].[AppointmentsPast] WITH (NOLOCK)
                WHERE MostRecent_ICN=1 
                  AND ApptCategory IN ('PCRecent','MHRecent','HomelessRecent','PainRecent','PeerRecent','OtherRecent','ClinRelevantRecent','EDRecent')
				  AND VisitDateTime >= @PastYear
                ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY VisitDateTime DESC)
                ) past ON past.MVIPersonSID = p.MVIPersonSID;

	--Team Info
	DROP TABLE IF EXISTS #BHIP_PACT
	SELECT DISTINCT
		 c.MVIPersonSID
		,CASE WHEN p.TeamType IN ('PACT') AND p.ActiveAny=1 THEN 1 ELSE 0 END AS PACT
		,CASE WHEN p.TeamType IN ('MH','BHIP') AND p.ActiveAny=1 THEN 1 ELSE 0 END AS BHIP --MH/BHIP 
	INTO #BHIP_PACT
	FROM #Cohort c
	INNER JOIN Common.Providers p WITH(NOLOCK)
		ON c.MVIPersonSID = p.MVIPersonSID
	WHERE p.TeamType IN ('PACT','BHIP','MH');

	--Most recent data-based risk review (past year)
	----Health factors
	DROP TABLE IF EXISTS #HFVM;
		-- VistA
	SELECT 
		 c.MVIPersonSID
		,hf.HealthFactorDateTime AS ReferenceDate
	INTO #HFVM
	FROM #Cohort c
	INNER JOIN
		(
			SELECT 
				ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
				, hf1.HealthFactorDateTime
			FROM [HF].[HealthFactor] hf1 WITH (NOLOCK) 
			INNER JOIN [Lookup].[ListMember] ht WITH (NOLOCK) 
				ON hf1.HealthFactorTypeSID = ht.ItemID
			LEFT OUTER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON hf1.PatientSID = mvi.PatientPersonSID 
			WHERE ht.List = 'ORM_DatabasedReview_HF' 
				AND hf1.HealthFactorDateTime >= @PastYear
		) hf ON hf.MVIPersonSID = c.MVIPersonSID

	UNION ALL

		--Cerner
	SELECT c.MVIPersonSID
		  ,pf.TZFormUTCDateTime AS ReferenceDate
	FROM #Cohort AS c
	INNER JOIN [Cerner].[FactPowerform] AS pf WITH(NOLOCK) ON pf.MVIPersonSID = c.MVIPersonSID
	INNER JOIN [Lookup].[ListMember] AS ht WITH(NOLOCK) ON ht.ItemID = pf.DerivedDtaEventCodeValueSID
	WHERE ht.List in ('ORM_DatabasedReview_HF','ORM_DatabasedReviewHigh_HF',
		'ORM_DatabasedReviewLow_HF','ORM_DatabasedReviewMedium_HF','ORM_DatabasedReviewVeryHigh_HF'
		) and pf.TZFormUTCDateTime >=  @PastYear

	----Note titles
	DROP TABLE IF EXISTS #TIU_Type;
	SELECT DISTINCT
		AttributeValue AS TIUDocumentDefinitionPrintName
		,ItemID AS TIUDocumentDefinitionSID
		,ORM_DatabasedReview_TIU = 1
	INTO #TIU_Type
	FROM LookUp.ListMember WITH(NOLOCK)
	WHERE List='ORM_DatabasedReview_TIU'
	
	DROP TABLE IF EXISTS #NotesVM;
		--VistA
	SELECT c.MVIPersonSID
		  ,ReferenceDateTime AS ReferenceDate
	INTO #NotesVM
	FROM #Cohort AS C
	INNER JOIN
		(
			SELECT
				 ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
				,t1.ReferenceDateTime
			FROM [TIU].[TIUDocument] t1 WITH (NOLOCK) 
			INNER JOIN #TIU_Type y 
				ON t1.TIUDocumentDefinitionSID = y.TIUDocumentDefinitionSID
			INNER JOIN [Dim].[TIUStatus] ts WITH (NOLOCK)
				ON t1.TIUStatusSID = ts.TIUStatusSID
			LEFT OUTER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON t1.PatientSID = mvi.PatientPersonSID 
			WHERE ((t1.ReferenceDateTime >= @PastYear) OR
				y.ORM_DatabasedReview_TIU=1) AND
				t1.DeletionDateTime IS NULL AND
				ts.TIUStatus IN ('Completed','Amended','Uncosigned','Undictated') --notes with these statuses populate in CPRS/JLV. Other statuses are in draft or retracted and do not display.
		) t	ON t.MVIPersonSID = c.MVIPersonSID

	UNION ALL 

		--Cerner
	SELECT c.MVIPersonSID
		  ,n.TZEventEndUTCDateTime as ReferenceDate
	FROM #Cohort AS c
	INNER JOIN [Cerner].[FactNoteTitle] AS n WITH(NOLOCK) 
		ON n.MVIPersonSID = c.MVIPersonSID
	INNER JOIN #TIU_Type AS y ON y.TIUDocumentDefinitionSID = n.EventCodeSID
	WHERE n.TZEventEndUTCDateTime >= @PastYear
		OR y.ORM_DatabasedReview_TIU=1

	--Combine HFs and note titles for most recent DBRR
	DROP TABLE IF EXISTS #DBRRStage
	SELECT DISTINCT
		 MVIPersonSID
		,CONVERT(DATE, ReferenceDate) AS ReferenceDate
	INTO #DBRRStage
	FROM #HFVM
	UNION
	SELECT DISTINCT
		 MVIPersonSID
		,CONVERT(DATE, ReferenceDate) AS ReferenceDate
	FROM #NotesVM

	DROP TABLE IF EXISTS #DBRR
	SELECT MVIPersonSID
		,MAX(ReferenceDate) AS ReferenceDate
	INTO #DBRR
	FROM #DBRRStage
	GROUP BY MVIPersonSID

	--Final table
	DROP TABLE IF EXISTS #ScreenEngage
	SELECT
		 MVIPersonSID
		,PatientKey
		,CSSRSPositivePastYear
		,CSREHighPastYear
		,CSREPastYear
		,SafetyPlanDate
		,SafetyPlanPastYear
		,FirearmAccess
		,OpioidAccess
		,PCLast3Mo
		,PCLastYr
		,MHLast3Mo
		,MHLastYr
		,SP2LastYr
		,SP2RequestDate
		,ActiveEpisode
		,ISNULL(MostRecentApptStop,'No VA Contact in the Last Year') MostRecentApptStop
		,ISNULL(NextApptStop,'No VA Contact Scheduled in the Future') NextApptStop
		,BHIP
		,PACT
		,ReferenceDate
	INTO #ScreenEngage
	FROM (
			SELECT DISTINCT
				 c.MVIPersonSID
				,c.PatientKey
				,MAX(CASE WHEN cssrs.CSSRSPositivePastYear=1 THEN 1 ELSE 0 END) AS CSSRSPositivePastYear
				,MAX(CASE WHEN csre.CSREHighPastYear=1 THEN 1 ELSE 0 END) AS CSREHighPastYear
				,MAX(CASE WHEN csre.CSREPastYear=1 THEN 1 ELSE 0 END) AS CSREPastYear
				,MAX(SafetyPlanDate) AS SafetyPlanDate
				,MAX(CASE WHEN sp.SafetyPlanPastYear=1 THEN 1 ELSE 0 END) AS SafetyPlanPastYear
				,MAX(CASE WHEN f.FirearmAccess=1 THEN 1 ELSE 0 END) AS FirearmAccess
				,MAX(CASE WHEN o.OpioidAccess=1 THEN 1 ELSE 0 END) AS OpioidAccess
				,MAX(CASE WHEN pc.PCLast3Mo=1 THEN 1 ELSE 0 END) AS PCLast3Mo
				,MAX(CASE WHEN pc.PCLastYr=1 THEN 1 ELSE 0 END) AS PCLastYr
				,MAX(CASE WHEN mh.MHLast3Mo=1 THEN 1 ELSE 0 END) AS MHLast3Mo
				,MAX(CASE WHEN mh.MHLastYr=1 THEN 1 ELSE 0 END) AS MHLastYr
				,MAX(CASE WHEN sp2.SP2LastYr=1 THEN 1 ELSE 0 END) AS SP2LastYr
				,MAX(sp2.RequestDate) AS SP2RequestDate
				,MAX(CASE WHEN com.ActiveEpisode=1 THEN 1 ELSE 0 END) AS ActiveEpisode
				,MAX(MostRecentApptStop) AS MostRecentApptStop
				,MAX(NextApptStop) AS NextApptStop
				,MAX(BHIP) AS BHIP
				,MAX(PACT) AS PACT
				,MAX(ReferenceDate) as ReferenceDate
			FROM #Cohort c
			LEFT JOIN #CSSRS cssrs ON c.MVIPersonSID=cssrs.MVIPersonSID
			LEFT JOIN #CSRE csre ON c.MVIPersonSID=csre.MVIPersonSID
			LEFT JOIN #SafetyPlan sp ON c.MVIPersonSID=sp.MVIPersonSID
			LEFT JOIN #Firearm f ON c.MVIPersonSID=f.MVIPersonSID
			LEFT JOIN #Opioids o ON c.MVIPersonSID=o.MVIPersonSID
			LEFT JOIN #PC pc ON c.MVIPersonSID=pc.MVIPersonSID
			LEFT JOIN #MH mh ON c.MVIPersonSID=mh.MVIPersonSID
			LEFT JOIN #MostRecent mr ON c.MVIPersonSID=mr.MVIPersonSID
			LEFT JOIN #BHIP_PACT bp ON c.MVIPersonSID=bp.MVIPersonSID
			LEFT JOIN #SP2 sp2 on c.MVIPersonSID=sp2.MVIPersonSID
			LEFT JOIN #COMPACT com ON c.MVIPersonSID=com.MVIPersonSID
			LEFT JOIN #DBRR dbrr ON c.MVIPersonSID=dbrr.MVIPersonSID
			GROUP BY c.MVIPersonSID, c.PatientKey
		 ) Src;

	EXEC [Maintenance].[PublishTable] 'SBOSR.ScreenEngage_PBI','#ScreenEngage';

	END