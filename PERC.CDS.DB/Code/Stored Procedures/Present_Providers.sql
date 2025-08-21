/********************************************************************************************************************
DESCRIPTION: Assigns patients to PCP, MHTC, PACT, BHIP from VSSC table
AUTHOR:		 Shalini Gupta
CREATED:	 02/25/22
UPDATE:
	[YYYY-MM-DD]	[INIT]	[CHANGE DESCRIPTION]
	2019-04-01		RAS		Added logging. Removed PrimaryProviderSID,PrimaryStandardPosition,InstitutionCode,TeamSta6a,ADMPARENT_FCDM from table.
							Created view Present.Provider_Active that filters to ActiveStaff=1.  
							USE THE VIEW unless you specifically need staff with a termination date in CDW.
	2020-04-03      SG		Added associate providers to PCP criteria, Associate PCP name and if they are active.
	2020-04-10		RAS		Added distinct to initial query - appears that information is duplicated across different 
							CurrentPatientProviderRelationshipSIDs in source CDW RPCMM_CurrentPatientProviderRelationship
	2020-04-10		RAS		-	In second query, made join with [RPCMM].[CurrentPatientTeamMembership] distinct because this was exploding table.
							-	Removed inner joins with NDim.RPCMMTeamFocus and NDim.RPCMMTeamPosition because fields were not being
								used or exposed and these joins were excluding rows.
							-	Removed unused fields from initial query: RequestedStartDateTime, TeamPatientAssignStatus, RPCMMTeamCareType
	2020-04-14		RAS		Added fields for ranking providers and teams to expedite the views such as Present.Provider_PCP and Present.Provider_PCP_ICN.
	2020-05-18      SG      Added TeamRole 'PHYSICIAN-ATTENDING' to PCP criteria
	2020-12-02		LM		Cerner overlay
	2021-05-18		JEB		Enclave work - updated NDim Synonym use. No logic changes made.	
	2021-05-18      JEB     Enclave work - updated [SStaff].[SStaff] Synonym use. No logic changes made.
	2021-07-21		AI		Enclave Refactoring - Counts confirmed
	2021-09-17		JEB		Enclave Refactoring - Refactored comment
	2021-09-20		AI		Enclave Refactoring - Refactored change list
	2021-09-20		JEB		Enclave Refactoring - Refactored comment
	2022-03-10		SG		Revamp the code using VSSC PCMM Table, previously we were using CDW RPCMM tables.
	                        Changes - remove column Pcm_std_team_care_type_id,TeamRoleCode,TeamRole not in VSSC table, TeamRole is replaced by PrimaryStandardPosition
							          Update RelationshipEndDateTime to RelationshipEndDate, RelationshipStartDateTime to RelationshipStartDate as per VSSC table
							          update method to get MHTC, PCP, BHIP,PACT flag
									  use vwMVIPersonSIDPatientPersonSID, and vwMVIPersonSIDPatientICN to get the MVIPersonSID 
									  Added CernerSiteFlag and ActiveAny flag
									  Used [NDim].[RPCMMTeam] table to get the TeamSID and Teams
   2022-03-29		SG		PatientSID from Common.MVIPersonSIDPatientPersonSID, two joins with PatientSID and (PatientICN and sta3n)	
   2022-05-25		CMH		Adding code to prevent SP for running and throw an error if provider counts are off
   2022-07-08		JEB		Updated Synonym references to point to Synonyms from Core
   2022-07-26		LM		Updated CernerSiteFlag to reflect facilities using Cerner based on IOC date
   2023-05-24		LM		Changed TerminationDate to TerminationDateTime due to upstream change in SStaff.SStaff
   2023-09-19		AER		Pulling in PatientPersonsid for relationships at CERNER stations
   2023-10-17		AER		Pulling VISTA PatientSID from VISTA facility where patientSID is null in VSSC
   2023-12-28		LM		Limited BHIP team type to only BHIP teams and added MH team which excludes BHIP.  
							Downstream view will combine MH and BHIP team types to get all MH teams
   2024-07-10       CW		Updating source data for PatientICN to fix mis-mapping bug
********************************************************************************************************************/
CREATE   PROCEDURE [Code].[Present_Providers] 
AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC Code.Present_Providers','Execute SP Code.Present_Providers'

 /****************************************************************************/
 /* Assign Team : BHIP, PACT  and ProviderType : MHTC and PCP                */
 /****************************************************************************/
 -- First check data in [PDW].[VSSC_Out_DoEX_VSSCPCMMAssignments] since there have been issues with PCP and MH provider counts being off. 
 -- If counts dont look as expected, log error and do not run procedure (data will be stale)

	DECLARE @PCThreshold INT = 5500000
	DECLARE @MHThreshold INT = 1200000
	
	DECLARE @PCCount BIGINT = (SELECT COUNT_BIG(*) FROM [PDW].[VSSC_Out_DoEX_VSSCPCMMAssignments] WITH (NOLOCK) WHERE TeamPurpose='PRIMARY CARE')
	DECLARE @MHCount BIGINT = (SELECT COUNT_BIG(*) FROM [PDW].[VSSC_Out_DoEX_VSSCPCMMAssignments] WITH (NOLOCK) WHERE TeamPurpose='MENTAL HEALTH')
	IF	(
		@PCCount  < @PCThreshold
		OR @MHCount < @MHThreshold
		)
	BEGIN 
		DECLARE @ErrorMsg varchar(500)=
			CASE WHEN @PCCount < @PCThreshold AND @MHCount < @MHThreshold  THEN 'Primary Care and Mental Health Providers/Teams: '
				WHEN @PCCount < @PCThreshold THEN 'Primary Care Providers/Teams: '
				WHEN @MHCount < @MHThreshold THEN 'Mental Health Providers/Teams: '
				END
			+ 'Row count insufficient to proceed with Code.Present_Providers'
		EXEC [Log].[Message] 'Error','Row Counts',@ErrorMsg
		EXEC [Log].[ExecutionEnd] @Status='Error' --Log end in case of error
		PRINT @ErrorMsg;
		THROW 51000,@ErrorMsg,1
	END


 -- VSSCPCMMAssignments table has all Null TeamSID, but has SynTeamID, getting TeamSID from [NDim].[RPCMMTeam]
 DROP TABLE IF EXISTS #RPCMMTeam
 Select SynTeamID = concat(sta3n,REPLICATE('0', 15 - LEN(Team_ID)) + CAST(Team_ID AS varchar)) 
        ,RPCMMTeamSID
	    ,RPCMMTeam
 INTO #RPCMMTeam
 FROM [NDim].[RPCMMTeam] WITH (NOLOCK)
 -- 22,182


