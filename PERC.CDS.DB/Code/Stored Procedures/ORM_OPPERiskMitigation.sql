


-- =============================================
-- Author:		Tolessa Gurmessa
-- Create date: 03/04/2022
-- Adopted from ORM_RiskMitigation code for OPPE report since the rules on PDMP are different
--
-- 20220914 - CW - Updating ActiveRxStatusVM to pull in Cerner data
-- 20221207 - TG - fixing informed consent requirement for Tramadol Only patients.
-- 20230214 - CW - Switching to ADS UDS dataset for UDS credit in OPPE
-- 20230608 - CW - Adding additional Clinical Evaluation Criteria: Data-based risk review (MeasureID=12) 
-- 20240613 - TG - Adding number of patients due in 90 days for each risk mitigation
-- 20240624 - TG - Fixing drug screen rules
-- 20240815 - TG - Reversing earlier drug screen rules because OPPE doesn't follow the same rules as STORM
-- 20241106 - TG - Fixing a bug that's affecting Tramadol only patients
-- 20250212 - TG - Fixing equality/inequality operator for risk review logic
-- 20250317 - TG - Crediting review notes from STORM copy-paste feature.
-- 20250711 - TG - Filtering TIU notes to 'COMPLETED','AMENDED','UNCOSIGNED','UNDICTATED'
-- =============================================
CREATE PROCEDURE [Code].[ORM_OPPERiskMitigation]

AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC Code.ORM_OPPERiskMitigation','Execution of SP Code.ORM_OPPERIskMitigation'
----------------------------------------------------------------------------
-- GET THE COHORT OF PATIENTS OF INTEREST, RELATED FIELDS, AND RISK MITIGATION STRATEGIES
----------------------------------------------------------------------------
DROP TABLE IF EXISTS #Cohort;
SELECT oh.MVIPersonSID
	  ,ISNULL(oh.ChronicOpioid,0) ChronicOpioid
	  ,ISNULL(c.CancerDx,0) CancerDx
	  ,ISNULL(oh.NonTramadol,0) NonTramadol
	  ,ISNULL(r.Hospice,0) Hospice
	  ,rm.MeasureID as MitigationID
	  -- Specific printnames for UDS (MeasureID 5) and Timely Follow-up (MeasureID 4)
	  ,CASE WHEN oh.ChronicOpioid = 1 AND rm.MeasureID = 5 THEN rm.PrintName + ' (365 Days)'
		WHEN oh.ChronicOpioid = 1 AND rm.MeasureID = 10 THEN rm.PrintName + ' (365 Days)'
		WHEN rm.DetailsRedRules IS NOT NULL AND rm.MeasureID <> 1 and rm.MeasureID <> 15 THEN rm.PrintName + ' (' + cast(DetailsRedRules - 1 as varchar) + ' Days)'
	   ELSE rm.PrintName
	   END AS PrintName
	  ,CAST(rm.DetailsRedRules AS DECIMAL) as DetailsRedRules
INTO #Cohort
FROM (SELECT MVIPersonSID, MAX(ChronicOpioid) AS ChronicOpioid , MAX(NonTramadol) AS NonTramadol, MAX(ActiveRxStatusVM) AS ActiveRxStatusVM
            FROM [ORM].[OpioidHistory] WITH(NOLOCK)
			WHERE ActiveRxStatusVM=1 AND ChronicOpioid = 1
            GROUP BY MVIPersonSID )oh 
LEFT JOIN [ORM].[RiskScore] r WITH(NOLOCK)
      ON oh.MVIPersonSID = r.MVIPersonSID
LEFT JOIN [SUD].[Cohort] c WITH(NOLOCK) on 
	oh.MVIPersonSID = c.MVIPersonSID 
INNER JOIN (
	SELECT MeasureID
		,PrintName
		,DetailsRedRules 
	FROM [ORM].[MeasureDetails] WITH(NOLOCK)
	WHERE MeasureID IN (3,5,10,12)  
	) rm on 1=1
;

CREATE NONCLUSTERED INDEX Cohort ON #Cohort (MVIPersonSID);

