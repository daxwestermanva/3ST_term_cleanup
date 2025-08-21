
-- =============================================
-- Author:		<Amy Robinson>
-- Create date: 09/11/2017
-- Description: Assigning patients to groups for report filters and metric calculations
-- Approx Run Time: 18 min
-- Modifications:
	--20190105	RAS	Formatting changes and added maintenance publish table instead of drop/recreate
	--20190819  CMH Expanded to include all patients from Present.StationAssignments and not limit to just PDSI and STORM so can be used for SPPRITE as well
	--20191022  CMH Filled in NULLS in ChecklistID for Unassigned rows with ChecklistID in Present.StationAssignments
	--20191118  CMH In order to match methods in Present.Provider views, only kept most recent provider (among PCP, PACT, MHTC, BHIP groupings) for patients with more than one provider in same group listed in the same ChecklistID
	--20200414	RAS	Added associate provider name when applicable for PCP.  Removed join to SStaff as names are avaiable in Present.Provider_Active
	--20201030	LM	Pointed to _VM tables for Cerner overlay
	--20201209	RAS Replaced StationAssignments join with a CTE that uses Present.ActivePatient to ensure all patient-stations are included	
	--20201211	RAS Changed StationAssignments join to use MVIPersonSID and ChecklistID rather than PatientPersonSID (which is sometimes VistA, sometimes Cerner)
	--20201213	LM	Made ProviderSID 0 if null when coming from Present.Medications due to incomplete prescriber data from Cerner

--2020-04-28	Need to update this to use Present.Providers ranking instead of recomputing. But should HBPC teams be included in "PACT" here?

	--20210518  JEB Enclave work - updated [SStaff].[SStaff] Synonym use. No logic changes made.	
	--20210913	PS/MCP	Adding Inpatient and Outpatient Stop Code Groupings
	--20210917  AI Enclave Refactoring - Counts confirmed
	--20220310  SG - Based on VSSC PCMM table, 
	               -- Remove Column pcm_std_team_care_type_id and update with TeamType = 'BHIP' and TeamType = 'PACT'  
				   -- RelationshipEndDateTime to RelationshipEndDate 
	--20220617	LM	Cerner overlay for GroupType=Outpatient Stop Codes
	--20220714	CW	Updated ProviderSID to account for AssociateProviderSID
	--20220726	LM	Get EDIPI for Cerner sites in place of ProviderSID
	--20240103  LM	Changed BHIP label to MH/BHIP to reflect broader definition of this concept
-- =============================================

CREATE PROCEDURE [Code].[Present_GroupAssignments]
AS
BEGIN

DROP TABLE IF EXISTS #providers;
WITH CTE_StationAssignments AS (
	--active patient with join to ProjectDisplay requirement replaces StationAssignments
	----Getting all patients and any station where they might be displayed
	SELECT DISTINCT 
		ap.MVIPersonSID
		,mp.PatientICN
		,ap.PatientPersonSID
		,ap.ChecklistID
		,Sta3n_Loc AS Sta3n
	FROM [Present].[ActivePatient] ap WITH (NOLOCK)
	INNER JOIN [Config].[Present_ProjectDisplayRequirement] d WITH (NOLOCK) 
		ON ap.RequirementID=d.RequirementID
	INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK) 
		ON mp.MVIPersonSID=ap.MVIPersonSID
	--WHERE d.ProjectName IN ('PDSI','STORM'
	)
SELECT DISTINCT 
	 sa.PatientPersonSID
	,sa.MVIPersonSID
	,sa.PatientICN
	,g.GroupType
	,g.GroupID
	,ISNULL(ISNULL(p.ProviderSID,TeamSID),-1) as ProviderSID
	,ISNULL(ISNULL(p.ProviderName,Team),'Unassigned') as   ProviderName
	,ISNULL((CASE WHEN g.GroupID in (2,5) THEN p.ChecklistID
				  WHEN g.GroupID in (3,4) THEN t.ChecklistID END), sa.ChecklistID) as ChecklistID
	,sa.Sta3n
	,c.VISN
	,CASE WHEN g.GroupID in (2,5) THEN p.RelationshipStartDate
		  WHEN g.GroupID in (3,4) THEN t.RelationshipStartDate END as RelationshipStartDate
INTO #providers
FROM CTE_StationAssignments as sa
--Only mandatory assignment (i.e., PCP/MTHC ect) go in this query
INNER JOIN (
	SELECT GroupType
		  ,GroupID 
	FROM [Dim].[GroupType] WITH(NOLOCK)
	WHERE GroupID in (2,3,4,5)	--PCP,BHIP,PACT,MHTC
	) as g on 1 = 1
