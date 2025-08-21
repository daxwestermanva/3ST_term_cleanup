


CREATE VIEW [Present].[SPatient]
AS
SELECT MVIPersonSID
	  ,ISNULL(STORM,0) as STORM
	  ,ISNULL(PDSI,0) as PDSI
	  ,ISNULL(PRF_HRS,0) as PRF_HRS
	  ,ISNULL(REACH,0) as REACH
	  ,ISNULL(SMI,0) as SMI
FROM (
	SELECT DISTINCT 
		ap.MVIPersonSID
		,pr.ProjectName
		,Flag=1
	FROM [Present].[ActivePatient] ap
	INNER JOIN [Config].[Present_ProjectPatientRequirement] pr on pr.RequirementID=ap.RequirementID
	) a
PIVOT (MAX(Flag) FOR ProjectName IN (
		STORM
		,PDSI
		,PRF_HRS
		,REACH
		,SMI
		)
	) b