----------------------------------------------------------------------------
-- METRIC INCLUSION RULES PER PATIENT AND RISK MITIGATION STRATEGY
----------------------------------------------------------------------------
DROP TABLE IF EXISTS #RMPrep
SELECT DISTINCT MVIPersonSID
	  ,ChronicOpioid
	  ,MitigationID
	  ,PrintName
	  ,DetailsRedRules
	  ,CASE WHEN MitigationID = 3 AND ChronicOpioid = 1 
								  AND NonTramadol = 1
								  AND Hospice = 0     
								  AND CancerDx = 0 THEN 1
	   --Removing UDS requirement for SUD (pandemic); requiring for LTOT
	   WHEN MitigationID = 5 AND ChronicOpioid = 1 THEN 1
	   WHEN MitigationID = 10 THEN 1
	   WHEN MitigationID = 12 THEN 1
	   ELSE 0
	   END AS MetricInclusion
INTO #RMPrep
FROM #Cohort;

----------------------------------------------------------------------------
-- DATA SOURCES FOR SOME OF THE RISK MITIGATION STRATEGIES
----------------------------------------------------------------------------

/************* UDS (MeasureID 5) *************/ 
	DROP TABLE IF EXISTS #UDS
	SELECT MVIPersonSID
		  ,MAX(LabDate) AS UDS_Any_DateTime
		  ,MitigationID = 5
	INTO #UDS
	FROM Present.UDSLabResults WITH (NOLOCK)	
	GROUP BY MVIPersonSID;

/************* PDMP (MeasureID 10) *************/ 
-- Present.PDMP is a union of VistA and Cerner data

	DROP TABLE IF EXISTS #PDMP
	SELECT MVIPersonSID
		  ,PerformedDateTime
		  ,MitigationID = 10
	INTO #PDMP
	FROM Present.PDMP;

/************* Note Titles for informed consent (MeasureID 3) and DBRR (MeasureID 12) *************/

	-- Health Factors for data-based opioid risk review (MeasureID 12) Vista/Cerner 
	-- Then, pull the actual instances from the CDW HF table, and join on 
	-- HealthFactorTypeSID to limit it to the qualifying HFs from the above table.

	DROP TABLE IF EXISTS #HFVM;
	-- VistA
	SELECT 
		c.MVIPersonSID
		, hf.HealthFactorDateTime AS ReferenceDate
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
				AND hf1.HealthFactorDateTime >=  DATEADD(YEAR,-2,CAST(GETDATE() AS DATE))
		) hf ON hf.MVIPersonSID = c.MVIPersonSID
	UNION ALL
	-- Cerner
	SELECT c.MVIPersonSID
		  ,pf.TZFormUTCDateTime AS ReferenceDate
	FROM #Cohort AS c
	INNER JOIN [Cerner].[FactPowerform] AS pf WITH(NOLOCK) 
		ON pf.MVIPersonSID = c.MVIPersonSID
	INNER JOIN [Lookup].[ListMember] AS ht WITH(NOLOCK) 
		ON ht.ItemID = pf.DerivedDtaEventCodeValueSID
	WHERE ht.List in ('ORM_DatabasedReview_HF','ORM_DatabasedReviewHigh_HF',
		'ORM_DatabasedReviewLow_HF','ORM_DatabasedReviewMedium_HF','ORM_DatabasedReviewVeryHigh_HF'
		) AND pf.TZFormUTCDateTime >=  DATEADD(YEAR,-2,CAST(GETDATE() as date));

	--Get most recent per patient
	DROP TABLE IF EXISTS #HF;
	SELECT MVIPersonSID
		  ,MAX(ReferenceDate) AS ReferenceDate
		  ,MitigationID = 12
	INTO #HF
	FROM #HFVM 
	GROUP BY MVIPersonSID;

/************* Note Titles for data-based opioid risk review (MeasureID 12) and informed consent (MeasureID 3) *************/

	-- First, grab the list of qualifying note titles for the 3 RMs
	DROP TABLE IF EXISTS #TIU_Type;
	SELECT TIUDocumentDefinitionSID=ItemID
		  ,TIU_Type=List
		  ,CASE WHEN List = 'ORM_InformedConsent_TIU' THEN 3
				WHEN List = 'ORM_DatabasedReview_TIU' THEN 12
				END AS MitigationID
	INTO #TIU_Type
	FROM Lookup.ListMember WITH(NOLOCK)
	WHERE (List='ORM_InformedConsent_TIU' 
		OR List='ORM_DatabasedReview_TIU' )
