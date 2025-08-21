

-- =============================================
-- Author:		<Catherine Barry>
-- Create date: <2025-04-17>
-- Description:	SUD related Health factors and DTAs. 
--					Initial data: AUDIT-C Follow-up Advising required for AUDIT-C screens with scores of 5 or greater. 
--					Main use case is the MDS e-measure eSA17 (within Code.Metric.eSA7 which is its companion). This will need to include the full 4-quarter data based on each quarterly update. 
--					Another use case will be identifying AUDIT-C F/U for BHIP CC dashboard. 
--					May include other SUD health factors in future.

-- TO DO: Determine maintenance job needs and then share with Liam (or add to Maintenance Jobs myself)
--
-- Testing execution:
--		EXEC [Code].[SUD_Templates]
--
-- Helpful Auditing Scripts
--
--		SELECT TOP 5 DATEDIFF(mi,StartDateTime,EndDateTime) AS DurationInMinutes, * 
--		FROM [Log].[ExecutionLog] WITH (NOLOCK)
--		WHERE name = 'Code.SUD_Templates'
--		ORDER BY ExecutionLogID DESC
--
--		SELECT TOP 2 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE TableName = 'SUD_Templates' ORDER BY 1 DESC
--
-- =============================================

CREATE PROCEDURE [Code].[SUD_Templates]
AS
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] @Name = 'Code.SUD_Templates', @Description = 'Execution of Code.SUD_Templates SP'


--Step 1: Identify relevant note data (health factors and note titles) from PERC Config files
	DROP TABLE IF EXISTS #SUDnotedata; 
	SELECT 
		 c.Category
		,m.List
		,m.ItemID
		,m.AttributeValue
		,m.Attribute
		,c.Printname
	INTO #SUDnotedata
	FROM Lookup.ListMember m WITH (NOLOCK)
	INNER JOIN Lookup.List c WITH (NOLOCK) 
		ON m.List = c.List
	WHERE c.Category = 'AUDC FollowUp'	
	;	

		-- Step 2a: Identify VistA Health Factor SIDs for each patient case
	DROP TABLE IF EXISTS #PatHealthFactorSUDVistA; 
	SELECT 
		 ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
		,h.VisitSID 
		,h.Sta3n
		,h.HealthFactorSID
		,NULL AS DocFormActivitySID
		,CONVERT(VARCHAR(16),h.HealthFactorDateTime) AS HealthFactorDateTime --removing the seconds from the HF date since the note date doesnt have seconds
		,h.Comments
		,n.Category
		,n.List
		,n.PrintName
		,n.AttributeValue AS HealthFactorType
	INTO  #PatHealthFactorSUDVistA
	FROM [HF].[HealthFactor] h WITH (NOLOCK) 
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON h.PatientSID = mvi.PatientPersonSID 
	INNER JOIN #SUDnotedata n WITH (NOLOCK) 
		ON n.ItemID = h.HealthFactorTypeSID
	WHERE n.Attribute = 'HealthFactorType' --pull only health factors
		and h.HealthFactorDateTime >= dateadd(year, -2, getdate()) --only go back for 2 years of data

	-- Step 2b: Join Visit details
	DROP TABLE IF EXISTS #AddLocationsVistA;
	SELECT 
		 h.MVIPersonSID
		,ISNULL(dd.ChecklistID,h.Sta3n) AS ChecklistID
		,h.VisitSID 
		,h.Sta3n
		,h.HealthFactorSID
		,DocFormActivitySID = NULL
		,h.HealthFactorDateTime
		,HealthFactorType
		,h.Comments
		,h.Category
		,h.List
		,h.PrintName
	INTO  #AddLocationsVistA
	FROM #PatHealthFactorSUDVistA h WITH (NOLOCK) 
	INNER JOIN [Outpat].[Visit] v WITH (NOLOCK) 
		ON h.VisitSID = v.VisitSID
	LEFT JOIN [Lookup].[DivisionFacility] dd WITH (NOLOCK) 
		ON dd.DivisionSID = v.DivisionSID
	;

	--correct ChecklistID for N California in cases where DivisionSID is missing from Outpat.Visit
	UPDATE #AddLocationsVistA
	SET ChecklistID='612A4'
	WHERE ChecklistID='612'


--Step 2c: Get DTAs from Oracle Health PowerForms
	DROP TABLE IF EXISTS #SUD_DTA; 
	SELECT  
		 h.MVIPersonSID
		,ch.ChecklistID
		,h.EncounterSID 
		,200 AS Sta3n
		,h.DerivedDtaEventCodeValueSID as DtaEventCodeValueSID 
		,h.DocFormActivitySID
		,CONVERT(VARCHAR(16),h.TZFormUTCDateTime) AS HealthFactorDateTime 
		,CONCAT(DerivedDtaEvent,': ',DerivedDtaEventResult) AS DTA
		,HF.Category
		,HF.List
		,HF.PrintName
		,h.DocFormDescription
	INTO #SUD_DTA
	FROM [Cerner].[FactPowerForm] h WITH (NOLOCK) 
	INNER JOIN #SUDnotedata HF WITH (NOLOCK) 
		ON HF.ItemID = h.DerivedDtaEventCodeValueSID 
		AND HF.AttributeValue = h.DerivedDtaEventResult
	LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
		ON h.StaPa = ch.StaPa
	WHERE HF.Attribute ='DTA'
		and CONVERT(VARCHAR(16),h.TZFormUTCDateTime) >= dateadd(year, -2, getdate()) --only go back for 2 years of data

	
--Step 3: combine VistA and OH data
		DROP TABLE IF EXISTS #SUDComb
			SELECT hf.VisitSID
			 ,hf.MVIPersonSID
			 ,hf.Sta3n
			 ,hf.HealthFactorType  as HealthFactorDTAType
			 ,hf.HealthFactorDateTime
			 ,DocFormDescription = null
			 ,hf.ChecklistID
			 ,hf.HealthFactorSID
			 ,DocFormActivitySID=NULL
			 ,hf.Category
			 ,hf.List  
			 ,hf.PrintName
		INTO #SUDComb
		FROM #AddLocationsVistA AS hf
		UNION ALL
		SELECT a.EncounterSID
			 ,a.MVIPersonSID
			 ,a.Sta3n
			  ,a.DTA as HealthFactorDTAType			  
			  ,a.HealthFactorDateTime
			  ,a.DocFormDescription
			 ,a.ChecklistID
			 ,HealthFactorSID = NULL
			 ,a.DocFormActivitySID
			 ,a.Category
			 ,a.List  
			 ,a.PrintName
		FROM #SUD_DTA a

--Create final stage table
	DROP TABLE IF EXISTS #StageSUD;
	SELECT DISTINCT
		 b.MVIPersonSID
		,b.Sta3n
		,b.ChecklistID
		,b.VisitSID 
		,b.HealthFactorDTAType
		,b.HealthFactorSID
		,b.DocFormActivitySID 
		,b.HealthFactorDateTime
		,b.Category
		,b.List
		,b.PrintName
	INTO #StageSUD
	FROM  #SUDComb as b
	INNER JOIN [Common].[MasterPatient] r WITH (NOLOCK) 
		ON r.MVIPersonSID = b.MVIPersonSID


		--select count(*)
		--from #StageSUD
		--where checklistid is null
	

		----Review
		----select max(healthfactordatetime), min(healthfactordatetime) from #StageSUD
	
	EXEC [Maintenance].[PublishTable] 'SUD.Templates', '#StageSUD' ;
	
	EXEC [Log].[ExecutionEnd] @Status = 'Completed' ;

END