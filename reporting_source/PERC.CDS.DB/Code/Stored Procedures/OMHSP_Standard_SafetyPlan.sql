


/*=============================================
	Author:		Rebecca Stephens (RAS)
	Create date: 2018-07-18
	Description:	Gets safety plans, based on note titles and health factors 
	    for all real patients. Consider most recent, etc, but for now it includes all without a time limit.
	Modifications:
		2020-01-06	RAS	Added SP_RefusedSafetyPlanning_HF flag to final table to indicate declines.
		2020-06-09	LM	Broke out TIU query into two queries for faster performance
		2020-07-08	LM	Changed to pull health factors from OMHSP_Standard.HealthFactorSuicPrev
		2020-08-13	LM	Overlay of Cerner data
		2021-08-25	JEB Enclave Refactoring - Counts confirmed; Some additional formatting; Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; Added logging
		2021-09-13	LM	Removed deleted TIU documents
		2022-05-12	LM	Exclude local safety plan templates entered after 7/1/2022 based on decision by SP Field Ops

	Testing execution:
		EXEC [Code].[OMHSP_Standard_SafetyPlan]

	Helpful Auditing Scripts

		SELECT TOP 5 DATEDIFF(mi,StartDateTime,EndDateTime) AS DurationInMinutes, * 
		FROM [Log].[ExecutionLog] WITH (NOLOCK)
		WHERE name = 'EXEC Code.OMHSP_Standard_SafetyPlan'
		ORDER BY ExecutionLogID DESC

		SELECT TOP 6 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE TableName = 'SafetyPlan' ORDER BY 1 DESC

  =============================================*/

