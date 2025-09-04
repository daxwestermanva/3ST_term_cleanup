


-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	3/24/2025
-- Description:	To be used as Fact source in CaseFactors and Clinical_Insights cross-drill Power BI report.
--				Adapted from [App].[PowerBIReports_Medications]
--
--
--				Row duplication is expected in this dataset.
--
-- Modifications:
-- 5/15/2025 -- Adding in Demo Mode data; logic in line with SUD Case Finder Demo data
--
--
-- =======================================================================================================

CREATE VIEW [App].[PBIReports_Medications] AS

	SELECT DISTINCT 
		s.MVIPersonSID
		,MedType=
			CASE WHEN a.DrugNameWithoutDose LIKE '%BUPRENORPHINE%' THEN 'Buprenorphine'
				 WHEN a.OpioidForPain_rx	= 1 OR a.OpioidAgonist_Rx = 1  THEN 'Opioid'
				 WHEN a.Anxiolytics_Rx = 1 OR a.Benzodiazepine_Rx = 1  THEN 'Anxiolytic or Benzodiazepine'
				 WHEN a.Antidepressant_Rx = 1 THEN 'Antidepressant'
				 WHEN a.Antipsychotic_Rx = 1 THEN 'Antipsychotic'
				 WHEN a.MoodStabilizer_Rx = 1 THEN 'Mood Stabilizer'
				 WHEN a.Stimulant_Rx = 1 THEN 'Stimulant'
				 ELSE 'Other' 
			END
		,a.DrugNameWithDose
		,a.IssueDate
		,a.LastReleaseDateTime
		,a.RxStatus
		,a.Sta6a
		,a.PrescriberName
		,d.Facility
		,d.Code
		--,Exclude=CASE WHEN a.DrugStatus = 'ActiveRx' THEN 0 ELSE 1 END 
	FROM [Common].[PBIReportsCohort] as s WITH (NOLOCK)
	INNER JOIN [Present].[Medications] AS a WITH (NOLOCK) 
		ON a.MVIPersonSID = s.MVIPersonSID
	LEFT JOIN [LookUp].[Sta6a] AS c WITH (NOLOCK)
		ON a.Sta6a = c.Sta6a
	LEFT JOIN [LookUp].StationColors AS d WITH (NOLOCK)
		ON c.ChecklistID = d.ChecklistID
	WHERE a.DrugStatus = 'ActiveRx'

	UNION
	
	SELECT MVIPersonSID
		,MedType
		,DrugNameWithDose
		,IssueDate
		,LastReleaseDate
		,RxStatus
		,Sta6a
		,PrescriberName
		,Facility
		,Code
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)