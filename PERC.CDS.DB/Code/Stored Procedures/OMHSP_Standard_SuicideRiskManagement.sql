

/*=============================================
-- Author:		Liam Mina
-- Create date: 2020-03-18
-- Description:	Gets details of suicide risk management follow-up notes, based on note titles and health factors.
-- Modifications:
	2020-10-01	LM	Overlay of Cerner data
	2021-03-15	LM	Added OFRCare column, added comments for when patient declined outreach
	2021-05-26	LM	Added HealthFactorDateTime
	2021-06-09	LM	Health factor VA-SRM FU SP DISCUSSED does not exist. Switched to pull in all health factors that could indicate discussion of safety plan
	2021-06-23	LM	Added new SRM health factors and columns
	2021-08-26  JEB - Enclave Refactoring - Counts confirmed; Some additional formatting; Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; Added logging
	2021-09-13	LM	Removed deleted TIU documents
	2021-09-15	LM	Added columns for COVID outreach, Risk Mitigation plan, and reason for unable to attempt contact
	2022-07-26	LM	Force EDVisit=1 and OutpatTx=1 for Cerner sites where 'Chart Review' is documented; see email 'SPED Cerner question' 7/12/22
	2023-08-17	LM	Adjustments to account for new Cerner DTAs
	2024-08-13	LM	Add DTA for outreach not indicated

	Testing execution:
		EXEC [Code].[OMHSP_Standard_SuicideRiskManagement]

	Helpful Auditing Scripts

		SELECT TOP 5 DATEDIFF(mi,StartDateTime,EndDateTime) AS DurationInMinutes, * 
		FROM [Log].[ExecutionLog] WITH (NOLOCK)
		WHERE name = 'EXEC Code.OMHSP_Standard_SuicideRiskManagement'
		ORDER BY ExecutionLogID DESC

		SELECT TOP 6 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE TableName = 'SuicideRiskManagement' ORDER BY 1 DESC

--Notes:
	If the same health factor/DTA is entered twice in the same encounter, in VistA the first record will be dropped, because there cannot be 
	more than one of the same health factor per VisitSID. In Cerner, they will both be retained because the DTAs are grouped at the DocFormActivitySID
	level instead of the EncounterSID level. In this code, DocIdentifier represents the DocFormActivitySID value from Cerner and the VisitSID value from 
	VistA to allow for easier joining across note title and health factor/DTA data.
  =============================================*/

CREATE PROCEDURE [Code].[OMHSP_Standard_SuicideRiskManagement]
AS
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] 'EXEC Code.OMHSP_Standard_SuicideRiskManagement','Execution of Code.OMHSP_Standard_SuicideRiskManagement SP'

	/*Pull Suicide Risk Management Follow-Up Note health factors */
	DROP TABLE IF EXISTS #HealthFactors
	SELECT 
		 MVIPersonSID
		,PatientICN
		,Sta3n
		,ChecklistID
		,VisitSID
		,DocFormActivitySID
		,HealthFactorDateTime
		,HealthFactorSID
		,Comments
		,Category
		,List
		,PrintName
		,ISNULL(DocFormActivitySID,VisitSID) AS DocIdentifier  
	INTO #HealthFactors
	FROM [OMHSP_Standard].[HealthFactorSuicPrev] WITH (NOLOCK)
	WHERE Category = 'Suicide Risk Management'
	AND HealthFactorDateTime >= '2020-03-18'

	DROP TABLE IF EXISTS #TIU
	SELECT 
		 a.VisitSID
		,a.MVIPersonSID
		,a.SecondaryVisitSID
		,a.DocFormActivitySID
		,a.TIUDocumentDefinitionSID
		,a.EntryDateTime
		,a.TIUDocumentDefinition
		,a.ReferenceDateTime
		,a.Sta3n
		,ISNULL(DocFormActivitySID,VisitSID) AS DocIdentifier   
	INTO #TIU 
	FROM [Stage].[FactTIUNoteTitles] a WITH (NOLOCK)
	WHERE List='SuicideRiskManagement_TIU'
		AND a.EntryDateTime >= '2020-03-18' 


