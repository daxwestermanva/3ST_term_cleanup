

/***********************************************************************************************************
 Author:	<Tolessa Gurmessa>
 Create date: <2/22/2018>
 Facility performance on these metrics will be visible to staff on the Psychotropic 
 Drug Safety Initiative dashboard summary page and updated on a quarterly basis.
 This stored procedure creates a historical table for Very High Risk Category patients so that it could be
 used as a denominator in the Quarterly STORM Memo Metrics.
 It will be updated daily.
 2020-07-10 --TG altered SP to include ChecklistID
 --2021-12-21 --TG adding more risk categories to STRM1 metric
***********************************************************************************************************/
CREATE PROCEDURE [Code].[ORM_VeryHighRiskHistoric]
	
	AS
BEGIN

-- The following code is adopted from ORM_Cohort
DROP TABLE IF EXISTS #riskcategory;
SELECT mp.MVIPersonSID
      ,mp.PatientICN
	,pr.RiskCategory
	,pr.RiskAnyCategory 
	,pr.RiskCategoryLabel
	,pr.RiskAnyCategoryLabel
	,pr.ChecklistID 
INTO #riskcategory
FROM [ORM].[PatientReport] pr WITH (NOLOCK)
INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK) ON mp.MVIPersonSID=pr.MVIPersonSID
  ;

-- Insert new records in to a new table.
INSERT INTO [ORM].[Evaluation_RiskCategory]
SELECT DISTINCT PatientICN
	,RiskCategory
	,GETDATE() as RiskCategoryDate
	,ChecklistID
	,MVIPersonSID
FROM #riskcategory
WHERE RiskCategory IN (4,9,10,11)
	;
END