

CREATE VIEW [Present].[StationAssignments]
AS

SELECT MVIPersonSID
	  ,PatientICN
	  ,PatientPersonSID
	  ,Sta3n_Loc
	  ,ChecklistID
	  ,ISNULL(STORM,0) as STORM
	  ,ISNULL(PDSI,0) as PDSI
	  ,ISNULL(PRF_HRS,0) as PRF_HRS
FROM (
	SELECT a.MVIPersonSID
		  ,mp.PatientICN
		  ,a.PatientPersonSID
		  ,a.ChecklistID
		  ,a.Sta3n_Loc
		  ,p.ProjectName
		  ,Flag=1
	FROM [Present].[ActivePatient] a WITH(NOLOCK)
	INNER JOIN [Config].[Present_ProjectDisplayRequirement] p WITH(NOLOCK) on p.RequirementID=a.RequirementID
	INNER JOIN [Common].[MasterPatient] mp WITH(NOLOCK) ON mp.MVIPersonSID=a.MVIPersonSID
	WHERE a.ChecklistID IS NOT NULL
	) s
PIVOT (max(Flag) FOR s.ProjectName IN (STORM,PDSI,PRF_HRS)
	) p