;
	--Then, pull the actual notes from the CDW TIU table and Cerner PowerForm Table, 
	--joining to the above table on TIUDocumentDefinitionSID. This is also where we limit 
	--to the qualifying timeframe per the recommendations. 

	DROP TABLE IF EXISTS #NotesVM;
	-- VistA
	SELECT c.MVIPersonSID
		  ,ReferenceDateTime AS ReferenceDate
		  ,t.MitigationID
	INTO #NotesVM
	FROM #Cohort AS C
	INNER JOIN
		(
			SELECT
				ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
				, t1.ReferenceDateTime
				, y.MitigationID
			FROM [TIU].[TIUDocument] t1 WITH (NOLOCK) 
			INNER JOIN #TIU_Type y 
				ON t1.TIUDocumentDefinitionSID = y.TIUDocumentDefinitionSID
			INNER JOIN [Dim].[TIUStatus] ts WITH (NOLOCK)
				ON t1.TIUStatusSID = ts.TIUStatusSID
			LEFT OUTER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON t1.PatientSID = mvi.PatientPersonSID 
			WHERE (t1.ReferenceDateTime >=  DATEADD(YEAR,-2,CAST(GETDATE() as date))
				OR (y.TIU_Type = 'ORM_InformedConsent_TIU'  AND t1.ReferenceDateTime > '2014-05-06'))
				AND t1.DeletionDateTime IS NULL
				AND ts.TIUStatus IN ('COMPLETED','AMENDED','UNCOSIGNED','UNDICTATED') --notes with these statuses populate in CPRS/JLV. Other statuses are in draft or retracted and do not display.
		) t ON t.MVIPersonSID = c.MVIPersonSID
	UNION ALL 
	-- Cerner
	SELECT c.MVIPersonSID
		  ,n.TZEventEndUTCDateTime as ReferenceDate
		  ,y.MitigationID
	FROM #Cohort AS c
	INNER JOIN [Cerner].[FactNoteTitle] AS n WITH(NOLOCK) 
		ON n.MVIPersonSID = c.MVIPersonSID
	INNER JOIN #TIU_Type AS y 
		ON y.TIUDocumentDefinitionSID = n.EventCodeSID
	WHERE n.TZEventEndUTCDateTime >=  DATEADD(YEAR,-2,CAST(GETDATE() as date))
		OR (y.TIU_Type = 'ORM_InformedConsent_TIU')
		UNION ALL
      -- Note entries from copy-paste feature on STORM report
	SELECT c.MVIPersonSID
		  ,ReferenceDateTime AS ReferenceDate
		  ,MitigationID = 12
	FROM #Cohort AS C
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON c.MVIPersonSID=mvi.MVIPersonSID
	INNER JOIN [PDW].[HDAP_NLP_OMHSP] t1 WITH (NOLOCK) 
		ON t1.PatientSID = mvi.PatientPersonSID 
	WHERE t1.ReferenceDateTime >=  DATEADD(YEAR,-2,CAST(GETDATE() as datetime2))
		AND t1.Snippet like '%STORM risk estimate%'  AND t1.ReferenceDateTime > CAST('2025-02-01' AS datetime2) -- the copy/paste feature was deplyed in early March 2025	
			;
		
	

	--Most recent per person	
	DROP TABLE IF EXISTS #Notes;
	SELECT MVIPersonSID
		  ,Max(ReferenceDate) AS ReferenceDate
		  ,MitigationID
	INTO #Notes
	FROM #NotesVM
	GROUP BY MVIPersonSID
			,MitigationID;

/************* Combine health factors and TIU note titles into a single temp table *************/
	DROP TABLE IF EXISTS #TIU_HF_Merge;
	SELECT MVIPersonSID
		  ,ReferenceDate
		  ,MitigationID
	INTO #TIU_HF_Merge
	FROM #Notes
	UNION ALL
	SELECT MVIPersonSID
		  ,ReferenceDate
		  ,MitigationID
	FROM #HF;

	DROP TABLE IF EXISTS #TIU_HF_3_12
	SELECT MVIPersonSID
		  ,MAX(ReferenceDate) as ReferenceDate
		  ,MitigationID
	INTO #TIU_HF_3_12
	FROM #TIU_HF_Merge
	GROUP BY MVIPersonSID
		    ,MitigationID;