---align patient IDs for VISN and CERNER patients 
DROP TABLE IF EXISTS #VSSC_Out_DoEX_VSSCPCMMAssignments_PatientPerson
SELECT ISNULL(ISNULL(c.PatientPersonSID,PatientSID),d.PatientPersonSID) AS PatientPersonSID
	,a.*
	,mv.mvipersonsid
INTO #VSSC_Out_DoEX_VSSCPCMMAssignments_PatientPerson
FROM [PDW].[VSSC_Out_DoEX_VSSCPCMMAssignments] AS a WITH (NOLOCK) 
LEFT OUTER JOIN Common.MasterPatient AS mv WITH (NOLOCK) 
	ON a.PatientICN = mv.PatientICN
LEFT OUTER JOIN Common.MVIPersonSIDPatientPersonSID AS c WITH (NOLOCK) 
	ON mv.MVIPersonSID = c.MVIPersonSID AND c.Sta3n = 200 AND a.CernerSiteFlag =1
LEFT OUTER JOIN Common.MVIPersonSIDPatientPersonSID AS d WITH (NOLOCK) 
	ON mv.MVIPersonSID = d.MVIPersonSID AND d.Sta3n <> 200 AND d.sta3n=a.sta3n



DROP TABLE IF EXISTS #Providers1
SELECT DISTINCT 
	mvi1.MVIPersonSID
		--, MVIPersonSID1= ISNULL(mvi.MVIPersonSID, 0) 
		--, MVIPersonSID2= ISNULL(mvi1.MVIPersonSID, 0)
	-- mvi.PatientPersonSID as patientSID to get all the PatinetSID's that was missing in the VSSCPCMMAssignments
	,a.PatientPersonSID as PatientSID
	,mvi1.PatientICN
	,a.Sta3n
	-- , a.PatientSID
	,a.AssociateProviderSID
	,a.AssociateStandardPosition
	,a.PrimaryProviderSID
	,a.PrimaryPositionSID
	,a.PrimaryStandardPosition
	,TeamRole=a.PrimaryStandardPosition
	,a.RelationshipStartDate
	,a.RelationshipEndDate	
	,a.ProviderRole
	,tt.RPCMMTeamSID
	,tt.RPCMMTeam AS RPCMMTeam
	,a.TeamSID
	,a.SynTeamID
	,a.Team
	,a.TeamPurpose
	,a.TeamFocus
	,a.InstitutionSid
	,InstitutionCode
	,sta.ChecklistID
	,sta.Sta6a
	,sta.DIVISION_FCDM
	,a.CurrentProviderFlag
	,a.AssociateProviderFlag
	,a.PCPAssBegDate
	,a.PCPProvID
	,a.APProvID
	,a.AsOfDate
	,a.DECEASED
	,a.DOD	
	,a.RPCMM
	,a.ActiveStatus
	,a.NextPCAppointment
	,a.NextPCApptClinicName
	,a.NextPCApptPrimaryStopCode
	,a.AP_STAFF_IEN
	,a.AP_STAFF_EDIPI
	,a.AP_STAFF_CERNER_PERSON_ID	
	,a.PCP_STAFF_IEN
	,a.PCP_STAFF_EDIPI
	,a.PCP_STAFF_CERNER_PERSON_ID
	,CASE WHEN l.IOCDate < getdate() THEN 1 ELSE 0 END AS CernerSiteFlag	
	,a.PatientEDIPI
	,PCP = CASE WHEN a.ProviderRole = 'PC ASSIGNMENT' THEN 1 ELSE 0 END
	,MHTC= CASE WHEN a.PrimaryStandardPosition LIKE '%MHTC%' THEN 1 ELSE 0 END
	,BHIP= CASE WHEN a.Team LIKE '%BHIP%' THEN 1 ELSE 0 END
	,MH= CASE WHEN a.TeamPurpose = 'MENTAL HEALTH' THEN 1 ELSE 0 END
	,PACT= CASE WHEN a.TeamPurpose = 'PRIMARY CARE' THEN 1 ELSE 0 END
	,a.PrimaryProviderSID AS ProviderSID --  In VSSC table PrimaryProviderSID already took care of AssociateProviderFlag = 'Y' then AssociateProviderSID, else PrimaryProviderSID
	-- For Cerner data 
	,PrimaryProviderEDIPI = a.PCP_STAFF_EDIPI-- For cerner 1) No AssociateProviderEDIPI, 2) PCP_STAFF_EDIPI is for all PCP , MHTC etc
