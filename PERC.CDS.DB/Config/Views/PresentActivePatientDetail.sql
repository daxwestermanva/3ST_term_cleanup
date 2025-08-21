
CREATE VIEW [Config].[PresentActivePatientDetail]
AS
SELECT pop.ProjectName
	,r.RequirementID
	,Cohort=1
	,CASE WHEN dis.RequirementID IS NOT NULL THEN 1 ELSE 0 END as StationDisplay
	,r.RequirementName
	,r.Description as RequirementDescription
FROM [Config].[Present_ActivePatientRequirement] r 
INNER JOIN [Config].[Present_ProjectPatientRequirement] pop ON r.RequirementID=pop.RequirementID
LEFT JOIN [Config].[Present_ProjectDisplayRequirement] dis ON dis.ProjectName=pop.ProjectName
	AND r.RequirementID=dis.RequirementID
--ORDER BY ProjectName