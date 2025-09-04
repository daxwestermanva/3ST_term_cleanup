

-- =============================================
-- Author:		<Catherine Barry>
-- Create date: <2024-05-15>
-- Description:	Health factors that relate to BHIP note templates; as of 5/17/24, there are NO CERNER versions of the BHIP note templated
-- Modifications:
--	2025-01-13	LM	Refine VistA queries and add queries for Oracle Health data
--  2025-05-13  GC  Added MHTC_BHIPCC_NeedsAssessIntervPlanConsult_TIU to #VistA_TIU
--  2025-05-14  GC  Removed deceased patients from #StageBHIP
--                  select only completed or amended notes : tiustatus in (amended', 'completed')      
--	2025-05-15  GC  Added joins on sta3n between note and HF in step #BHIP_TIU_HF for same patients exist at more than one site. 
--                  IF there are two hf datetime on the same date, get the latest HF datetime 
--                  Remove Test patients 
--  2025-05-27  GC  Remove incorrect join step in #BHIP_TIU_HF 
--  2025-06-05  GC  Added VisitDateTime to the output 
-- Testing execution:
--		EXEC [Code].[BHIP_Templates]
--
-- Helpful Auditing Scripts
--
--		SELECT TOP 5 DATEDIFF(mi,StartDateTime,EndDateTime) AS DurationInMinutes, * 
--		FROM [Log].[ExecutionLog] WITH (NOLOCK)
--		WHERE name = 'Code.BHIP_Templates'
--		ORDER BY ExecutionLogID DESC
--
--		SELECT TOP 2 * FROM [Log].[PublishedTableLog] WITH (NOLOCK) WHERE TableName = 'BHIP_Templates' ORDER BY 1 DESC
--
-- =============================================
CREATE PROCEDURE [Code].[BHIP_Templates]
AS
BEGIN

	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] @Name = 'Code.BHIP_Templates', @Description = 'Execution of Code.BHIP_Templates SP'
	