INTO #Providers1 
FROM #VSSC_Out_DoEX_VSSCPCMMAssignments_PatientPerson as a WITH (NOLOCK)
-- Join by PatientPersonSID
LEFT JOIN Common.MVIPersonSIDPatientPersonSID AS mvi1 WITH (NOLOCK) 
	ON a.PatientPersonSID = mvi1.PatientPersonSID 
LEFT JOIN #RPCMMTeam tt 
	ON a.SynTeamID = tt.SynTeamID
LEFT JOIN [LookUp].[Sta6a] as sta WITH (NOLOCK)
	ON a.InstitutionCode = sta.Sta6a
LEFT JOIN [Lookup].[ChecklistID] AS l WITH (NOLOCK) 
	ON l.ChecklistID = sta.ChecklistID
    
 -- 7044881 in 35s

-- select count(*) from #Providers1 where mvipersonsid is null where sta3n='668' and PatientSID is null

 /**********************************************************************************/
 /*  Adding Staff information, Vista-sstaff and for Cerner - FactStaffDemographic  */
 /**********************************************************************************/

	DROP TABLE IF EXISTS #Providers
	SELECT a.MVIPersonSID
		  ,a.PatientICN
		  ,a.PatientSID as PatientSID
		  ,a.Sta3n
		  ,a.ChecklistID
		  ,a.Sta6a
		  ,a.DIVISION_FCDM
		  ,a.ProviderSID
		  ,ProviderEDIPI = a.PrimaryProviderEDIPI
		  ,a.RelationshipStartDate 
		  ,a.RelationshipEndDate
		  ,a.RPCMMTeamSID AS TeamSID
	      ,a.RPCMMTeam AS Team
		  ,a.TeamRole
		  ,a.PCP
		  ,a.MHTC
		  ,a.BHIP
		  ,a.PACT

		  --Primary Provider
		  ,a.PrimaryProviderSID
		  ,a.PrimaryProviderEDIPI
		  ,StaffName = case when a.CernerSiteFlag= 1 then sd.NameFullFormatted else  st.StaffName end
		  ,CAST(st.TerminationDateTime as date) AS TerminationDate -- For cerner sites we do not have terminition date
		  ,ActiveStaff = CASE WHEN st.TerminationDateTime > GetDate() or st.TerminationDateTime IS NULL THEN 1 ELSE 0 END
		 
		 --Associate Provider
		  ,a.AssociateProviderFlag
		  ,a.AssociateProviderSID
		  ,StaffNameA=st1.StaffName 
		  ,TerminationDateA=CAST(st1.TerminationDateTime as date)
		  ,ActiveStaffA = CASE WHEN st1.TerminationDateTime > GetDate() or st1.TerminationDateTime IS NULL THEN 1 ELSE 0 END
          
		   --Create categories to partition for ranking in next step
		  ,ProvType = CASE WHEN a.PCP=1 THEN 'PCP' 
				           WHEN a.MHTC=1 THEN 'MHTC' 
				      END 
		  ,TeamType= CASE WHEN PACT=1 THEN 'PACT'
						  WHEN MH=1 THEN 'MH' --replaced with BHIP when applicable in later step
				     END 
		  ,ActiveAny = CASE WHEN CernerSiteFlag <> 1 
		                             and ((st.TerminationDateTime > GetDate() or st.TerminationDateTime IS NULL) 
							         OR (st1.TerminationDateTime > GetDate() or st1.TerminationDateTime IS NULL)) THEN 1 
                            WHEN a.CernerSiteFlag = 1 and a.PrimaryProviderEDIPI IS NOT NULL THEN 1
						ELSE 0 END
         -- Crener related columns
	     ,a.CernerSiteFlag
		 ,a.PCP_STAFF_IEN	
         ,a.PCP_STAFF_EDIPI	
         ,a.PCP_STAFF_CERNER_PERSON_ID	
         ,a.AP_STAFF_IEN	
         ,a.AP_STAFF_EDIPI	
         ,a.AP_STAFF_CERNER_PERSON_ID	
         ,a.PatientEDIPI
	INTO #Providers
	FROM #Providers1 AS a
    LEFT JOIN [SStaff].[SStaff] AS st WITH (NOLOCK) ON a.PrimaryProviderSID = st.StaffSID -- or a.PCP_STAFF_IEN = st.StaffIEN  
	LEFT JOIN [SStaff].[SStaff] AS st1 WITH (NOLOCK) ON a.AssociateProviderSID = st1.StaffSID  -- or a.AP_STAFF_IEN = st.StaffIEN -- Associate provider
	LEFT JOIN [Cerner].[FactStaffDemographic] as sd WITH (NOLOCK) on a.CernerSiteFlag = 1 AND a.PCP_STAFF_EDIPI=sd.EDIPI   --or PCP_STAFF_IEN = sd.EDIPI 
	WHERE a.MVIPersonSID is not null
	-- -- run in 31s

	/****************************************************************************/
	/*  Adding rank to facilitate views                                         */
	/****************************************************************************/
	DROP TABLE IF EXISTS #StageProviders
	SELECT MVIPersonSID
		  ,PatientICN
		  ,PatientSID
		  ,Sta3n
		  ,ChecklistID
		  ,Sta6a
		  ,DivisionName
		  ,ProviderSID
		  ,ProviderEDIPI
		  ,RelationshipStartDate
		  ,RelationshipEndDate
		  ,TeamSID
		  ,Team
		  ,TeamRole
		  ,PCP
		  ,MHTC
		  ,PrimaryProviderSID
		  ,PrimaryProviderEDIPI
		  ,StaffName
		  ,TerminationDate
		  ,ActiveStaff
		  ,AssociateProviderSID
		  --,AssociateProviderEDIPI
		  ,StaffNameA
		  ,TerminationDateA
		  ,ActiveStaffA
		  ,AssociateProviderFlag
		  ,ActiveAny
		  ,ProvType
		  ,CASE WHEN BHIP=1 THEN 'BHIP' ELSE TeamType END AS TeamType
		  ,CernerSiteFlag
		  ,ProvRank_ICN = CASE 
							WHEN ProvType IS NULL 
								OR (ActiveStaff = 0 AND ActiveStaffA = 0) THEN -1 
							ELSE ProvRank_ICN END
		  ,TeamRank_ICN	= CASE 
							WHEN TeamType IS NULL
								OR (ActiveStaff = 0 AND ActiveStaffA = 0) THEN -1 
							ELSE TeamRank_ICN END
		  ,ProvRank_SID	= CASE 
							WHEN ProvType IS NULL
								OR (ActiveStaff = 0 AND ActiveStaffA = 0) THEN -1 
							ELSE ProvRank_SID END
		  ,TeamRank_SID	= CASE 
							WHEN TeamType IS NULL
								OR (ActiveStaff = 0 AND ActiveStaffA = 0) THEN -1 
							ELSE TeamRank_SID END
	INTO #StageProviders
	FROM (
		SELECT MVIPersonSID
			  ,PatientICN
			  ,PatientSID
			  ,Sta3n
			  ,ChecklistID
			  ,Sta6a
			  ,DivisionName =DIVISION_FCDM
			  ,ProviderSID
			  ,ProviderEDIPI
			  ,RelationshipStartDate
			  ,RelationshipEndDate
			  ,TeamSID
			  ,Team 
			  ,TeamRole
			  ,PCP
			  ,MHTC
			  ,PrimaryProviderSID
			  ,PrimaryProviderEDIPI
			  ,StaffName
			  ,TerminationDate
			  ,ActiveStaff
			  ,AssociateProviderSID
			  --,AssociateProviderEDIPI
			  ,StaffNameA
			  ,TerminationDateA
			  ,ActiveStaffA
			  ,AssociateProviderFlag
			  ,ActiveAny
			  ,CernerSiteFlag
			  ,ProvType
			  ,TeamType
			  ,BHIP
			  ,ROW_NUMBER() OVER(PARTITION BY MVIPersonSID,ProvType,ActiveAny ORDER BY RelationshipStartDate DESC) ProvRank_ICN
			  ,ROW_NUMBER() OVER(PARTITION BY MVIPersonSID,TeamType,ActiveAny ORDER BY RelationshipStartDate DESC) TeamRank_ICN
			  ,ROW_NUMBER() OVER(PARTITION BY PatientSID,ProvType,ActiveAny ORDER BY RelationshipStartDate DESC) ProvRank_SID
			  ,ROW_NUMBER() OVER(PARTITION BY PatientSID,TeamType,ActiveAny ORDER BY RelationshipStartDate DESC) TeamRank_SID
        
		FROM #Providers
		WHERE ProviderSID>0 or ProviderEDIPI IS NOT NULL
		) provrank


  /****************************************************************************/
  /*  FOR Present Providers                                                   */
  /****************************************************************************/
   EXEC [Maintenance].[PublishTable] 'Present.Providers', '#StageProviders'
  
   EXEC [Log].[ExecutionEnd]

END
GO