--Match Suicide Risk Management notes to health factors on VisitSIDs
	DROP TABLE IF EXISTS #MatchVisitSID
	SELECT 
		 b.VisitSID
		,b.DocFormActivitySID
		,a.MVIPersonSID
		,a.Sta3n
		,b.EntryDateTime
		,b.TIUDocumentDefinition
		,b.DocIdentifier
	INTO #MatchVisitSID
	FROM #HealthFactors a WITH (NOLOCK)
	INNER JOIN #TIU b WITH (NOLOCK) 
		ON a.DocIdentifier = b.DocIdentifier 
		AND a.MVIPersonSID=b.MVIPersonSID

	UNION ALL

	SELECT 
		 c.VisitSID
		,c.DocFormActivitySID
		,a.MVIPersonSID
		,a.Sta3n
		,c.EntryDateTime
		,c.TIUDocumentDefinition
		,a.VisitSID AS DocIdentifier 
	FROM #HealthFactors a WITH (NOLOCK)
	INNER JOIN #TIU c WITH (NOLOCK) 
		ON a.VisitSID = c.SecondaryVisitSID 
		AND a.MVIPersonSID = c.MVIPersonSID

	--where visitsids do not match but HF record occurs on same day as TIU record entry date
	DROP TABLE IF EXISTS #MatchEntryDate
	SELECT 
		 hf.VisitSID
		,t.DocFormActivitySID
		,hf.MVIPersonSID
		,t.EntryDateTime
		,t.TIUDocumentDefinition
		,t.DocIdentifier
	INTO #MatchEntryDate
	FROM #HealthFactors AS hf
	INNER JOIN #TIU t ON 
		t.MVIPersonSID = hf.MVIPersonSID
	LEFT JOIN #MatchVisitSID m 
		ON t.VisitSID = m.VisitSID
	WHERE m.DocIdentifier <> t.DocIdentifier --Not those that matched in previous step
		AND ((CONVERT(DATE,hf.HealthFactorDateTime) = CONVERT(DATE,t.EntryDateTime)) 
			OR CONVERT(DATE,hf.HealthFactorDateTime) = CONVERT(DATE,t.ReferenceDateTime) )

	--Combine the health factors with their corresponding TIUDocumentDefinitions
	DROP TABLE IF EXISTS #TIU_HF
	SELECT h.MVIPersonSID
		  ,h.PatientICN
		  ,h.Sta3n
		  ,h.ChecklistID
		  ,h.List
		  ,h.PrintName
		  ,h.Comments
		  ,h.VisitSID
		  ,h.HealthFactorDateTime
		  ,ISNULL(t.EntryDateTime,h.HealthFactorDateTime) AS EntryDateTime
		  ,t.TIUDocumentDefinition
		  ,t.DocFormActivitySID
		  ,h.DocIdentifier
	INTO #TIU_HF
	FROM #HealthFactors h
	LEFT JOIN 
		(
			SELECT EntryDateTime, TIUDocumentDefinition, VisitSID, DocFormActivitySID, DocIdentifier FROM #MatchVisitSID
			UNION 
			SELECT EntryDateTime, TIUDocumentDefinition, VisitSID, DocFormActivitySID, DocIdentifier FROM #MatchEntryDate
		) t 
		ON h.DocIdentifier = t.DocIdentifier

	--Get details
	DROP TABLE IF EXISTS #OutreachStatus
	SELECT 
		 DocIdentifier
		,List
		,CASE 
			WHEN List = 'SRMFU_ContactMade_HF' THEN 1
			WHEN List = 'SRMFU_ContactNoEngagement_HF' THEN 2
			WHEN List = 'SRMFU_NoContactMade_HF' THEN 3
			WHEN List = 'SRMFU_ChartReview_HF' THEN 4
			WHEN List = 'SRMFU_OutreachNotIndicated_HF' THEN 5
		END AS OutreachStatus
		,CASE WHEN List='SRMFU_ContactNoEngagement_HF' THEN Comments ELSE NULL END AS Comment_PtDecline
		,CASE WHEN Comments LIKE '%OFR%' OR Comments LIKE '%ORF Care%' THEN 1 ELSE 0 END AS OFRCare
		,CASE WHEN Comments LIKE '%COVID%' THEN 1 ELSE 0 END AS COVID
	INTO #OutreachStatus
	FROM #HealthFactors WITH (NOLOCK)
	WHERE List IN ('SRMFU_ContactMade_HF','SRMFU_NoContactMade_HF','SRMFU_ContactNoEngagement_HF', 'SRMFU_ChartReview_HF','SRMFU_OutreachNotIndicated_HF')

	DROP TABLE IF EXISTS #OutreachReason
	SELECT 
		 DocIdentifier
		,List 
		,CASE WHEN List = 'SRMFU_ReasonSPED_HF' THEN 1 ELSE 0 END AS EdVisit
		,CASE WHEN List = 'SRMFU_ReasonPDE_HF' THEN 1 ELSE 0 END AS MHDischarge
		,CASE WHEN List = 'SRMFU_ReasonHRF_HF' THEN 1 ELSE 0 END AS HRF
		,CASE WHEN List = 'SRMFU_ReasonVCL_HF' THEN 1 ELSE 0 END AS VCL
		,CASE WHEN List = 'SRMFU_ReasonCovid_HF' OR Comments LIKE '%Covid%' THEN 1 ELSE 0 END AS COVID
		,CASE WHEN Comments LIKE '%OFR%' OR Comments LIKE '%ORF Care%' THEN 1 ELSE 0 END AS OFRCare
		,Comments AS OtherReason
	INTO #OutreachReason
	FROM #HealthFactors WITH (NOLOCK) 
	WHERE List LIKE 'SRMFU_Reason%'
	
	DROP TABLE IF EXISTS #TopicsDiscussed
	SELECT 
		 DocIdentifier
		,List
		,CASE WHEN List = 'SRMFU_RiskAssessment_HF' THEN 1 ELSE 0 END AS RiskAssessmentDiscussed
		,CASE WHEN List LIKE 'SRMFU_SP%' THEN 1 ELSE 0 END AS SafetyPlanDiscussed
		,CASE WHEN List = 'SRMFU_TxEngage_HF' THEN 1 ELSE 0 END AS TxEngagementDiscussed
		,CASE WHEN List = 'SRMFU_RiskMitigationPlan_HF' THEN 'Yes' END AS RiskMitigationPlan
	INTO #TopicsDiscussed
	FROM #HealthFactors WITH (NOLOCK)
	WHERE List IN ('SRMFU_RiskAssessment_HF','SRMFU_TxEngage_HF','SRMFU_RiskMitigationPlan_HF')
		OR List LIKE 'SRMFU_SP%'

	DROP TABLE IF EXISTS #EngagedCare
	SELECT 
		 DocIdentifier
		,List
		,CASE WHEN List	= 'SRMFU_EngagedOutpatMH_HF' THEN 1 ELSE 0 END AS OutpatTx
		,CASE WHEN List	= 'SRMFU_AdmittedMHInpat_HF' THEN 1 ELSE 0 END AS InpatTx
	INTO #EngagedCare
	FROM #HealthFactors a WITH (NOLOCK)
	WHERE List IN ('SRMFU_EngagedOutpatMH_HF','SRMFU_AdmittedMHInpat_HF')

	DROP TABLE IF EXISTS #Risks
	SELECT 
		 DocIdentifier
		,List
		,CASE 
			WHEN List LIKE '%Acute%' THEN 1
			WHEN List LIKE '%Chronic%' THEN 2
		END AS AcuteChronic
		,CASE 
			WHEN List Like '%High%' THEN 1
			WHEN List LIKE '%Int%' THEN 2
			WHEN List LIKE '%Low%' THEN 3
		END AS RiskLevel
	INTO #Risks
	FROM #HealthFactors WITH (NOLOCK)
	WHERE List LIKE '%Acute%' OR List LIKE '%Chronic%'

	DROP TABLE IF EXISTS #FutureFollowUp
	SELECT 
		 DocIdentifier
		,List
		,CASE 
			WHEN List = 'SRMFU_FUContinued_HF' THEN 'Continue'
			WHEN List = 'SRMFU_FUDeclined_HF' THEN 'Declined' 
			WHEN List = 'SRMFU_FUDiscontinuedMHEngage_HF' THEN 'Discontinue-Engaged in Care'
			WHEN List = 'SRMFU_FUDiscontinuedOther_HF' THEN 'Discontinue-Other Reason' 
		END AS FutureFollowUp
	INTO #FutureFollowUp
	FROM #HealthFactors WITH (NOLOCK)
	WHERE List IN ('SRMFU_FUContinued_HF','SRMFU_FUDeclined_HF') OR LIST LIKE 'SRMFU_FUDiscontinued%'

	DROP TABLE IF EXISTS #WellnessCheck
	SELECT 
		 DocIdentifier
		,List
		,CASE 
			WHEN List LIKE '%Yes%' THEN 'Yes'
			WHEN List LIKE '%No%' THEN 'No'
			WHEN List LIKE '%Unable%' THEN 'Unable'
		END AS WellnessCheck
	INTO #WellnessCheck
	FROM #HealthFactors WITH (NOLOCK)
	WHERE List LIKE 'SRMFU_WellCheck%'

	DROP TABLE IF EXISTS #FollowUpAttempts
	SELECT 
		 DocIdentifier
		,List
		,CASE 
			WHEN List LIKE '%First%' THEN 1
			WHEN List LIKE '%Second%' THEN 2
			WHEN List LIKE '%Third%' THEN 3
		END AS AttemptToContact
	INTO #FollowUpAttempts
	FROM #HealthFactors WITH (NOLOCK)
	WHERE List LIKE '%VMAttempt_HF'

	DROP TABLE IF EXISTS #Ineligible
	SELECT
		DocIdentifier
		,List
		,CASE
			WHEN List = 'SRMFU_IneligibleByConsult_HF' THEN 'Ineligible-Consult'
			WHEN List = 'SRMFU_IneligibleByChartRev_HF' THEN 'Ineligible-Chart Review'
			WHEN List = 'SRMFU_IneligUnableToAttemptContactOther_HF' THEN 'Other Reason'
		END AS NoContact
	INTO #Ineligible
	FROM #HealthFactors WITH (NOLOCK)
	WHERE List LIKE 'SRMFU_Inelig%' 
	
	DROP TABLE IF EXISTS #VMLetter
	SELECT 
		 DocIdentifier
		,List
		,CASE 
			WHEN List = 'SRMFU_UnsuccessVM_HF' THEN 1 
			WHEN List = 'SRMFU_UnsuccessNoVM_HF' THEN 0 
		END AS VoiceMail
		,CASE 
			WHEN List IN ('SRMFU_UnsuccessLetter_HF','SRMFU_IneligLetterSent_HF') THEN 1 
			WHEN List IN ('SRMFU_UnsuccessNoLetter_HF','SRMFU_IneligUnableToSendLetter_HF') THEN 0 
		END AS Letter
	INTO #VMLetter
	FROM #HealthFactors WITH (NOLOCK)
	WHERE List IN ('SRMFU_UnsuccessVM_HF','SRMFU_UnsuccessNoVM_HF') OR List LIKE '%Letter%'

	DROP TABLE IF EXISTS #SRM
	SELECT 
		t.MVIPersonSID
		,t.PatientICN
		,t.Sta3n
		,t.ChecklistID
		,t.VisitSID
		,t.DocFormActivitySID
		,t.HealthFactorDateTime
		,t.EntryDateTime
		,t.TIUDocumentDefinition
		,t.DocIdentifier
		,a.OutreachStatus
		,a.Comment_PtDecline
		,ISNULL(r.EDVisit,0) AS EDVisit
		,ISNULL(r.MHDischarge,0) AS MHDischarge
		,ISNULL(r.HRF,0) AS HRF
		,ISNULL(r.VCL,0) AS VCL
		,COALESCE(r.COVID, a.COVID, 0) AS COVID
		,COALESCE(r.OFRCare, a.OFRCare, 0) AS OFRCare
		,r.OtherReason
		,ISNULL(b.RiskAssessmentDiscussed,0) AS RiskAssessmentDiscussed
		,ISNULL(b.SafetyPlanDiscussed,0) AS SafetyPlanDiscussed
		,ISNULL(b.TxEngagementDiscussed,0) AS TxEngagementDiscussed
		,tx.OutpatTx
		,tx.InpatTx
		,CASE 
			WHEN c.AcuteChronic = 1 AND c.RiskLevel = 1 THEN 'High'
			WHEN c.AcuteChronic = 1 AND c.RiskLevel = 2 THEN 'Intermediate' 
			WHEN c.AcuteChronic = 1 AND c.RiskLevel = 3 THEN 'Low' 
		END AS AcuteRisk	     
		,CASE 				     
			WHEN c.AcuteChronic = 2 AND c.RiskLevel = 1 THEN 'High'
			WHEN c.AcuteChronic = 2 AND c.RiskLevel = 2 THEN 'Intermediate' 
			WHEN c.AcuteChronic = 2 AND c.RiskLevel = 3 THEN 'Low' 
		END AS ChronicRisk
		,b.RiskMitigationPlan
		,d.FutureFollowUp
		,w.WellnessCheck
		,e.AttemptToContact
		,i.NoContact
		,f.VoiceMail
		,f.Letter
	INTO #SRM
	FROM #TIU_HF t
	LEFT JOIN #OutreachStatus a
		ON a.DocIdentifier = t.DocIdentifier
	LEFT JOIN #OutreachReason r
		ON r.DocIdentifier = t.DocIdentifier
	LEFT JOIN #TopicsDiscussed b
		ON b.DocIdentifier = t.DocIdentifier
	LEFT JOIN #EngagedCare tx
		ON tx.DocIdentifier = t.DocIdentifier
	LEFT JOIN #Risks c
		ON c.DocIdentifier=t.DocIdentifier
	LEFT JOIN #FutureFollowUp d
		ON d.DocIdentifier = t.DocIdentifier 
	LEFT JOIN #WellnessCheck  w
		ON w.DocIdentifier = t.DocIdentifier
	LEFT JOIN #FollowUpAttempts e 
		ON e.DocIdentifier = t.DocIdentifier
	LEFT JOIN #Ineligible i
		ON i.DocIdentifier = t.DocIdentifier
	LEFT JOIN #VMLetter f
		ON f.DocIdentifier = t.DocIdentifier

	CREATE NONCLUSTERED INDEX SRMIndex ON #SRM (DocIdentifier); 

	--If multiple screenings are done withing the same VisitSID, the health factors get jumbled/sometimes overwritten
	--To avoid duplicate or jumbled data in these cases, err on the side of taking the max value for 1 and 0 responses 
	DROP TABLE IF EXISTS #SRM_Stage
	SELECT DISTINCT 
		 a.MVIPersonSID
		,a.PatientICN
		,a.Sta3n
		,a.ChecklistID
		,a.VisitSID
		,a.DocFormActivitySID
		,b.HealthFactorDateTime
		,b.EntryDateTime
		,b.TIUDocumentDefinition
		,CASE 
			WHEN b.OutreachStatus = 1 THEN 'Success' 
			WHEN b.OutreachStatus = 2 THEN 'Declined' 
			WHEN b.OutreachStatus = 3 THEN 'Unsuccess' 
			WHEN b.OutreachStatus = 4 THEN 'Chart Review'
			WHEN b.OutreachStatus = 5 THEN 'Outreach Not Indicated'
		END AS OutreachStatus
		,b.Comment_PtDecline
		,b.EDVisit
		,b.MHDischarge
		,b.HRF
		,b.VCL
		,b.COVID
		,b.OFRCare
		,b.OtherReason
		,b.RiskAssessmentDiscussed
		,b.SafetyPlanDiscussed
		,b.TxEngagementDiscussed
		,b.OutpatTx
		,b.InpatTx
		,b.AcuteRisk
		,b.ChronicRisk 
		,b.RiskMitigationPlan
		,b.FutureFollowUp
		,b.WellnessCheck
		,b.AttemptToContact
		,b.NoContact
		,b.VoiceMail
		,b.Letter
	INTO #SRM_Stage
	FROM #SRM a
	INNER JOIN 
		(
			SELECT 
				 DocIdentifier
				,MAX(HealthFactorDateTime) AS HealthFactorDateTime
				,MAX(EntryDateTime) AS EntryDateTime
				,MAX(TIUDocumentDefinition) AS TIUDocumentDefinition
				,MIN(OutreachStatus) AS OutreachStatus
				,MAX(Comment_PtDecline) AS Comment_PtDecline
				,MAX(EDVisit) AS EDVisit
				,MAX(MHDischarge) AS MHDischarge
				,MAX(HRF) AS HRF
				,MAX(VCL) AS VCL
				,MAX(COVID) AS COVID
				,MAX(OFRCare) AS OFRCare
				,MAX(OtherReason) AS OtherReason
				,MAX(RiskAssessmentDiscussed) AS RiskAssessmentDiscussed
				,MAX(SafetyPlanDiscussed) AS SafetyPlanDiscussed
				,MAX(TxEngagementDiscussed) AS TxEngagementDiscussed
				,MAX(OutpatTx) AS OutpatTx
				,MAX(InpatTx) AS InpatTx
				,MIN(AcuteRisk) AS AcuteRisk --min to order from High, Intermediate, Low
				,MIN(ChronicRisk) AS ChronicRisk --min to order from High, Intermediate, Low
				,MAX(RiskMitigationPlan) AS RiskMitigationPlan
				,MIN(FutureFollowUp) AS FutureFollowUp --min to order from Continue, Declined, Discontinue
				,MAX(WellnessCheck) AS WellnessCheck
				,MAX(AttemptToContact) AS AttemptToContact
				,MAX(NoContact) AS NoContact
				,MAX(VoiceMail) AS VoiceMail
				,MAX(Letter) AS Letter
		FROM #SRM WITH (NOLOCK) 
		GROUP BY DocIdentifier
		) b 
		ON a.DocIdentifier = b.DocIdentifier

		--SRM PowerForm in Cerner does not prompt for selection of reason for outreach when 'SPED: Chart Review' is selected. 
		--To ensure these cases are counted on SPED, force EDVisit=1 and OutpatTx=1.  Revisit this after the SRM Powerform is updated to match CPRS.
		--See email 7/12/22 'SPED Cerner question' between CNB and LM. 
		UPDATE #SRM_Stage
		SET EDVisit=1
			,OutpatTx=1
		WHERE Sta3n = 200 AND OutreachStatus = 'Chart Review'
		AND HealthFactorDateTime < '2023-07-06' --on 7/6 the PowerForm was updated to address this and now prompts for outreach reason in all cases
	;

	EXEC [Maintenance].[PublishTable] '[OMHSP_Standard].[SuicideRiskManagement]','#SRM_Stage'

	EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END