--Step 1: Identify relevant BHIP note data (health factors and note titles) from PERC Config files
	DROP TABLE IF EXISTS #BHIPnotedata   
	SELECT 
		 c.Category
		,m.List
		,m.ItemID
		,m.AttributeValue
		,m.Attribute
		,c.Printname
	INTO #BHIPnotedata
	FROM [Lookup].[ListMember] m WITH (NOLOCK)
	INNER JOIN [Lookup].[List] c WITH (NOLOCK) 
		ON m.List = c.List
	WHERE c.Category like 'MHTC BHIP%' 		
	;	
	
	--Oracle Health DTA comments
	DROP TABLE IF EXISTS #Comments
	SELECT 
		 c.Category
		,c.List
		,c.ItemID
		,p.DerivedDtaEventResult AS AttributeValue
		,c.Attribute
		,p.DocFormActivitySID
	INTO #Comments
	FROM #BHIPnotedata c 
	INNER JOIN [Cerner].[FactPowerForm] p WITH (NOLOCK) 
		ON c.ItemID = p.DerivedDtaEventCodeValueSID
	WHERE c.Attribute = 'Comment'

	/****************************************************/
	/*  Step 0: This step is to get the latest healthfactors if there are two healthfactordatetime on the same visitsid */
	/****************************************************/
		DROP TABLE IF EXISTS #LATEST_HF 
		SELECT sta3n, mvipersonsid, HealthFactorDateTime 
		INTO #LATEST_HF
		FROM 
		(
		SELECT DISTINCT  h.Sta3n, mvipersonsid, HealthFactorDateTime 
		,ROW_Number() OVER(PARTITION BY h.sta3n, mvipersonsid, visitsid ORDER BY HealthFactorDateTime DESC) as RN
		FROM [HF].[HealthFactor] h WITH (NOLOCK) 
	    INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON h.PatientSID = mvi.PatientPersonSID 
		INNER JOIN #BHIPnotedata n WITH (NOLOCK) --select distinct * from #BHIPnotedata where attribute like 'HealthFactorType'
		ON n.ItemID = h.HealthFactorTypeSID
		WHERE h.HealthFactorDateTime >= dateadd(year,-1,getdate() )
		and attribute like 'HealthFactorType'
		) as a 
		WHERE RN=1

	-- Step 1a: Identify VistA Health Factor SIDs for each patient case
	DROP TABLE IF EXISTS #PatHealthFactorBHIPVistA -- select * from #Pathealthfactorbhipvista  where mvipersonsid = 22194
	SELECT DISTINCT 
		 ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
		,h.VisitSID 
		,h.Sta3n
		,h.HealthFactorSID
		--,NULL AS DocFormActivitySID ---only needed if there were CERNER data
		,CONVERT(VARCHAR(16),h.HealthFactorDateTime) AS HealthFactorDateTime --removing the seconds from the HF date since Cerner note date doesnt have seconds
		,h.Comments
		,n.Category
		,n.List
		,n.PrintName
		,n.AttributeValue AS HealthFactorType
		--,ROW_Number() OVER(PARTITION BY h.sta3n, mvi.mvipersonsid  ORDER BY healthfactordatetime DESC) as RN --partition incorrect
	INTO  #PatHealthFactorBHIPVistA
	FROM [HF].[HealthFactor] h WITH (NOLOCK) 
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
		ON h.PatientSID = mvi.PatientPersonSID 
	INNER JOIN #BHIPnotedata n WITH (NOLOCK) 
		ON n.ItemID = h.HealthFactorTypeSID
	WHERE EXISTS 
	    (Select * from #LATEST_HF f
		 WHERE f.sta3n = h.sta3n and mvi.mvipersonsid = f.MVIPersonSID and f.HealthFactorDateTime = h.HealthFactorDateTime)
	    AND h.HealthFactorDateTime >= getdate()-365 --(the new national note template started testing around then)
		AND n.Attribute = 'HealthFactorType' --pull only health factors
		 
	 	
	-- Step 1b: Join Visit details
	DROP TABLE IF EXISTS #AddLocationsVistA; --145076
	SELECT 
		 h.MVIPersonSID
		,ISNULL(dd.ChecklistID,h.Sta3n) AS ChecklistID
		,h.VisitSID 
		,h.Sta3n
		,h.HealthFactorSID
		,DocFormActivitySID = NULL-- only needed if there were CERNER data
		,h.HealthFactorDateTime
		,HealthFactorType
		,h.Comments
		,h.Category
		,h.List
		,h.PrintName
	INTO  #AddLocationsVistA
	FROM #PatHealthFactorBHIPVistA h WITH (NOLOCK) 
	INNER JOIN [Outpat].[Visit] v WITH (NOLOCK) 
		ON h.VisitSID = v.VisitSID
	LEFT JOIN [Lookup].[DivisionFacility] dd WITH (NOLOCK) 
		ON dd.DivisionSID = v.DivisionSID
	;

	--correct ChecklistID for N California in cases where DivisionSID is missing from Outpat.Visit
	UPDATE #AddLocationsVistA
	SET ChecklistID='612A4'
	WHERE ChecklistID='612'

	--Step 1c: Get DTAs from Oracle Health PowerForms
	DROP TABLE IF EXISTS #BHIP_DTA; 
	SELECT  
		 h.MVIPersonSID
		,ISNULL(ch.ChecklistID,s.checklistID) AS ChecklistID
		,h.EncounterSID 
		,200 AS Sta3n
		,h.DerivedDtaEventCodeValueSID as DtaEventCodeValueSID 
		,h.DocFormActivitySID
		,h.TZFormUTCDateTime  HealthFactorDateTime 
		,TZServiceDateTime VisitDateTime
		,CONCAT(DerivedDtaEvent,': ',DerivedDtaEventResult) AS DTA
		,c.AttributeValue AS Comments
		,HF.Category
		,HF.List
		,HF.PrintName
		,h.DocFormDescription
		,ss.NameFullFormatted
	INTO #BHIP_DTA
	FROM [Cerner].[FactPowerForm] h WITH (NOLOCK) 
	INNER JOIN #BHIPnotedata HF WITH (NOLOCK) 
		ON HF.ItemID = h.DerivedDtaEventCodeValueSID 
		AND HF.AttributeValue = h.DerivedDtaEventResult
	LEFT JOIN #Comments c WITH (NOLOCK) 
		ON HF.List = c.List
		AND h.DocFormActivitySID = c.DocFormActivitySID
	LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
		ON h.StaPa = ch.StaPa
	LEFT JOIN (SELECT sc.EncounterSID, l.ChecklistID, sc.TZServiceDateTime FROM [Cerner].[FactUtilizationStopCode] sc WITH (NOLOCK)
				INNER JOIN [Lookup].[Sta6a] l WITH (NOLOCK)
				ON sc.DerivedSta6a = l.Sta6a
				) s
		ON s.EncounterSID = h.EncounterSID AND CAST(s.TZServiceDateTime as date)=CAST(h.TZClinicalSignificantModifiedDateTime as date)
	LEFT JOIN Cerner.FactStaffDemographic ss
		ON h.ResultPerformedPersonStaffSID = ss.PersonStaffSID
	WHERE HF.Attribute ='DTA'
	UNION ALL
	SELECT  
		 h.MVIPersonSID
		,ISNULL(ch.ChecklistID,s.checklistID) AS ChecklistID
		,h.EncounterSID 
		,200 AS Sta3n
		,h.DerivedDtaEventCodeValueSID as DtaEventCodeValueSID 
		,h.DocFormActivitySID
		,h.TZFormUTCDateTime  AS HealthFactorDateTime 
		,TZServiceDateTime VisitDateTime
		,CONCAT(DerivedDtaEvent,': ',DerivedDtaEventResult) AS DTA
		,h.DerivedDtaEventResult AS Comments
		,HF.Category
		,HF.List
		,HF.PrintName
		,h.DocFormDescription
		,ss.NameFullFormatted
	FROM [Cerner].[FactPowerForm] h WITH (NOLOCK) 
	INNER JOIN #BHIPnotedata HF WITH (NOLOCK) 
		ON HF.ItemID = h.DerivedDtaEventCodeValueSID
	LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK)
		ON h.StaPa = ch.StaPa
	LEFT JOIN (SELECT sc.EncounterSID, l.ChecklistID, sc.TZServiceDateTime FROM [Cerner].[FactUtilizationStopCode] sc WITH (NOLOCK)
				INNER JOIN [Lookup].[Sta6a] l WITH (NOLOCK)
				ON sc.DerivedSta6a = l.Sta6a
				) s
		ON s.EncounterSID = h.EncounterSID AND CAST(s.TZServiceDateTime as date)=CAST(h.TZClinicalSignificantModifiedDateTime as date)
	LEFT JOIN Cerner.FactStaffDemographic ss
		ON h.ResultPerformedPersonStaffSID = ss.PersonStaffSID
	WHERE HF.Attribute ='FreeText'