INNER JOIN [LookUp].[ChecklistID] as c WITH(NOLOCK) on sa.ChecklistID=c.ChecklistID
--Provider Groups
LEFT OUTER JOIN (
    SELECT PatientSID
          ,MVIPersonSID
          ,CASE WHEN AssociateProviderFlag=1 THEN AssociateProviderSID ELSE ISNULL(ProviderSID,TRY_CAST(ProviderEDIPI AS int)) END AS ProviderSID --accounting for AssociateProviderSID
          ,CASE WHEN AssociateProviderFlag=1 THEN StaffNameA ELSE StaffName END as ProviderName
          ,ChecklistID
          ,RelationshipStartDate
          ,CASE WHEN PCP = 1 THEN 2
                WHEN MHTC = 1 THEN 5
                ELSE null
            END GroupID
    FROM [Present].[Provider_Active] WITH(NOLOCK)
    WHERE (PCP = 1 OR MHTC = 1)
    ) as p on 
		sa.MVIPersonSID = p.MVIPersonSID
		AND sa.ChecklistID = p.ChecklistID
		AND p.GroupID = g.GroupID
--Team Groups 
LEFT OUTER JOIN (
	SELECT act.PatientSID
		  ,act.TeamSID
		  ,act.Team
		  ,act.ChecklistID
		  ,act.RelationshipStartDate
		  ,CASE WHEN act.TeamType in ('MH','BHIP') THEN 3
				WHEN act.TeamType = 'PACT' THEN 4 
				ELSE null 
			END GroupID --4=MH/BHIP, 7=PACT
	FROM [Present].[Provider_Active] as act WITH(NOLOCK)
	--INNER JOIN [SStaff].[SStaff] as stf on act.ProviderSID = stf.StaffSID  --this join doesn't do anything. Present_Providers already joins on SStaff and FactStaffDemographic (cerner)
    --where  Team Like '%BHIP%' or Team Like '%PACT%'
	) as t on 
		sa.PatientPersonSID = t.PatientSID 
		AND t.GroupID = g.GroupID
 ; 
-- Among each GroupType, select most recent provider if patient had more than one in same ChecklistID
DROP TABLE IF EXISTS #StageGroupAssignments
SELECT MVIPersonSID
	  ,PatientICN
	  --,PatientSID
	  ,GroupType
	  ,GroupID
	  ,ProviderSID
	  ,ProviderName
	  ,ChecklistID
	  ,Sta3n
	  ,VISN
INTO #StageGroupAssignments
FROM (
	SELECT MVIPersonSID
		  ,PatientICN
		  --,PatientSID
		  ,GroupType
		  ,GroupID
		  ,ProviderSID
		  ,ProviderName
		  ,ChecklistID
		  ,Sta3n
		  ,VISN
		  ,MostRecentRank = ROW_NUMBER() OVER(PARTITION BY MVIPersonSID, ChecklistID, GroupType ORDER BY RelationshipStartDate DESC)
	FROM #providers
	) a
WHERE a.MostRecentRank=1 

/*****Insert Group Type for non mandatory types******/ 
--Prescriber Groups
INSERT INTO #StageGroupAssignments
SELECT DISTINCT
	 m.MVIPersonSID
	,p.PatientICN
	--,m.PatientSID
	,g.GroupType
	,g.GroupID
	,CASE WHEN m.PrescriberSID IS NULL THEN 0 ELSE m.PrescriberSID END as ProviderSID  --null ProviderSIDs coming from Spokane currently
	,m.PrescriberName as ProviderName
	,c.ChecklistID
	,m.Sta3n
	,c.VISN
FROM [Present].[Medications] as m WITH(NOLOCK)
INNER JOIN (
	SELECT GroupType,GroupID 
	FROM [Dim].[GroupType] WITH(NOLOCK)
	WHERE GroupID in (8,9)	--opioid prescriber, PDSI prescriber
	) as g on 
		(Opioid_Rx = 1 AND GroupID = 8) 
		OR (PDSIRelevant_Rx = 1 AND GroupID =  9)
