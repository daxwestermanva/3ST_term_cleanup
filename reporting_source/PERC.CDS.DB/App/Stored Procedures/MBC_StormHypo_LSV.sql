
-- =============================================
-- =============================================
-- Author:  <Amy Robinson>
-- Create date: <9/19/2016>
-- Description: Main data date for the Persceptive Reach report-- Updates
--	2019-01-09 - Jason Bacani - Performance tuning; formatting; NOLOCKs
----	2019-01-19 - SM Updating to align with randomization requirements for evaluation, added a station parameter so 
--  we know which station user is from to determine the checklistID
--  2019-01-28 -SM - reverting to original sp
--	2019-02-13  SM correcting to pull riskcategory and riskcategorylabel from ORM.PatientReport since it has the randomized values
--  2019-04-05 - LM - Added MVIPersonSID to initial select statement
--	2020-09-16 - LM - Pointed to _VM tables
--  2021-12-21 - TG - Added overdose flag just in case we are going to display it on PatientDetails Report
--  2022-01-12 - TG - Fixing RiskCategoryLabels in patient lookup report.
--  2023-04-13 - CW - Adding MOUD/OUD to STORMCohort, Taking out RiskScore when RiskCategory IN (5,11)
--  2023-09-12 - CW - Adding inpatient/census information
--  2025-04-25 - TG - Adding unexpected Fentanyl drug screen
--  2025-05-21 - TG - Adding NonVA cannabis and xylazine exposure data elements
--  2025-06-23 - TG - Adding NLP Concept to link to snippet report