CREATE PROCEDURE [Code].[OMHSP_Standard_SafetyPlan]
AS
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] 'EXEC Code.OMHSP_Standard_SafetyPlan','Execution of Code.OMHSP_Standard_SafetyPlan SP'

	/*Pull safety plan health factors */
	DROP TABLE IF EXISTS #hf;
	SELECT  
		 s.MVIPersonSID
		,s.ChecklistID 
		,s.HealthFactorSID
		,s.HealthFactorDateTime
		,s.Comments
		,s.VisitSID
		,s.DocFormActivitySID
		,s.List
		,s.Sta3n
	INTO #hf
	FROM [OMHSP_Standard].[HealthFactorSuicPrev] s WITH (NOLOCK)
	WHERE s.List IN ('SP_SafetyPlanReviewed_HF','SP_RefusedSafetyPlanning_HF','SP_NewSafetyPlan_HF','SP_UpdateSafetyPlan_HF')
		AND s.HealthFactorDateTime >= '2018-01-01' 

	/*Get safety plan note title information*/	
	DROP TABLE IF EXISTS #TIU;
	SELECT  
		 t.MVIPersonSID
		,t.EntryDateTime
		,t.TIUDocumentSID
		,t.VisitSID
		,t.SecondaryVisitSID
		,t.ReferenceDateTime
		,t.TIUDocumentDefinition
		,t.Sta3n
		,CASE WHEN t.List='SuicidePrevention_SP_ReviewDecline_TIU' THEN 2
			WHEN t.Sta3n = 200 THEN 3
			WHEN t.List='SuicidePrevention_SafetyPlan_TIU' THEN 1   
			END AS NoteType
		,c.ChecklistID
	INTO #TIU
	FROM [Stage].[FactTIUNoteTitles] t WITH (NOLOCK)
	LEFT JOIN [Lookup].[ChecklistID] c WITH (NOLOCK)
		ON t.StaPa = c.StaPa
	WHERE t.List IN ('SuicidePrevention_SafetyPlan_TIU','SuicidePrevention_SP_ReviewDecline_TIU')
		AND (t.TIUDocumentDefinition LIKE '%SUICIDE PREVENTION SAFETY PLAN%' OR t.TIUDocumentDefinition = 'VA Safety Plan' OR t.EntryDateTime < '2022-07-01')
		
	/****JOIN HF WITH TIU***/
	--Step 1:Join HF with an exact VisitSID match in TIU
	DROP TABLE IF EXISTS #Step1_SID;
	SELECT DISTINCT 
		hf.List
		,hf.HealthFactorSID--,hf.HealthFactorType
		,hf.VisitSID AS VisitSID_HF
		,ISNULL(v.VisitSID,c.VisitSID)  AS VisitSID_TIU
		,hf.DocFormActivitySID
		,ISNULL(v.TIUDocumentSID, c.TIUDocumentSID) AS TIUDocumentSID
		,ISNULL(v.sta3n,c.Sta3n) AS Sta3n
		,hf.ChecklistID
		,hf.MVIPersonSID
		,hf.HealthFactorDateTime
		,ISNULL(v.EntryDateTime, c.EntryDateTime) AS EntryDateTime
		,ISNULL(v.ReferenceDateTime,c.ReferenceDateTime) AS ReferenceDateTime
		,ISNULL(v.TIUDocumentDefinition,c.TIUDocumentDefinition) AS TIUDocumentDefinition
	INTO #Step1_SID
	FROM #hf hf WITH (NOLOCK)
	LEFT JOIN 
		(
			SELECT * FROM #TIU WITH (NOLOCK)
			WHERE NoteType = 2  --only VistA review/decline
		) v  
		ON hf.VisitSID = v.VisitSID 
	LEFT JOIN 
		(
			SELECT * FROM #TIU WITH (NOLOCK)
			WHERE NoteType = 3 --Cerner
		) c  
		ON hf.DocFormActivitySID=c.TIUDocumentSID
		
	--Data for those where VisitSIDs match 
	DROP TABLE IF EXISTS #SID_Match;
	SELECT *  
	INTO #SID_Match
	FROM #Step1_SID WITH (NOLOCK)
	WHERE VisitSID_TIU IS NOT NULL

	--Data for those where VisitSIDs do NOT match 
	DROP TABLE IF EXISTS #No_SID_Match;
	SELECT HealthFactorSID--,HealthFactorType
		  ,VisitSID_HF
		  ,Sta3n
		  ,ChecklistID
		  ,MVIPersonSID
		  --,PatientSID
		  ,HealthFactorDateTime
		  --,VisitDateTime
	INTO #No_SID_Match 
	FROM #Step1_SID WITH (NOLOCK)
	WHERE VisitSID_TIU IS NULL
	;

	--Step 2: Join HF to TIU where VisitSIDs do not match BUT HF record occurs on same day as TIU date
	DROP TABLE IF EXISTS #Step2_Date;
	SELECT 
		a.*
		,t.VisitSID AS VisitSID_TIU
		,t.EntryDateTime
		,t.ReferenceDateTime
		,t.TIUDocumentDefinition
		,t.TIUDocumentSID
	INTO #Step2_Date
	FROM #No_SID_Match a WITH (NOLOCK)
	LEFT JOIN #TIU t WITH (NOLOCK)
		ON a.MVIPersonSID = t.MVIPersonSID 
		AND a.ChecklistID = t.ChecklistID
		AND t.NoteType = 2 
		AND (
			CONVERT(DATE,a.HealthFactorDateTime) = CONVERT(DATE,t.EntryDateTime) 
			OR CONVERT(DATE,a.HealthFactorDateTime) = CONVERT(DATE,t.ReferenceDateTime) 
			)

	--when neither visitsids nor entry date match…grab IDs
	DROP TABLE IF EXISTS #SID_Date_Match;
	SELECT DISTINCT 
		HealthFactorSID
		,VisitSID_HF
		,Sta3n
		,MVIPersonSID
		--,PatientSID
		,HealthFactorDateTime
		--,VisitDateTime
		,TIUDocumentSID
		,TIUDocumentDefinition
	INTO #SID_Date_Match  
	FROM #SID_Match WITH (NOLOCK)
	UNION
	SELECT 
		HealthFactorSID
		,VisitSID_HF
		,Sta3n
		,MVIPersonSID
		--,Patientsid
		,HealthFactorDateTime
		--,VisitDateTime
		,TIUDocumentSID
		,TIUDocumentDefinition
	FROM #Step2_Date WITH (NOLOCK)
	WHERE VisitSID_TIU IS NOT NULL 
	;

	DROP TABLE IF EXISTS #HF_TIU;
	SELECT DISTINCT 
		hf.MVIPersonSID
		--,hf.Patientsid
		,hf.HealthFactorSID
		,ISNULL(a.VisitSID, hf.VisitSID) AS VisitSID
		,ISNULL(a.ReferenceDateTime ,hf.HealthFactorDateTime) AS HealthFactorDateTime
		,ISNULL(a.CheckListID, hf.CheckListID ) AS ChecklistID
		,a.TIUDocumentDefinition
		,a.TIUDocumentSID --Equivalent to DocFormActivitySID in Cerner Powerforms
		,hf.Comments
		,hf.Sta3n
		,CASE 
			WHEN hf.List='SP_RefusedSafetyPlanning_HF' THEN 'VA-SP REFUSED SAFETY PLANNING'
			WHEN  hf.List='SP_SafetyPlanReviewed_HF' THEN 'VA-SP SAFETY PLAN REVIEWED' 
		END AS HealthFactorType 
		,CASE WHEN hf.List='SP_RefusedSafetyPlanning_HF' THEN 1 ELSE 0 END AS SP_RefusedSafetyPlanning_HF
		,CASE WHEN hf.List='SP_SafetyPlanReviewed_HF' THEN 1 ELSE 0 END AS SP_SafetyPlanReviewed_HF
		,CASE WHEN hf.List='SP_UpdateSafetyPlan_HF' THEN 1 ELSE 0 END AS SP_UpdateSafetyPlan_HF
		,CASE WHEN hf.List='SP_NewSafetyPlan_HF' OR hf.List IS NULL THEN 1 ELSE 0 END AS SP_NewSafetyPlan_HF
		,hf.List
	INTO #HF_TIU
	FROM #hf AS hf WITH (NOLOCK)
	LEFT JOIN 
		(
			SELECT a.Healthfactorsid
				  ,t.* 
			FROM #SID_Date_Match a WITH (NOLOCK)
			LEFT JOIN #TIU t WITH (NOLOCK) ON a.TIUDocumentSID = t.TIUDocumentSID
		) a 
		ON a.HealthFactorSID= hf.HealthFactorSID 
	WHERE hf.Sta3n <> 200
	UNION ALL
	SELECT DISTINCT 
		hf.MVIPersonSID
		--,hf.Patientsid
		,hf.HealthFactorSID
		,isnull(a.VisitSID, hf.VisitSID) AS VisitSID
		,isnull(a.ReferenceDateTime ,hf.HealthFactorDateTime) AS HealthFactorDateTime
		,isnull(a.CheckListID, hf.CheckListID ) AS ChecklistID
		,a.TIUDocumentDefinition
		,a.TIUDocumentSID --Equivalent to DocFormActivitySID in Cerner Powerforms
		,hf.Comments
		,hf.Sta3n
		,'N/A' AS HealthFactorType 
		,CASE WHEN hf.List='SP_RefusedSafetyPlanning_HF' THEN 1 ELSE 0 END AS SP_RefusedSafetyPlanning_HF
		,CASE WHEN hf.List='SP_SafetyPlanReviewed_HF' THEN 1 ELSE 0 END AS SP_SafetyPlanReviewed_HF
		,CASE WHEN hf.List='SP_UpdateSafetyPlan_HF' THEN 1 ELSE 0 END AS SP_UpdateSafetyPlan_HF
		,CASE WHEN hf.List='SP_NewSafetyPlan_HF' OR hf.List IS NULL THEN 1 ELSE 0 END AS SP_NewSafetyPlan_HF
		,hf.List
	FROM #hf AS hf WITH (NOLOCK)
	LEFT JOIN 
		(
			SELECT a.Healthfactorsid
				  ,t.* 
			FROM #SID_Date_Match AS a 
			LEFT JOIN #TIU AS t WITH (NOLOCK) ON a.TIUDocumentSID = t.TIUDocumentSID
		) a 
		ON a.HealthFactorSID = hf.HealthFactorSID 
		AND hf.DocFormActivitySID=TIUDocumentSID
	WHERE hf.Sta3n=200
	;

	--Final table with regular note title and review/decline note titles that are reviews (exclude decline)
	DROP TABLE IF EXISTS #hf_final;
	SELECT 
		h.MVIPersonSID
		,p.PatientICN
		,h.Sta3n
		,h.ChecklistID
		,h.VisitSID
		,h.HealthFactorDateTime AS SafetyPlanDateTime
		,h.TIUDocumentDefinition
		,h.TIUDocumentSID
		,h.HealthFactorType
		,h.List
		,ISNULL(h.SP_RefusedSafetyPlanning_HF,0) AS SP_RefusedSafetyPlanning_HF
	INTO #hf_final
	FROM #HF_TIU h WITH (NOLOCK)
	INNER JOIN [Common].[MasterPatient] p WITH (NOLOCK) 
		ON h.MVIPersonSID = p.MVIPersonSID
	UNION
	SELECT h.MVIPersonSID
		  ,p.PatientICN
		  ,h.Sta3n
		  ,h.ChecklistID
		  ,h.VisitSID
		  ,h.ReferenceDateTime AS SafetyPlanDateTime
		  ,h.TIUDocumentDefinition
		  ,h.TIUDocumentSID
		  ,'N/A' AS HealthFactorType
		  ,CASE WHEN hf.List IS NOT NULL THEN 'SP_NewSafetyPlan_HF'
			ELSE NULL END AS List
		  ,0 AS SP_RefusedSafetyPlanning_HF
	FROM #TIU AS h WITH (NOLOCK)
	INNER JOIN [Common].[MasterPatient] p WITH (NOLOCK) 
		ON h.MVIPersonSID = p.MVIPersonSID
	LEFT JOIN #hf AS hf WITH (NOLOCK) 
		ON h.VisitSID = hf.VisitSID
	WHERE h.NoteType=1 
		AND h.ReferenceDateTime IS NOT NULL
	
	--Update permanent table
	EXEC [Maintenance].[PublishTable] 'OMHSP_Standard.SafetyPlan','#hf_final'

	EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END