INNER JOIN [LookUp].[Sta6a] as c WITH(NOLOCK) on m.Sta6a = c.Sta6a
INNER JOIN [Common].[MasterPatient] p WITH(NOLOCK) on m.MVIPersonSID = p.MVIPersonSID
WHERE (m.Opioid_Rx = 1 
	OR m.PDSIRelevant_Rx = 1
	) 

	--limit to active Rx because Present.Medications has pills on hand as well
	--AND RxStatus IN ('HOLD', 'SUSPENDED', 'ACTIVE', 'PROVIDER HOLD') 
	
--Inpatient
INSERT INTO #StageGroupAssignments
SELECT DISTINCT a.MVIPersonSID
	  ,PatientICN
	  ,GroupType = 'Inpatient'
	  ,GroupID = 6
	  ,ProviderSID = Flag
	  ,ProviderName = PrintName
	  ,ChecklistID
	  ,Sta3n
	  ,VISN
FROM (
	SELECT MVIPersonSID
		  ,Sta6a as Discharge_Sta6a
		  ,isnull(Flag, 0) Flag
		  ,isnull(Category, 'Other') AS Category
	FROM [Inpatient].[BedSection] AS a  WITH (NOLOCK)
    LEFT OUTER JOIN (
        SELECT PTFCode
                ,Category
                ,Flag
        FROM (
                SELECT DISTINCT PTFCode
                        ,CASE 
                            WHEN Residential_TreatingSpecialty = 1
                                    THEN 1
                            ELSE 0
                            END Residential_TreatingSpecialty
                        ,CASE 
                            WHEN MedSurgInpatient_TreatingSpecialty = 1
                                    THEN 2
                            ELSE 0
                            END MedSurgInpatient_TreatingSpecialty
                        ,CASE 
                            WHEN NursingHome_TreatingSpecialty = 1
                                    THEN 3
                            ELSE 0
                            END NursingHome_TreatingSpecialty
                        ,CASE 
                            WHEN MentalHealth_TreatingSpecialty = 1
                                    THEN 4
                            ELSE 0
                            END MentalHealth_TreatingSpecialty
                        ,CASE 
                            WHEN Domiciliary_TreatingSpecialty = 1
                                    THEN 5
                            ELSE 0
                            END Domiciliary_TreatingSpecialty
                FROM [LookUp].[TreatingSpecialty]  WITH (NOLOCK)
                ) AS p
        UNPIVOT(Flag FOR Category IN (
                            Domiciliary_TreatingSpecialty
                            ,Residential_TreatingSpecialty
                            ,MedSurgInpatient_TreatingSpecialty
                            ,NursingHome_TreatingSpecialty
                            ,MentalHealth_TreatingSpecialty
                            )) AS upvt
        WHERE flag > 0
        ) AS b ON a.bedsection = b.PTFCode
    WHERE [DischargeDateTime] IS NULL
    ) AS a
INNER JOIN [LookUp].[Sta6a] AS b  WITH (NOLOCK) ON a.Discharge_Sta6a = b.sta6a
INNER JOIN [LookUp].[ColumnDescriptions] AS d  WITH (NOLOCK) ON a.category = d.columnName
INNER JOIN [Common].[MasterPatient] p  WITH (NOLOCK) on a.MVIPersonSID = p.MVIPersonSID

--Stop Codes
INSERT INTO #StageGroupAssignments
SELECT DISTINCT a.MVIPersonSID
	  ,PatientICN
	  ,GroupType = 'Outpatient Stop Codes'
	  ,GroupID = 7
	  ,ProviderSID = Flag
	  ,ProviderName = PrintName
	  ,ChecklistID
	  ,a.Sta3n
	  ,VISN
FROM (
	SELECT
		mvi.MVIPersonSID
		,a.Sta3n
		,ISNULL(b.Flag, 0) Flag
		,ISNULL(b.Category, 'Other') AS Category
	FROM [Outpat].[Visit] AS a WITH (NOLOCK)
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
		ON a.PatientSID = mvi.PatientPersonSID
    LEFT OUTER JOIN (
        SELECT
			StopCodeSID 
            ,Category
            ,Flag
        FROM (
				SELECT DISTINCT
					StopCodeSID
					,CASE 
						WHEN GeneralMentalHealth_Stop = 1
							THEN 1
						ELSE 0
						END GeneralMentalHealth_Stop
					,CASE 
						WHEN PrimaryCare_PDSI_Stop = 1
							THEN 2
						ELSE 0
						END PrimaryCare_PDSI_Stop
					,CASE 
						WHEN SUDTx_NoDxReq_Stop = 1
							THEN 3
						ELSE 0
						END SUDTx_NoDxReq_Stop
			FROM [LookUp].[StopCode] WITH (NOLOCK)
			WHERE stopcodesid > 0
                ) AS p
        UNPIVOT(Flag FOR Category IN (
                             GeneralMentalHealth_Stop
                            ,PrimaryCare_PDSI_Stop
							,SUDTx_NoDxReq_Stop
                            )) AS upvt
        WHERE Flag > 0
        ) AS b ON a.PrimaryStopCodeSID = b.StopCodeSID
    WHERE a.VisitDateTime > CAST(DATEADD(DAY, - 366, GETDATE()) AS DATETIME2(0))
    ) AS a