-- EXEC [App].[MBC_StormHypo_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @ICN = 
-- EXEC [App].[MBC_StormHypo_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @ICN = 
-- =============================================
CREATE PROCEDURE [App].[MBC_StormHypo_LSV]
(
	@User VARCHAR(100),
	@ICN VARCHAR(1000)
)
AS
BEGIN
	SET NOCOUNT ON;

  	--For inline testing only
	--DECLARE @User VARCHAR(MAX), @ICN VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @ICN = 
	--DECLARE @User VARCHAR(MAX), @ICN VARCHAR(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @ICN =  

	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT MVIPersonSID
		,PatientICN
	INTO #Patient
	FROM [Common].[MasterPatient] AS b WITH (NOLOCK) 
	WHERE b.PatientICN =  @ICN
		AND EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0);

	SELECT DISTINCT TOP 100
		p.PatientICN,
		a.OUD,
		b.OpioidforPain_Rx, --this is now pills on hand
		CASE 		
			WHEN b.RiskCategory NOT IN (1,2,3,4) AND m.ActiveMOUD=1 AND a.OUD=1 THEN 9 --MOUD and OUD (but not Active Opioid)
			WHEN b.RiskCategory NOT IN (1,2,3,4) AND m.ActiveMOUD=1 AND a.OUD=0 THEN 10 --MOUD (but not Active Opioid)
			WHEN b.RiskCategory = 10 AND a.OUD = 0 THEN 4 --Active status, no pills on hand
			WHEN b.RiskCategory = 10 AND a.OUD = 1 THEN 5 --Active status, no pills on hand, OUD
			WHEN b.RiskCategory IN (1,2,3,4) AND a.OUD = 0 THEN 1 --pills on hand
			WHEN (b.RiskCategory NOT IN (1,2,3,4) OR b.RiskCategory IS NULL) AND a.OUD = 1 THEN 2 --OUD flag, and including the ISNULL because we are now pulling DoD patients
			WHEN b.RiskCategory IN (1,2,3,4) AND a.OUD = 1 THEN 3 --OUD and pills on hand
			WHEN b.RiskCategory IN (6,7,8,9) AND a.OUD = 1 THEN 6 --OUD and recently discontinued
			WHEN b.RiskCategory IN (6,7,8,9) AND a.OUD = 0 THEN 7 --Recently discontinued, no OUD
			WHEN b.RiskCategory IN (11) THEN 8 --Overdose in the past year per SBOR
			ELSE 0 
		END AS STORMCohort,
		b.RIOSORDriskclass,
		b.riosordscore,
		b.Hospice,
		b.ODPastYear,
		b.Facility,
		CASE WHEN (a.RiskCategory IN (5,11) OR b.RiskCategory IN (5,11)) THEN NULL 
			 ELSE a.RiskScore 
			 END AS RiskScore,
		a.RiskScore10,
		a.RiskScore50,
		a.RiskScoreNoSed,
		CASE WHEN (a.RiskCategory IN (5,11) OR b.RiskCategory IN (5,11)) THEN NULL 
			 ELSE a.RiskScoreAny 
			 END AS RiskScoreAny,
		a.RiskScoreAny10,
		a.RiskScoreAny50,
		a.RiskScoreAnyNoSed,
		a.RiskScoreAnyHypothetical10,
		a.RiskScoreAnyHypothetical50,
		a.RiskScoreAnyHypothetical90,
		a.RiskScoreHypothetical10,
		a.RiskScoreHypothetical50,
		CASE WHEN (a.RiskCategory IN (5,11) OR b.RiskCategory IN (5,11)) THEN NULL
			 ELSE a.RiskScoreHypothetical90
			 END AS RiskScoreHypothetical90,
		CASE WHEN b.RiskCategory IS NULL THEN a.RiskCategory 
			 ELSE b.RiskCategory 
			 END AS RiskCategory,
		a.RiskAnyCategory,
		a.RiskCategory_Hypothetical90,
		a.RiskCategory_Hypothetical50,
		a.RiskCategory_Hypothetical10,
		RiskAnyCategory_Hypothetical90,
		RiskAnyCategory_Hypothetical50,
		RiskAnyCategory_Hypothetical10,
		CASE WHEN b.ODPastYear = 1 THEN b.RiskCategoryLabel
             ELSE a.RiskAnyCategoryLabel
             END AS RiskAnyCategoryLabel,
		CASE WHEN b.RiskCategoryLabel IS NULL THEN a.RiskCategoryLabel
			 ELSE b.RiskCategoryLabel
			 END AS RiskCategoryLabel,	
		CASE WHEN b.ODPastYear = 1 THEN b.RiskCategoryLabel
             ELSE a.RiskCategoryLabel_Hypothetical90
             END AS RiskCategoryLabel_Hypothetical90,
        CASE WHEN b.ODPastYear = 1 THEN b.RiskCategoryLabel
             ELSE a.RiskCategoryLabel_Hypothetical50
             END AS RiskCategoryLabel_Hypothetical50,
        CASE WHEN b.ODPastYear = 1 THEN b.RiskCategoryLabel
             ELSE a.RiskCategorylabel_Hypothetical10 
		     END AS RiskCategorylabel_Hypothetical10,
        CASE WHEN b.ODPastYear = 1 THEN b.RiskCategoryLabel
             ELSE a.RiskAnyCategoryLabel_Hypothetical90
             END AS RiskAnyCategoryLabel_Hypothetical90,
        CASE WHEN b.ODPastYear = 1 THEN b.RiskCategoryLabel
             ELSE a.RiskAnyCategoryLabel_Hypothetical50
             END AS RiskAnyCategoryLabel_Hypothetical50,
        CASE WHEN b.ODPastYear = 1 THEN b.RiskCategoryLabel
             ELSE a.RiskAnyCategorylabel_Hypothetical10
             END AS RiskAnyCategorylabel_Hypothetical10,
		Census=ISNULL(i.Census,0),
		InpatientFacility=CASE WHEN i.Census=1 THEN i.Facility ELSE NULL END
		,pd.Details
		,pd.NonVACannabis
		,pd.XylazineExposure
		,pd.Concept
	FROM #Patient AS p
	INNER JOIN [ORM].[RiskScore] AS a WITH (NOLOCK)
	ON p.MVIPersonSID = a.MVIPersonSID
	LEFT JOIN [ORM].[PatientReport] AS b WITH (NOLOCK)
		ON p.MVIPersonSID = b.MVIPersonSID  
	LEFT JOIN [Present].[MOUD] AS m  WITH (NOLOCK)
		ON p.MVIPersonSID=m.MVIPersonSID
	LEFT JOIN (SELECT MVIPersonSID,c.Facility,Census=MAX(Census) FROM Inpatient.BedSection b WITH(NOLOCK) 
			   INNER JOIN LookUp.ChecklistID c WITH(NOLOCK) ON b.ChecklistID=c.ChecklistID
			   GROUP BY MVIPersonSID,c.Facility) i 
		ON p.MVIPersonSID=i.MVIPersonSID
	LEFT JOIN ORM.PatientDetails AS pd
	    ON p.MVIPersonSID = pd.MVIPersonSID
		;
	
END