--Step 2:
--Identify relevant TIU notes. Documentation is required to be done within specific note titles.		
	DROP TABLE IF EXISTS #VistA_TIU  
	SELECT m.MVIPersonSID	
	    ,t.patientsid 
		,t.TIUDocumentSID
		,t.TIUDocumentDefinitionSID
		,DocFormActivitySID = NULL --will need b/c later join with CERNER note title data
		,t.EntryDateTime
		,t.ReferenceDateTime
		,t.VisitSID
		,t.SecondaryVisitSID
		,t.Sta3n
		,ISNULL(d.Sta6a,t.Sta3n) AS Sta6a
		,ISNULL(s.StaPa,t.Sta3n) AS StaPa
		,l.AttributeValue AS TIUDocumentDefinition
		,l.List
		,ss.StaffName
		,tiustatus --switch this to formstatus to incorpoate the CERNER TIU equivalent
	INTO #VistA_TIU  
	FROM [TIU].[TIUDocument] t WITH (NOLOCK)
	INNER JOIN [Lookup].[ListMember] l WITH (NOLOCK)   --select distinct itemid into #note from lookup.listmember where List in  ('MHTC_BHIPCC_NeedsAssessIntervPlan_TIU','MHTC_BHIPCC_Assignment_TIU', 'MHTC_BHIPCC_NeedsAssessIntervPlanConsult_TIU')
		ON t.TIUDocumentDefinitionSID = l.ItemID
	inner join dim.tiustatus  st WITH (NOLOCK) on t.TIUStatusSID = st.TIUStatusSID
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] m WITH (NOLOCK) 
		ON t.PatientSID = m.PatientPersonSID
	LEFT JOIN [Dim].[Division] d WITH (NOLOCK)
		ON t.InstitutionSID = d.InstitutionSID
	LEFT JOIN [Lookup].[Sta6a] s WITH (NOLOCK)
		ON d.Sta6a = s.Sta6a
	LEFT JOIN [SStaff].[SStaff] ss WITH (NOLOCK)
		ON t.EnteredByStaffSID=ss.StaffSID
	WHERE  List in  ('MHTC_BHIPCC_NeedsAssessIntervPlan_TIU','MHTC_BHIPCC_Assignment_TIU', 'MHTC_BHIPCC_NeedsAssessIntervPlanConsult_TIU')
	AND st.TIUStatus IN ('Completed','Amended','Uncosigned','Undictated') --notes with these statuses populate in CPRS/JLV. Other statuses are in draft or retracted and do not display.

	--Step 2b: Identify visit date/times
	DROP TABLE IF EXISTS #AddVisitDate
	SELECT DISTINCT VisitSID, MIN(VisitDateTime) AS VisitDateTime
	INTO #AddVisitDate
	FROM (
		SELECT a.VisitSID, b.VisitDateTime 
		FROM #VistA_TIU a
		INNER JOIN [Outpat].[Visit] b WITH (NOLOCK) 
			ON a.VisitSID = b.VisitSID
		) x
	GROUP BY VisitSID

	--Step 2c: Join the visit datetimes to the general BHIP TIU table
	DROP TABLE IF EXISTS #Stage_VistA_BHIPTIU 
	SELECT vt.*, a.VisitDateTime 
	INTO #STage_VistA_BHIPTIU
	FROM #VistA_TIU as vt
	INNER JOIN #AddVisitDate AS a
		ON a.VisitSID=vt.VisitSID

	--select * from #AddVisitDate
	--select * from #VistA_TIU
	--select * from #Stage_VistA_BHIPTIU


	--Step 2d: Incorporate where visitsids do not match but HF record occurs on same day as TIU record entry date
	--         Select latest healthfactor and entryda tetime 
		DROP TABLE IF EXISTS #BHIP_TIU_HF
		SELECT distinct hf.VisitSID
		     ,t.Visitdatetime 
			 ,t.SecondaryVisitSID
			 ,hf.MVIPersonSID
			 ,hf.Sta3n
			 ,t.EntryDateTime
			 ,t.TIUDocumentDefinition
			 ,hf.HealthFactorType AS HealthFactorDTAType
			 ,hf.HealthFactorDateTime
			 ,hf.ChecklistID
			 ,hf.HealthFactorSID
			 ,DocFormActivitySID=NULL
			 ,hf.Comments
			 ,hf.Category
			 ,hf.List  
			 ,hf.PrintName
			 ,t.StaffName
		INTO #BHIP_TIU_HF
		FROM #AddLocationsVistA AS hf
		INNER JOIN #Stage_VistA_BHIPTIU t ON 
			t.MVIPersonSID=hf.MVIPersonSID
		WHERE hf.VisitSID = t.VisitSID
		UNION ALL
		SELECT a.EncounterSID
		     ,a.VisitDateTime
			 ,SecondaryVisitSID=NULL
			 ,a.MVIPersonSID
			 ,a.Sta3n
			 ,a.HealthFactorDateTime
			 ,a.DocFormDescription
			 ,a.DTA
			 ,a.HealthFactorDateTime
			 ,a.ChecklistID
			 ,HealthFactorSID = NULL
			 ,a.DocFormActivitySID
			 ,a.Comments
			 ,a.Category
			 ,a.List  
			 ,a.PrintName
			 ,a.NameFullFormatted
		FROM #BHIP_DTA a

 

