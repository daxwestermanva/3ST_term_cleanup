



-------------------------------------------------------------------------------------------
/**** Diagnosis categories to be displayed in CRISTAL***************/

-- 20211103	RAS	Removed ProjectType from view (add back in with join to LookUp.ICD10_Display if needed)
-- 20211201	RAS	Changed to use group by and max of description instead of just distinct because
				-- the important thing is to have the granularity at ICD10Code/DxCategory and it 
				-- doesn't really matter which description is taken from the source table
-------------------------------------------------------------------------------------------		
CREATE VIEW [LookUp].[ICD10_Vertical]
AS

 SELECT 
	ICD10Code
	,MAX(ICD10Description) AS ICD10Description
	,DxCategory
 FROM [LookUp].[ICD10_VerticalSID] WITH (NOLOCK)
 GROUP BY DxCategory,ICD10Code