INNER JOIN [LookUp].[Sta6a] b WITH (NOLOCK)
	ON a.Sta3n = b.Sta3n
INNER JOIN [LookUp].[ColumnDescriptions] d WITH (NOLOCK)
	ON a.category = d.columnName
INNER JOIN [Common].[MasterPatient] p WITH (NOLOCK)
	ON a.MVIPersonSID = p.MVIPersonSID

--Cerner Stop Codes
INSERT INTO #StageGroupAssignments
SELECT DISTINCT a.MVIPersonSID
	  ,a.PatientICN
	  ,GroupType = 'Outpatient Stop Codes'
	  ,GroupID = 7
	  ,ProviderSID = Flag
	  ,ProviderName = PrintName
	  ,b.ChecklistID
	  ,a.Sta3n
	  ,b.VISN
FROM (
	SELECT
		mvi.MVIPersonSID
		,mvi.PatientICN
		,a.StaPa
		,Sta3n = 200
		,ISNULL(b.Flag, 0) Flag
		,ISNULL(b.Category, 'Other') AS Category
	FROM [Cerner].[FactUtilizationStopCode] AS a WITH (NOLOCK)
	INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK)
		ON a.PersonSID = mvi.PatientPersonSID
    LEFT OUTER JOIN (
        SELECT
			StopCodeSID 
            ,Category
            ,Flag
        FROM (
				SELECT DISTINCT
					StopCodeSID
					--,CASE 
					--	WHEN GeneralMentalHealth_Stop = 1
					--		THEN 1
					--	ELSE 0
					--	END GeneralMentalHealth_Stop
					,CASE 
						WHEN PrimaryCare_PDSI_Stop = 1
							THEN 2
						ELSE 0
						END PrimaryCare_PDSI_Stop
					,CASE 
						WHEN SUDTx_NoDxReq_Stop = 1
							THEN 3
						ELSE 0
						END SUDTx_NoDxReq_Stop
			FROM [LookUp].[StopCode] WITH (NOLOCK)
			WHERE StopCodeSID > 0
                ) AS p
        UNPIVOT(Flag FOR Category IN (
                             --GeneralMentalHealth_Stop
                            PrimaryCare_PDSI_Stop
							,SUDTx_NoDxReq_Stop
                            )) AS upvt
        WHERE Flag > 0
        ) AS b ON a.CompanyUnitBillTransactionAliasSID = b.StopCodeSID
    WHERE a.TZServiceDateTime > CAST(DATEADD(DAY, - 366, GETDATE()) AS DATETIME2(0))
    ) AS a
INNER JOIN [LookUp].[Sta6a] b  WITH (NOLOCK)
	ON a.StaPa = b.StaPa
INNER JOIN [LookUp].[ColumnDescriptions] d WITH (NOLOCK)
	ON a.category = d.columnName

INSERT INTO #StageGroupAssignments
SELECT DISTINCT a.MVIPersonSID
	  ,b.PatientICN
	  ,GroupType = 'Outpatient Stop Codes'
	  ,GroupID = 7
	  ,ProviderSID = 1
	  ,ProviderName = 'Gen MH Outpatient'
	  ,d.ChecklistID
	  ,d.Sta3n
	  ,d.VISN
FROM [Cerner].[FactUtilizationOutpatient] a WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientICN] b WITH (NOLOCK)
	ON a.MVIPersonSID=b.MVIPersonSID
INNER JOIN [Lookup].[ListMember] c WITH (NOLOCK)
	ON a.ActivityTypeCodeValueSID = c.ItemID
INNER JOIN [Lookup].[ChecklistID] d WITH (NOLOCK) 
	ON a.StaPa = d.StaPa
WHERE c.List = 'MHOC_GMH'


EXEC [Maintenance].[PublishTable] 'Present.GroupAssignments','#StageGroupAssignments';

EXEC sp_refreshview '[Present].[GroupAssignments_STORM]';

END
GO