--Step 3
--Create final stage table
	DROP TABLE IF EXISTS #StageBHIP
	SELECT DISTINCT
		 b.MVIPersonSID
		,b.Sta3n
		,b.ChecklistID
		,b.VisitSID 
		,b.VisitDateTime
		,b.TIUDocumentDefinition
		,b.EntryDateTime
		,b.HealthFactorDTAType
		,b.HealthFactorSID
		,b.DocFormActivitySID 
		,b.HealthFactorDateTime
		,b.Comments
		,b.StaffName
		,b.Category
		,b.List
		,b.PrintName
	INTO #StageBHIP
	FROM  #BHIP_TIU_HF as b --select distinct checklistid, tiudocumentdefinition from #bhip_tiu_HF where tiudocumentdefinition like 'MHTC BHIP CC Needs Assessment and Intervention'
	INNER JOIN [Common].[MasterPatient] r WITH (NOLOCK) 
		ON r.MVIPersonSID = b.MVIPersonSID
    WHERE r.DateOfDeath_Combined is null
	and TestPatient = 0
--*******************************************************************************************************************
	EXEC [Maintenance].[PublishTable] 'BHIP.Templates', '#StageBHIP' ;
	
	EXEC [Log].[ExecutionEnd] @Status = 'Completed' ;

END