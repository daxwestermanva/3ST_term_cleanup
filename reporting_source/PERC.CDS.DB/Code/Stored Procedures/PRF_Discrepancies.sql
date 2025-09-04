

/*=============================================
-- Author:		Liam Mina
-- Create date: 2023-06-08
-- Description:	This code gets all national PRF discrepancies between VistA systems or between Cerner and one or more VistA systems.  
				This include patient record flags for suicide, behavioral, or missing patient. Discrepancies may involve the flag status (active/inactive) being different
				at different sites, or flag owners being different at different sites.  National PRFs should be aligned at all sites.
				OIT tickets are generally required for resolving discrepancies; the purpose of this data is to allow for monitoring of and rapid response to discrepancies by national field offices.
-- Updates:
-- 2024-04-04	LM	Limit Cerner/Vista discrepancies to patients who have had contact at a Cerner site due to unreliable CDWWork2 data for patients who have not had contact
-- 2024-05-09	LM	Add History Comments
=========================================================================================================================================*/
CREATE PROCEDURE [Code].[PRF_Discrepancies]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.PRF_Discrepancies', @Description = 'Execution of Code.PRF_Discrepancies SP'

--Suicide flags
	DROP TABLE IF EXISTS #FlagTypeSID_S;
	SELECT DISTINCT NationalPatientRecordFlagSID , NationalPatientRecordFlag
	INTO #FlagTypeSID_S 
	FROM [Dim].[NationalPatientRecordFlag] WITH (NOLOCK) 
	WHERE NationalPatientRecordFlag =  'HIGH RISK FOR SUICIDE'

	DROP TABLE IF EXISTS #flags_S;
	SELECT DISTINCT 
		mvi.MVIPersonSID
		,s.PatientICN
		,prf.PatientSID
		,prf.Sta3n
		,prf.PatientRecordFlagAssignmentSID
		,prf.OwnerInstitutionSID
		,prf.ActiveFlag
		,NationalPatientRecordFlag
		,MAX(h.ActionDateTime) OVER (PARTITION BY h.PatientRecordFlagAssignmentSID) AS MaxActionDate
	INTO #flags_S
	FROM #FlagTypeSID_S f
	INNER JOIN [SPatient].[PatientRecordFlagAssignment] AS prf WITH (NOLOCK)
		ON prf.NationalPatientRecordFlagSID = f.NationalPatientRecordFlagSID
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] AS mvi WITH (NOLOCK)
		ON prf.PatientSID = mvi.PatientPersonSID
	INNER JOIN [Common].[MasterPatient] AS s WITH (NOLOCK)
		ON s.MVIPersonSID = mvi.MVIPersonSID
	LEFT JOIN [SPatient].[PatientRecordFlagHistory] h WITH (NOLOCK)
		ON prf.PatientRecordFlagAssignmentSID = h.PatientRecordFlagAssignmentSID
	WHERE s.TestPatient = 0
	
	DROP TABLE IF EXISTS #MissingRecords_S
	SELECT DISTINCT f.MVIPersonSID
		,f.PatientICN
		,sp.PatientSID
		,sp.Sta3n
		,PatientRecordFlagAssignmentSID=NULL
		,OwnerInstitutionSID=NULL
		,ActiveFlag='M'
		,f.NationalPatientRecordFlag
		,MaxActionDate=CAST(NULL as date)
	INTO #MissingRecords_S
	FROM #flags_S f 
	INNER JOIN [SPatient].[SPatient] sp WITH (NOLOCK)
		ON f.PatientICN = sp.PatientICN 
	LEFT JOIN #flags_S f2
		ON sp.PatientSID= f2.PatientSID
	WHERE f2.PatientSID IS NULL

	DROP TABLE IF EXISTS #AllStations_S
	SELECT MVIPersonSID
		,PatientICN
		,PatientSID
		,Sta3n
		,PatientRecordFlagAssignmentSID
		,OwnerInstitutionSID
		,ActiveFlag
		,NationalPatientRecordFlag
		,MaxActionDate
	INTO #AllStations_S
	FROM #flags_S
	UNION ALL
	SELECT MVIPersonSID
		,PatientICN
		,PatientSID
		,Sta3n
		,PatientRecordFlagAssignmentSID
		,OwnerInstitutionSID
		,ActiveFlag
		,NationalPatientRecordFlag
		,MaxActionDate
	FROM #MissingRecords_S

	DROP TABLE IF EXISTS #SameSiteConflict_S
	SELECT a.MVIPersonSID
		,a.Sta3n
		,a.PatientSID
		,CASE WHEN a.MaxActionDate >= b.MaxActionDate THEN 'Y' ELSE 'N' END AS ActiveFlag
	INTO #SameSiteConflict_S
	FROM (SELECT * FROM #AllStations_S WHERE ActiveFlag='y') a
	INNER JOIN (SELECT * FROM #AllStations_S WHERE ActiveFlag='n') b
		ON a.MVIPersonSID=b.MVIPersonSID AND a.Sta3n=b.Sta3n

	DROP TABLE IF EXISTS #Flags2_S
	SELECT a.* 
	INTO #Flags2_S
	FROM #AllStations_S a
	LEFT JOIN #SameSiteConflict_S b
		on a.PatientSID=b.PatientSID AND a.ActiveFlag <> b.ActiveFlag
	WHERE b.PatientSID IS NULL
	
--Add in facility info
	DROP TABLE IF EXISTS #WithChecklistID_S;
	SELECT prf.MVIPersonSID
		  ,prf.PatientICN
		  ,prf.PatientSID
		  ,prf.Sta3n
		  ,prf.PatientRecordFlagAssignmentSID
		  ,prf.OwnerInstitutionSID
		  ,prf.ActiveFlag
		  ,c.ChecklistID
		  ,c.ADMPARENT_FCDM AS Facility
		  ,prf.NationalPatientRecordFlag 
	INTO #WithChecklistID_S 
	FROM #flags2_S AS prf
	--LEFT JOIN (SELECT * FROM #Flags2_S WHERE ActiveFlag='y') s
	--	ON prf.MVIPersonSID=s.MVIPersonSID
	LEFT JOIN [Dim].[Institution] AS i WITH (NOLOCK) 
		ON i.InstitutionSID=prf.OwnerInstitutionSID
	LEFT JOIN [Lookup].[ChecklistID] AS c WITH (NOLOCK) 
		ON i.StaPa=c.Sta6aID
	ORDER BY ChecklistID
;
	DROP TABLE IF EXISTS #discrepancies_S;
	SELECT a.MVIPersonSID
		,a.PatientICN
		,a.PatientSID
		,a.Sta3n
		,a.PatientRecordFlagAssignmentSID
		,a.OwnerInstitutionSID
		,a.ActiveFlag
		,a.ChecklistID
		,a.Facility
		,a.NationalPatientRecordFlag
	INTO #discrepancies_S
	FROM #WithChecklistID_S AS a
	INNER JOIN ( 
		SELECT MVIPersonSID
			  ,CountFlagSID=COUNT(DISTINCT PatientRecordFlagAssignmentSID)
			  ,CountActiveValue=COUNT(DISTINCT ActiveFlag) 
		FROM #WithChecklistID_S
		GROUP BY MVIPersonSID
		HAVING COUNT(DISTINCT ActiveFlag)>1 --where this is a Y and N for the same patient
	  ) AS ct
	ON a.MVIPersonSID=ct.MVIPersonSID
	;

	DROP TABLE IF EXISTS #othersites_S
	SELECT a.MVIPersonSID
		,a.PatientICN
		,a.PatientSID
		,a.NationalPatientRecordFlag
		,a.Facility AS OwnerFacility
		,a.ChecklistID AS OwnerChecklistID
		,a.ActiveFlag AS OwnerActiveFlagStatus
		,b.Sta3n
		,b.ActiveFlag AS ActiveFlagSta3n
		,a.PatientRecordFlagAssignmentSID
	INTO #othersites_S
	FROM (SELECT * FROM #discrepancies_S WHERE Sta3n=LEFT(ChecklistID,3)) a
	LEFT JOIN  (SELECT * FROM #discrepancies_S WHERE Sta3n<>LEFT(ChecklistID,3)) b
		ON a.MVIPersonSID=b.MVIPersonSID AND a.ActiveFlag <> b.ActiveFlag 
	UNION ALL
	SELECT a.MVIPersonSID
		,a.PatientICN
		,a.PatientSID
		,a.NationalPatientRecordFlag
		,a.Facility AS OwnerFacility
		,a.ChecklistID AS OwnerChecklistID
		,a.ActiveFlag AS OwnerActiveFlagStatus
		,b.Sta3n
		,b.ActiveFlag AS ActiveFlagSta3n
		,a.PatientRecordFlagAssignmentSID
	FROM #discrepancies_S a
	INNER JOIN #discrepancies_S b 
		ON a.MVIPersonSID=b.MVIPersonSID AND a.ChecklistID<>b.ChecklistID 
	
	DROP TABLE IF EXISTS #SuicideFlag
	SELECT TOP 1 WITH TIES * INTO #SuicideFlag FROM (
	SELECT DISTINCT b.Sta3n
		,a.mvipersonsid
		,mp.DateOfDeath_SVeteran
		,a.NationalPatientRecordFlag 
		,c.activeflag
		,c.OwnerFacility
		,ActionDateTime
		,CASE WHEN PatientRecordFlagHistoryAction=1 THEN 'New'
			WHEN PatientRecordFlagHistoryAction=2 THEN 'Continued'
			WHEN PatientRecordFlagHistoryAction=3 THEN 'Inactivated'
			WHEN PatientRecordFlagHistoryAction=4 THEN 'Reactivated'
			ELSE PatientRecordFlagHistoryAction END AS PatientRecordFlagHistoryAction
		,c.PatientRecordFlagHistoryComments
	FROM #discrepancies_S a
	LEFT JOIN [SPatient].[SPatient] b WITH (NOLOCK) ON a.patienticn=b.patienticn
	LEFT JOIN (SELECT h.PatientSID, prf.Sta3n, ActiveFlag, c.ChecklistID AS OwnerFacility, h.ActionDateTime, h.PatientRecordFlagHistoryAction, h.PatientRecordFlagHistoryComments
				FROM (SELECT TOP 1 WITH TIES * FROM SPatient.PatientRecordFlagAssignment WITH (NOLOCK) 
					ORDER BY ROW_NUMBER() OVER (PARTITION BY PatientSID, NationalPatientRecordFlagSID ORDER BY CASE WHEN ActiveFlag='N' THEN 1 ELSE 2 END)) prf
				INNER JOIN #FlagTypeSID_S s on prf.NationalPatientRecordFlagSID=s.NationalPatientRecordFlagSID
				INNER JOIN [Dim].[Institution] AS i WITH (NOLOCK) 
				ON i.InstitutionSID=prf.OwnerInstitutionSID
				LEFT JOIN [Lookup].[ChecklistID] AS c WITH (NOLOCK) 
				ON i.StaPa=c.Sta6aID
				LEFT JOIN (SELECT TOP 1 WITH TIES * FROM Spatient.PatientRecordFlagHistory
					ORDER BY ROW_NUMBER() OVER (PARTITION BY PatientSID, PatientRecordFlagAssignmentSID ORDER BY ActionDateTime DESC)) h
				ON h.PatientSID=prf.PatientSID AND h.PatientRecordFlagAssignmentSID=prf.PatientRecordFlagAssignmentSID
				) c
		ON b.PatientSID=c.PatientSID
	LEFT JOIN Common.MasterPatient mp WITH (NOLOCK) 
		ON a.MVIPersonSID = mp.MVIPersonSID
	)t
	ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, Sta3n ORDER BY CASE WHEN ActiveFlag IS NOT NULL THEN 1 ELSE 2 END)
	;

--Behavioral flags
	DROP TABLE IF EXISTS #FlagTypeSID_B;
	SELECT DISTINCT NationalPatientRecordFlagSID, NationalPatientRecordFlag
	INTO #FlagTypeSID_B
	FROM [Dim].[NationalPatientRecordFlag] WITH (NOLOCK) 
	WHERE NationalPatientRecordFlag = 'BEHAVIORAL'
	
	DROP TABLE IF EXISTS #flags_B;
	SELECT DISTINCT 
		mvi.MVIPersonSID
		,s.PatientICN
		,prf.PatientSID
		,prf.Sta3n
		,prf.PatientRecordFlagAssignmentSID
		,prf.OwnerInstitutionSID
		,prf.ActiveFlag
		,NationalPatientRecordFlag
		,MAX(h.ActionDateTime) OVER (PARTITION BY h.PatientRecordFlagAssignmentSID) AS MaxActionDate
	INTO #flags_B
	FROM #FlagTypeSID_B f
	INNER JOIN [SPatient].[PatientRecordFlagAssignment] AS prf WITH (NOLOCK)
		ON prf.NationalPatientRecordFlagSID = f.NationalPatientRecordFlagSID
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] AS mvi WITH (NOLOCK)
		ON prf.PatientSID = mvi.PatientPersonSID
	INNER JOIN [Common].[MasterPatient] AS s WITH (NOLOCK)
		ON s.MVIPersonSID = mvi.MVIPersonSID
	LEFT JOIN [SPatient].[PatientRecordFlagHistory] h WITH (NOLOCK)
		ON prf.PatientRecordFlagAssignmentSID = h.PatientRecordFlagAssignmentSID
	WHERE s.TestPatient = 0

	DROP TABLE IF EXISTS #MissingRecords_B
	SELECT DISTINCT f.MVIPersonSID
		,f.PatientICN
		,sp.PatientSID
		,sp.Sta3n
		,PatientRecordFlagAssignmentSID=NULL
		,OwnerInstitutionSID=NULL
		,ActiveFlag='M'
		,f.NationalPatientRecordFlag
		,MaxActionDate=CAST(NULL as date)
	INTO #MissingRecords_B
	FROM #flags_B f 
	INNER JOIN [SPatient].[SPatient] sp WITH (NOLOCK)
		ON f.PatientICN = sp.PatientICN 
	LEFT JOIN #flags_B f2
		ON sp.PatientSID= f2.PatientSID
	WHERE f2.PatientSID IS NULL

	DROP TABLE IF EXISTS #AllStations_B
	SELECT MVIPersonSID
		,PatientICN
		,PatientSID
		,Sta3n
		,PatientRecordFlagAssignmentSID
		,OwnerInstitutionSID
		,ActiveFlag
		,NationalPatientRecordFlag
		,MaxActionDate
	INTO #AllStations_B
	FROM #flags_B
	UNION ALL
	SELECT MVIPersonSID
		,PatientICN
		,PatientSID
		,Sta3n
		,PatientRecordFlagAssignmentSID
		,OwnerInstitutionSID
		,ActiveFlag
		,NationalPatientRecordFlag
		,MaxActionDate
	FROM #MissingRecords_B
		
	DROP TABLE IF EXISTS #SameSiteConflict_B
	SELECT a.MVIPersonSID
		,a.Sta3n
		,a.PatientSID 
		,CASE WHEN a.MaxActionDate >= b.MaxActionDate THEN 'Y' ELSE 'N' END AS ActiveFlag
	INTO #SameSiteConflict_B
	FROM (SELECT * FROM #AllStations_B WHERE ActiveFlag='Y') a
	INNER JOIN (SELECT * FROM #AllStations_B WHERE ActiveFlag='N') b
		ON a.MVIPersonSID=b.MVIPersonSID AND a.Sta3n=b.Sta3n

	DROP TABLE IF EXISTS #Flags2_B
	SELECT a.* 
	INTO #Flags2_B
	FROM #AllStations_B a
	LEFT JOIN #SameSiteConflict_B b
		ON a.PatientSID=b.PatientSID AND a.ActiveFlag <> b.ActiveFlag
	WHERE b.PatientSID IS NULL
	
--Add in facility info
	DROP TABLE IF EXISTS #WithChecklistID_B;
	SELECT prf.MVIPersonSID
		  ,prf.PatientICN
		  ,prf.PatientSID
		  ,prf.Sta3n
		  ,prf.PatientRecordFlagAssignmentSID
		  ,prf.OwnerInstitutionSID
		  ,prf.ActiveFlag
		  ,c.ChecklistID
		  ,c.ADMPARENT_FCDM AS Facility
		  ,prf.NationalPatientRecordFlag
	INTO #WithChecklistID_B 
	FROM #flags2_B AS prf
	--LEFT JOIN (SELECT * FROM #Flags2_B WHERE ActiveFlag='y') s
	--	ON prf.MVIPersonSID=s.MVIPersonSID
	LEFT JOIN [Dim].[Institution] AS i WITH (NOLOCK) 
		ON i.InstitutionSID=prf.OwnerInstitutionSID
	LEFT JOIN [Lookup].[ChecklistID] AS c WITH (NOLOCK) 
		ON i.StaPa=c.Sta6aID
	ORDER BY ChecklistID
	  ;
	
	DROP TABLE IF EXISTS #discrepancies_B;
	SELECT a.MVIPersonSID
		,a.PatientICN
		,a.PatientSID
		,a.Sta3n
		,a.PatientRecordFlagAssignmentSID
		,a.OwnerInstitutionSID
		,a.ActiveFlag
		,a.ChecklistID
		,a.Facility
		,a.NationalPatientRecordFlag
	INTO #discrepancies_B
	FROM #WithChecklistID_B AS a
	INNER JOIN ( 
		SELECT MVIPersonSID
			  ,CountFlagSID=COUNT(DISTINCT PatientRecordFlagAssignmentSID)
			  ,CountActiveValue=COUNT(DISTINCT ActiveFlag) 
		FROM #WithChecklistID_B
		GROUP BY MVIPersonSID
		HAVING COUNT(DISTINCT ActiveFlag)>1 --where this is a Y and N for the same patient
	  ) AS ct
	ON a.MVIPersonSID=ct.MVIPersonSID
	;
	
	DROP TABLE IF EXISTS #BehavioralFlag
	SELECT TOP 1 WITH TIES * INTO #BehavioralFlag FROM (
	select DISTINCT b.Sta3n
		,a.mvipersonsid
		,mp.DateOfDeath_SVeteran
		,a.NationalPatientRecordFlag 
		,c.activeflag
		,c.OwnerFacility
		,c.ActionDateTime
		,CASE WHEN PatientRecordFlagHistoryAction=1 THEN 'New'
			WHEN PatientRecordFlagHistoryAction=2 THEN 'Continued'
			WHEN PatientRecordFlagHistoryAction=3 THEN 'Inactivated'
			WHEN PatientRecordFlagHistoryAction=4 THEN 'Reactivated'
			ELSE PatientRecordFlagHistoryAction 
			END AS PatientRecordFlagHistoryAction
		,c.PatientRecordFlagHistoryComments
	FROM #discrepancies_B a
	LEFT JOIN SPatient.SPatient b WITH (NOLOCK) 
		ON a.PatientSID=b.PatientSID
	LEFT JOIN (SELECT prf.PatientSID, prf.sta3n, prf.ActiveFlag, c.ChecklistID AS OwnerFacility, h.ActionDateTime, h.PatientRecordFlagHistoryAction,h.PatientRecordFlagAssignmentSID, h.PatientRecordFlagHistoryComments
				FROM (SELECT TOP 1 WITH TIES * FROM SPatient.PatientRecordFlagAssignment WITH (NOLOCK) 
					ORDER BY ROW_NUMBER() OVER (PARTITION BY PatientSID, NationalPatientRecordFlagSID ORDER BY CASE WHEN ActiveFlag='N' THEN 1 ELSE 2 END)) prf 
				INNER JOIN #FlagTypeSID_B s on prf.NationalPatientRecordFlagSID=s.NationalPatientRecordFlagSID
				INNER JOIN [Dim].[Institution] AS i WITH (NOLOCK) 
					ON i.InstitutionSID=prf.OwnerInstitutionSID
				LEFT JOIN [Lookup].[ChecklistID] AS c WITH (NOLOCK) 
					ON i.StaPa=c.Sta6aID
				LEFT JOIN (SELECT TOP 1 WITH TIES * FROM SPatient.PatientRecordFlagHistory
					ORDER BY ROW_NUMBER() OVER (PARTITION BY PatientSID, PatientRecordFlagAssignmentSID ORDER BY ActionDateTime DESC)) h
				on h.PatientSID=prf.PatientSID AND h.PatientRecordFlagAssignmentSID=prf.PatientRecordFlagAssignmentSID
			) c
	on b.PatientSID=c.PatientSID
	LEFT JOIN Common.MasterPatient mp WITH (NOLOCK) 
		ON a.MVIPersonSID = mp.MVIPersonSID
	) t
	ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, Sta3n ORDER BY CASE WHEN ActiveFlag IS NOT NULL THEN 1 ELSE 2 END)
	; 
--Missing Patient Flag
	DROP TABLE IF EXISTS #FlagTypeSID_M;
	SELECT DISTINCT NationalPatientRecordFlagSID, NationalPatientRecordFlag
	INTO #FlagTypeSID_M
	FROM [Dim].[NationalPatientRecordFlag] WITH (NOLOCK) 
	WHERE NationalPatientRecordFlag = 'MISSING PATIENT'
	
	DROP TABLE IF EXISTS #flags_M;
	SELECT DISTINCT 
		mvi.MVIPersonSID
		,s.PatientICN
		,prf.PatientSID
		,prf.Sta3n
		,prf.PatientRecordFlagAssignmentSID
		,prf.OwnerInstitutionSID
		,prf.ActiveFlag
		,NationalPatientRecordFlag
		,MAX(h.ActionDateTime) OVER (PARTITION BY h.PatientRecordFlagAssignmentSID) AS MaxActionDate
	INTO #flags_M
	FROM #FlagTypeSID_M f
	INNER JOIN [SPatient].[PatientRecordFlagAssignment] AS prf WITH (NOLOCK)
		ON prf.NationalPatientRecordFlagSID = f.NationalPatientRecordFlagSID
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] AS mvi WITH (NOLOCK)
		ON prf.PatientSID = mvi.PatientPersonSID
	INNER JOIN [Common].[MasterPatient] AS s WITH (NOLOCK)
		ON s.MVIPersonSID = mvi.MVIPersonSID
	LEFT JOIN [SPatient].[PatientRecordFlagHistory] h WITH (NOLOCK)
		ON prf.PatientRecordFlagAssignmentSID = h.PatientRecordFlagAssignmentSID
	WHERE s.TestPatient = 0

	DROP TABLE IF EXISTS #MissingRecords_M
	SELECT DISTINCT f.MVIPersonSID
		,f.PatientICN
		,sp.PatientSID
		,sp.Sta3n
		,PatientRecordFlagAssignmentSID=NULL
		,OwnerInstitutionSID=NULL
		,ActiveFlag='M'
		,f.NationalPatientRecordFlag
		,MaxActionDate=CAST(NULL as date)
	INTO #MissingRecords_M
	FROM #flags_M f 
	INNER JOIN [SPatient].[SPatient] sp WITH (NOLOCK)
		ON f.PatientICN = sp.PatientICN 
	LEFT JOIN #flags_M f2
		ON sp.PatientSID= f2.PatientSID
	WHERE f2.PatientSID IS NULL

	DROP TABLE IF EXISTS #AllStations_M
	SELECT MVIPersonSID
		,PatientICN
		,PatientSID
		,Sta3n
		,PatientRecordFlagAssignmentSID
		,OwnerInstitutionSID
		,ActiveFlag
		,NationalPatientRecordFlag
		,MaxActionDate
	INTO #AllStations_M
	FROM #flags_M
	UNION ALL
	SELECT MVIPersonSID
		,PatientICN
		,PatientSID
		,Sta3n
		,PatientRecordFlagAssignmentSID
		,OwnerInstitutionSID
		,ActiveFlag
		,NationalPatientRecordFlag
		,MaxActionDate
	FROM #MissingRecords_M
		
	DROP TABLE IF EXISTS #SameSiteConflict_M
	SELECT a.MVIPersonSID
		,a.Sta3n
		,a.PatientSID 
		,CASE WHEN a.MaxActionDate >= b.MaxActionDate THEN 'Y' ELSE 'N' END AS ActiveFlag
	INTO #SameSiteConflict_M
	FROM (SELECT * FROM #AllStations_M WHERE ActiveFlag='y') a
	INNER JOIN (SELECT * FROM #AllStations_M WHERE ActiveFlag='n') b
		ON a.MVIPersonSID=b.MVIPersonSID AND a.Sta3n=b.Sta3n
	
	DROP TABLE IF EXISTS #Flags2_M
	SELECT a.* INTO #Flags2_M
	FROM #AllStations_M a
	LEFT JOIN #SameSiteConflict_M b
		on a.PatientSID=b.PatientSID AND a.ActiveFlag <> b.ActiveFlag
	WHERE b.PatientSID IS NULL

--Add in facility info
	DROP TABLE IF EXISTS #WithChecklistID_M;
	SELECT prf.MVIPersonSID
		  ,prf.PatientICN
		  ,prf.PatientSID
		  ,prf.Sta3n
		  ,prf.PatientRecordFlagAssignmentSID
		  ,prf.OwnerInstitutionSID
		  ,prf.ActiveFlag
		  ,c.ChecklistID
		  ,c.ADMPARENT_FCDM AS Facility
		  ,prf.NationalPatientRecordFlag
	INTO #WithChecklistID_M 
	FROM #flags2_M AS prf
	--INNER JOIN (SELECT * FROM #Flags2_M WHERE ActiveFlag='y') s
	--	ON prf.MVIPersonSID=s.MVIPersonSID
	LEFT JOIN [Dim].[Institution] AS i WITH (NOLOCK) 
		ON i.InstitutionSID=prf.OwnerInstitutionSID
	LEFT JOIN [Lookup].[ChecklistID] AS c WITH (NOLOCK) 
		ON i.StaPa=c.Sta6aID
	ORDER BY ChecklistID
	  ;

	DROP TABLE IF EXISTS #discrepancies_M;
	SELECT a.MVIPersonSID
		,a.PatientICN
		,a.PatientSID
		,a.Sta3n
		,a.PatientRecordFlagAssignmentSID
		,a.OwnerInstitutionSID
		,a.ActiveFlag
		,a.ChecklistID
		,a.Facility
		,a.NationalPatientRecordFlag
	INTO #discrepancies_M
	FROM #WithChecklistID_M AS a
	INNER JOIN ( 
		SELECT MVIPersonSID
			  ,CountFlagSID=COUNT(DISTINCT PatientRecordFlagAssignmentSID)
			  ,CountActiveValue=COUNT(DISTINCT ActiveFlag) 
		FROM #WithChecklistID_M
		GROUP BY MVIPersonSID
		HAVING COUNT(DISTINCT ActiveFlag)>1 --where this is a Y and N for the same patient
	  ) AS ct
	ON a.MVIPersonSID=ct.MVIPersonSID
	;
	
	DROP TABLE IF EXISTS #MissingPatientFlag
	SELECT TOP 1 WITH TIES * INTO #MissingPatientFlag FROM (
	SELECT DISTINCT b.Sta3n
		,a.MVIPersonSID
		,mp.DateOfDeath_SVeteran
		,a.NationalPatientRecordFlag 
		,c.ActiveFlag
		,c.OwnerFacility
		,c.ActionDateTime
		,CASE WHEN PatientRecordFlagHistoryAction=1 THEN 'New'
			WHEN PatientRecordFlagHistoryAction=2 THEN 'Continued'
			WHEN PatientRecordFlagHistoryAction=3 THEN 'Inactivated'
			WHEN PatientRecordFlagHistoryAction=4 THEN 'Reactivated'
			ELSE PatientRecordFlagHistoryAction 
			END AS PatientRecordFlagHistoryAction
		,c.PatientRecordFlagHistoryComments
	FROM #discrepancies_M a
	LEFT JOIN SPatient.SPatient b WITH (NOLOCK) on a.PatientICN=b.PatientICN
	LEFT JOIN (SELECT prf.PatientSID, prf.Sta3n, ActiveFlag, c.ChecklistID AS OwnerFacility, h.ActionDateTime, h.PatientRecordFlagHistoryAction, h.PatientRecordFlagHistoryComments
				FROM (SELECT TOP 1 WITH TIES * FROM SPatient.PatientRecordFlagAssignment WITH (NOLOCK) 
					ORDER BY ROW_NUMBER() OVER (PARTITION BY PatientSID, NationalPatientRecordFlagSID ORDER BY CASE WHEN ActiveFlag='N' THEN 1 ELSE 2 END)) prf 
				INNER JOIN #FlagTypeSID_M s on prf.NationalPatientRecordFlagSID=s.NationalPatientRecordFlagSID
				INNER JOIN [Dim].[Institution] AS i WITH (NOLOCK) 
					ON i.InstitutionSID=prf.OwnerInstitutionSID
				LEFT JOIN [Lookup].[ChecklistID] AS c WITH (NOLOCK) 
					ON i.StaPa=c.Sta6aID
				LEFT JOIN (SELECT TOP 1 WITH TIES * FROM SPatient.PatientRecordFlagHistory
					ORDER BY ROW_NUMBER() OVER (PARTITION BY PatientSID, PatientRecordFlagAssignmentSID ORDER BY ActionDateTime DESC)) h
				ON h.PatientSID=prf.PatientSID AND h.PatientRecordFlagAssignmentSID=prf.PatientRecordFlagAssignmentSID) c
		ON b.PatientSID=c.PatientSID 
	LEFT JOIN Common.MasterPatient mp WITH (NOLOCK) 
		ON a.MVIPersonSID = mp.MVIPersonSID
	) t
	ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, Sta3n ORDER BY CASE WHEN ActiveFlag IS NOT NULL THEN 1 ELSE 2 END)

	DROP TABLE IF EXISTS #Together
	SELECT DISTINCT * INTO #Together
	FROM #SuicideFlag
	UNION ALL
	SELECT DISTINCT * FROM #BehavioralFlag
	UNION ALL
	SELECT DISTINCT * FROM #MissingPatientFlag


	--DELETE FROM #Together
	--where left(ownerchecklistid,3)=sta3n

	--DELETE FROM #Together
	--where OwnerActiveFlagStatus=ActiveFlagSta3n


	--Cerner

	DROP TABLE IF EXISTS #CernerFlags
	SELECT TOP 1 WITH TIES a.*
		,CASE WHEN l.StaPa IS NULL THEN 1 ELSE 0 END AS Ignore
	INTO #CernerFlags
	FROM [Cerner].[FactPatientRecordFlag] a WITH (NOLOCK)
	INNER JOIN [Cerner].[FactUtilizationStopCode] s WITH (NOLOCK) --limit to patients who have had contact at an Oracle Health site; other records may be unreliable
		ON a.MVIPersonSID = s.MVIPersonSID
	LEFT JOIN [Lookup].[ChecklistID] l WITH (NOLOCK)
		ON l.STAPA=a.StaPa AND l.IOCDate < getdate()
	WHERE  a.StaPa <> '459' --Hawaii flags still managed through VistA; only inpatient unit on Cerner currently
	ORDER BY ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID, DerivedPRFType ORDER BY a.TZDerivedModifiedDateTime DESC, DerivedHistoryTrackingSID DESC)

	UPDATE #CernerFlags
	SET ActiveFlag = 'N'
	WHERE DerivedActionType = 3

	DELETE FROM #CernerFlags
	WHERE Ignore=1
	
	INSERT INTO #Together
	SELECT Sta3n=200, b.MVIPersonSID,a.DateOfDeath_SVeteran, b.DerivedPRFType, b.ActiveFlag, b.StaPa, b.TZDerivedModifiedDateTime, b.DerivedActionTypeDescription, PatientRecordFlagHistoryComments=NULL
	FROM #Together a
	INNER JOIN #CernerFlags b ON a.MVIPersonSID = b.MVIPersonSID AND a.NationalPatientRecordFlag=b.DerivedPRFType

	DROP TABLE IF EXISTS #CernerVistaDiscrepancies_S
	SELECT TOP 1 WITH TIES
		ISNULL(b.MVIPersonSID, a.MVIPersonSID) AS MVIPersonSID
		,b.PatientICN
		,ActiveFlagVistA=CASE WHEN b.MVIPersonSID IS NOT NULL THEN 'Y' ELSE 'N' END
		,NationalPatientRecordFlag='High Risk for Suicide'
		,a.ActiveFlag AS CernerActiveFlag
		,Sta3n_EHR=200
		,a.StaPa
		,a.TZDerivedModifiedDateTime
		,a.DerivedActionTypeDescription
	INTO #CernerVistaDiscrepancies_S
	FROM #CernerFlags a
	LEFT JOIN PRF_HRS.ActivePRF b WITH (NOLOCK) on a.MVIPersonSID = b.MVIPersonSID
	WHERE a.DerivedPRFType='High Risk for Suicide' AND ((b.MVIPersonSID IS NULL AND a.ActiveFlag='Y') OR (b.MVIPersonSID IS NOT NULL AND a.ActiveFlag='N'))
	ORDER BY ROW_NUMBER() OVER (PARTITION BY ISNULL(a.MVIPersonSID,b.MVIPersonSID) ORDER BY a.TZDerivedModifiedDateTime DESC)


	DROP TABLE IF EXISTS #CernerVistaDiscrepancies_MB
	SELECT TOP 1 WITH TIES
		ISNULL(b.MVIPersonSID, a.MVIPersonSID) AS MVIPersonSID
		,c.PatientICN
		,ActiveFlagVistA=ISNULL(b.ActiveFlag,'N')
		,NationalPatientRecordFlag=a.DerivedPRFType
		,a.ActiveFlag AS CernerActiveFlag
		,Sta3n_EHR=200
		,a.StaPa
		,a.TZDerivedModifiedDateTime
		,a.DerivedActionTypeDescription
	INTO #CernerVistaDiscrepancies_MB
	FROM #CernerFlags a
	INNER JOIN Common.vwMVIPersonSIDPatientICN c WITH (NOLOCK) on a.MVIPersonSID=c.MVIPersonSID
	LEFT JOIN PRF.BehavioralMissingPatient b WITH (NOLOCK) on a.MVIPersonSID = b.MVIPersonSID AND a.DerivedPRFType=b.NationalPatientRecordFlag
	WHERE a.DerivedPRFType IN ('Behavioral','Missing Patient')
	AND (((b.MVIPersonSID IS NULL OR b.ActiveFlag='N') AND a.ActiveFlag='Y') OR (b.ActiveFlag ='Y' AND a.ActiveFlag='N'))
	ORDER BY ROW_NUMBER() OVER (PARTITION BY a.MVIPersonSID, a.DerivedPRFType ORDER BY a.TZDerivedModifiedDateTime DESC)

	--Cerner Vista flag discrepancies - get VistA data
	DROP TABLE IF EXISTS #CernerDiscrepanciesAll
	SELECT DISTINCT m.PatientName
		,m.LastFour
		,m.PatientICN
		,m.EDIPI
		,m.DateOfDeath_SVeteran
		,m.MVIPersonSID
		,a.NationalPatientRecordFlag
		,Sta3n=200
		,a.CernerActiveFlag
		,d.ChecklistID AS OwnerFacility
		,a.TZDerivedModifiedDateTime AS LastActionDateTime
		,a.DerivedActionTypeDescription	
		,a.StaPa
	INTO #CernerDiscrepanciesAll		
	FROM (
		SELECT * FROM #CernerVistaDiscrepancies_S 
		UNION ALL
		SELECT * FROM #CernerVistaDiscrepancies_MB) a
	INNER JOIN Common.MasterPatient m WITH (NOLOCK) 
		ON a.MVIPersonSID=m.MVIPersonSID
	INNER JOIN Lookup.ChecklistID d WITH (NOLOCK) 
		ON a.StaPa = d.StaPa

	DROP TABLE IF EXISTS #AddVistARecords
	SELECT DISTINCT b.Sta3n
		,a.MVIPersonSID
		,a.DateOfDeath_SVeteran
		,ISNULL(c.NationalPatientRecordFlag,a.NationalPatientRecordFlag) AS NationalPatientRecordFlag
		,c.ActiveFlag
		,c.OwnerFacility
		,c.ActionDateTime
		,CASE WHEN c.PatientRecordFlagHistoryAction=1 THEN 'New'
			WHEN c.PatientRecordFlagHistoryAction=2 THEN 'Continued'
			WHEN c.PatientRecordFlagHistoryAction=3 THEN 'Inactivated'
			WHEN c.PatientRecordFlagHistoryAction=4 THEN 'Reactivated'
			ELSE c.PatientRecordFlagHistoryAction 
			END AS PatientRecordFlagHistoryAction
		,c.PatientRecordFlagHistoryComments
	INTO #AddVistARecords
	FROM #CernerDiscrepanciesAll a
	INNER JOIN SPatient.SPatient b WITH (NOLOCK) ON a.PatientICN=b.PatientICN
	LEFT JOIN SPatient.PatientRecordFlagAssignment prf WITH (NOLOCK) ON prf.PatientSID = b.PatientSID 
	LEFT JOIN (SELECT h.PatientSID, prf.Sta3n, ActiveFlag, c.ChecklistID AS OwnerFacility, h.ActionDateTime, h.PatientRecordFlagHistoryAction, s.NationalPatientRecordFlag, h.PatientRecordFlagHistoryComments
				FROM SPatient.PatientRecordFlagAssignment prf WITH (NOLOCK) 
				INNER JOIN (SELECT * FROM #FlagTypeSID_M
							UNION ALL
							SELECT * FROM #FlagTypeSID_B
							UNION ALL
							SELECT * FROM #FlagTypeSID_S) s
								ON prf.NationalPatientRecordFlagSID=s.NationalPatientRecordFlagSID
				INNER JOIN [Dim].[Institution] AS i WITH (NOLOCK) 
				ON i.InstitutionSID=prf.OwnerInstitutionSID
				LEFT JOIN [Lookup].[ChecklistID] AS c WITH (NOLOCK) 
				ON i.StaPa=c.Sta6aID
				LEFT JOIN (SELECT TOP 1 WITH TIES * FROM Spatient.PatientRecordFlagHistory
					ORDER BY ROW_NUMBER() OVER (PARTITION BY PatientSID, PatientRecordFlagAssignmentSID ORDER BY ActionDateTime DESC)) h
				on h.PatientSID=prf.PatientSID AND h.PatientRecordFlagAssignmentSID=prf.PatientRecordFlagAssignmentSID) c
		ON b.PatientSID=c.PatientSID AND a.NationalPatientRecordFlag=c.NationalPatientRecordFlag
	LEFT JOIN #Together t ON a.MVIPersonSID = t.MVIPersonSID AND a.NationalPatientRecordFlag=t.NationalPatientRecordFlag
	WHERE t.MVIPersonSID IS NULL

	DROP TABLE IF EXISTS #Final
	SELECT DISTINCT * 
		,CASE WHEN MIN(CASE WHEN Active_Sta3n='Y' THEN 0 ELSE 1 END) OVER (PARTITION BY MVIPersonSID, NationalPatientRecordFlag) = 0 THEN 1 ELSE 0 END AS ActiveAnywhere --identify records where at least one record is active
		,CASE WHEN MAX(CAST(LastActionDateTime as date)) OVER (PARTITION BY MVIPersonSID, NationalPatientRecordFlag) >= DATEADD(day,-2,CAST(getdate() AS date)) THEN 1 ELSE 0 END AS DropRecord
	INTO #Final
	FROM (
	SELECT a.MVIPersonSID
			,a.DateOfDeath_SVeteran
			,a.NationalPatientRecordFlag
			,a.Sta3n
			,a.ActiveFlag AS Active_Sta3n
			,a.OwnerFacility
			,a.ActionDateTime AS LastActionDateTime
			,a.PatientRecordFlagHistoryAction AS LastActionType
			,LEFT(a.PatientRecordFlagHistoryComments,100) AS PatientRecordFlagHistoryComments
			,SourceEHR=CASE WHEN MAX(CASE WHEN a.OwnerFacility IN (SELECT ChecklistID FROM [Lookup].[ChecklistID] WITH (NOLOCK) WHERE IOCDate < getdate()) THEN 2 ELSE 1 END) 
				OVER (PARTITION BY a.MVIPersonSID,a.NationalPatientRecordFlag) = 2 THEN 'VM' ELSE 'V' END
		FROM #Together a 

		UNION ALL
	
		SELECT a.MVIPersonSID
			,a.DateOfDeath_SVeteran
			,a.NationalPatientRecordFlag
			,Sta3n=200
			,a.CernerActiveFlag
			,d.ChecklistID AS OwnerFacility
			,a.LastActionDateTime
			,a.DerivedActionTypeDescription
			,PatientRecordFlagHistoryComments=NULL
			,SourceEHR='VM'
		FROM #CernerDiscrepanciesAll a 
		INNER JOIN Lookup.ChecklistID d WITH (NOLOCK) on a.StaPa = d.StaPa
	
		UNION ALL

		SELECT a.MVIPersonSID
			,a.DateOfDeath_SVeteran
			,a.NationalPatientRecordFlag
			,a.Sta3n
			,a.ActiveFlag AS Active_Sta3n
			,a.OwnerFacility
			,a.ActionDateTime AS LastActionDateTime
			,a.PatientRecordFlagHistoryAction AS LastActionType
			,LEFT(a.PatientRecordFlagHistoryComments,100) AS PatientRecordFlagHistoryComments
			,SourceEHR='VM'
		FROM #AddVistARecords a 
		) f
		
	DELETE FROM #Final WHERE DropRecord=1 --don't include cases where there was an action in the past 2 days; discrepancy is likely due to timing of data tranmission
	
	--Ensure that records with no discrepancies are dropped; this seems to be an issue related to the timing of the run
	DROP TABLE IF EXISTS #CompareRecords
	SELECT DISTINCT MVIPersonSID
		,CASE WHEN Active_Sta3n IS NULL THEN 'U' ELSE Active_Sta3n END AS Active_Sta3n
		,NationalPatientRecordFlag
		,COUNT(*) OVER (PARTITION BY MVIPersonSID, NationalPatientRecordFlag) AS TotalCount
	INTO #CompareRecords
	FROM #Final ORDER BY TotalCount

	DROP TABLE IF EXISTS #IdentifyNonDiscrepantRecords
	SELECT *
		,COUNT(*) OVER (PARTITION BY MVIPersonSID, NationalPatientRecordFlag) as StatusCount
	INTO #IdentifyNonDiscrepantRecords
	FROM #CompareRecords ORDER BY StatusCount
	
	DELETE FROM #Final
	WHERE MVIPersonSID IN (SELECT MVIPersonSID FROM #IdentifyNonDiscrepantRecords WHERE TotalCount>1 AND StatusCount=1) --more than 1 record exists, and only one flag status exists

	DROP TABLE IF EXISTS #DeceasedInactive
	SELECT DISTINCT a.MVIPersonSID	
		,a.NationalPatientRecordFlag
	INTO #DeceasedInactive
	FROM #CompareRecords a 
	INNER JOIN #Final b ON a.MVIPersonSID = b.MVIPersonSID AND a.NationalPatientRecordFlag = b.NationalPatientRecordFlag
	WHERE b.DateOfDeath_SVeteran IS NOT NULL AND b.ActiveAnywhere = 0

	DELETE FROM #Final
	WHERE MVIPersonSID IN (SELECT MVIPersonSID FROM #DeceasedInactive)


EXEC [Maintenance].[PublishTable] 'PRF.Discrepancies','#Final'

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END