----------------------------------------------------------------------------
-- PULL ALL THE RISK MITIGATIONS TOGETHER AND APPLY RULES FOR CHECKBOXES ETC.
----------------------------------------------------------------------------
DROP TABLE IF EXISTS #AllTogether
SELECT rm.MVIPersonSID
	  ,rm.MitigationID
	  ,PrintName
	  ,CASE WHEN rm.MitigationID = 3  THEN ic.ReferenceDate
		    WHEN rm.MitigationID = 5  THEN u.UDS_Any_DateTime
		    WHEN rm.MitigationID = 10 THEN pd.PerformedDateTime
			WHEN rm.MitigationID = 12 THEN db.ReferenceDate
	   END AS DetailsDate
	   ,MetricInclusion
	   ,rm.ChronicOpioid
	   ,rm.DetailsRedRules
INTO #AllTogether
FROM #RMPrep rm
	--Informed consent (MeasureID 3)
	LEFT JOIN (
			SELECT MVIPersonSID   --attempting to get latest consent date in case of multiples
				  ,MAX(ReferenceDate) as ReferenceDate
            FROM #TIU_HF_3_12 ic
            WHERE MitigationID = 3
            GROUP BY MVIPersonSID
            ) ic on rm.MVIPersonSID = ic.MVIPersonSID
	--Drug Screen (MeasureID 5)
	LEFT JOIN #UDS u
		ON rm.MVIPersonSID = u.MVIPersonSID
	-- PDMP (MeasureID 10)
	LEFT JOIN #PDMP pd
		ON rm.MVIPersonSID = pd.MVIPersonSID
		AND pd.MitigationID = 10
	-- Data-based opioid risk review (MeasureID 12)
	LEFT JOIN #TIU_HF_3_12 db
		ON rm.MVIPersonSID = db.MVIPersonSID
		AND db.MitigationID = 12
WHERE rm.MitigationID IN (3,5,10,12) AND MetricInclusion = 1;

DROP TABLE IF EXISTS #Checked
SELECT DISTINCT MVIPersonSID
	  ,MitigationID
	  ,PrintName
	  ,DetailsDate
	  ,MetricInclusion
	  ,DetailsRedRules
	,CASE WHEN MitigationID = 3 AND DetailsDate IS NOT NULL THEN 1
		   WHEN MitigationID = 5 AND DATEDIFF(D, DetailsDate, GETDATE()) < 366  THEN 1
		  WHEN MitigationID = 10 AND DATEDIFF(D, DetailsDate, GETDATE()) < 366  THEN 1
		  WHEN MitigationID = 12 AND DATEDIFF(D, DetailsDate, GETDATE()) < DetailsRedRules THEN 1
		  ELSE 0
	END as Checked
	,CASE WHEN MitigationID IN (3,12) AND (DetailsDate IS NULL OR DATEDIFF(D, DetailsDate, GETDATE()) >= DetailsRedRules) THEN 1
	      WHEN MitigationID = 5 AND ChronicOpioid = 1 AND (DetailsDate IS NULL OR DATEDIFF(D, DetailsDate, GETDATE()) > 365) THEN 1
	      WHEN MitigationID = 10 AND (DetailsDate IS NULL OR DATEDIFF(D, DetailsDate, GETDATE()) > 365) THEN 1
	   ELSE 0
	  END AS Red
INTO #Checked
FROM #AllTogether;

----------------------------------------------------------------------------
-- PUBLISH THE FINAL TABLE
----------------------------------------------------------------------------
DROP TABLE IF EXISTS #Staging;
SELECT cd.MVIPersonSID
       ,cd.MitigationID
	  ,cd.PrintName
	  ,CAST(cd.DetailsDate as DATE) as DetailsDate
	  ,Checked
	  ,Red
	  ,MetricInclusion
	  ,CASE WHEN MitigationID = 5 AND Checked = 1 AND DATEADD(dd, 365,DetailsDate)  <= DATEADD(dd, 90, GETDATE()) THEN 1
            WHEN MitigationID = 10 AND Checked = 1 AND DATEADD(dd, 365,DetailsDate)  <= DATEADD(dd, 90, GETDATE()) THEN 1
            WHEN MitigationID = 12 AND Checked = 1 AND DATEADD(dd, 365,DetailsDate)  <= DATEADD(dd, 90, GETDATE()) THEN 1
	ELSE 0
	END AS DueNinetyDays
   INTO #Staging 
   FROM #Checked cd;

EXEC Maintenance.PublishTable 'ORM.OPPERiskMitigation', '#Staging'

EXEC [Log].[ExecutionEnd]

END