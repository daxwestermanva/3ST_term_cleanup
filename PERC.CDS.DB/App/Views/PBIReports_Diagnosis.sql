



-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	3/24/2025
-- Description:	To be used as Fact source in CaseFactors and Clinical_Insights cross-drill Power BI report.
--				Adapted from [App].[PowerBIReports_Diagnosis]
--
--
--				Row duplication is expected in this dataset.
--
-- Modifications:
-- 5/15/2025 -- Adding in Demo Mode data; logic in line with SUD Case Finder Demo data
--
--
-- =======================================================================================================

CREATE VIEW [App].[PBIReports_Diagnosis] AS

	WITH DxDetails AS (
	SELECT top (1) WITH TIES
		 d.MVIPersonSID
		,d.PrintName
		,d.Category
		,dd.ChecklistID
		,ck.Facility
		,dd.MostRecentDate
		,dd.ICD10Code
		,v.ICD10Description
	FROM (	SELECT p.MVIPersonSID
				,c.PrintName
				,d.DxCategory
				,c.Category
			FROM [Present].[Diagnosis] d WITH(NOLOCK)
			INNER JOIN [Common].[PBIReportsCohort] p WITH(NOLOCK) ON d.MVIPersonSID=p.MVIPersonSID
			INNER JOIN [LookUp].[ColumnDescriptions] c WITH (NOLOCK) ON d.DxCategory = c.ColumnName
			INNER JOIN [LookUp].[ICD10_Display] dis WITH (NOLOCK) ON c.ColumnName=dis.DxCategory
			WHERE dis.ProjectType='CRISTAL' AND c.TableName = 'ICD10'
			--Categories: Social,Chronic Respiratory Diseases,Mental Health,Medical,Substance Use Disorder,Adverse Event,Reproductive health
		  ) d
	INNER JOIN LookUp.ICD10_Vertical as v  WITH (NOLOCK) 
		ON d.DxCategory=v.DxCategory
	INNER JOIN Present.DiagnosisDate as dd WITH (NOLOCK) 
		ON v.ICD10Code=dd.ICD10Code AND d.MVIPersonSID=dd.MVIPersonSID
	INNER JOIN LookUp.ChecklistID as ck WITH (NOLOCK) 
		ON ck.ChecklistID=dd.ChecklistID	
	ORDER BY ROW_NUMBER() over (partition by d.MVIPersonSID, d.PrintName order by dd.MostRecentDate desc)
	)
  SELECT 
		 d.ChecklistID
		,MVIPersonSID
		,ICDType             =Category
		,ICDDate             =cast(MostRecentDate as date)
		,ICDDetails          =('(' + ICD10Code + ') ' + ICD10Description)
		,PrintName
		,ICDSort= CASE WHEN Category='Adverse Event' THEN 1
							WHEN Category='Substance Use Disorder' THEN 2
							WHEN Category='Medical' THEN 3
							WHEN Category='Mental Health' THEN 4
							WHEN Category='Social' THEN 5
							WHEN Category='Chronic Respiratory Diseases' THEN 6
							WHEN Category='Reproductive Health' THEN 7
							END
		,c.Code
		,Facility2=c.Facility
	FROM DxDetails d
	LEFT JOIN LookUp.StationColors c WITH (NOLOCK)
		ON d.ChecklistID=c.CheckListID

	UNION

	SELECT
		 ChecklistID
		,MVIPersonSID
		,ICDCatetory
		,ICDDate
		,ICDDetails
		,ICDPrintName
		,ICDSort
		,Code
		,Facility
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)