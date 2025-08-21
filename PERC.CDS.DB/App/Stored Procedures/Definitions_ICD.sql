
-- =============================================
-- Author:		Amy Furman 
-- Create date: 4/15/2014
-- Description:	DataSet for Diagnosis Crosswalk
-- EXEC [App].[Definitions_ICD] @Disease1='Suicide,OUD'
-- =============================================
CREATE PROCEDURE [App].[Definitions_ICD]
	-- Add the parameters for the stored procedure here
	@Disease1 VARCHAR(5000) 
AS
BEGIN
	SET NOCOUNT ON;

	--declare @Disease1  varchar(100) set @Disease1 = 'REACH_arth'

DROP TABLE IF EXISTS #Columns
SELECT ColumnName,PrintName
INTO #Columns
FROM [LookUp].[ColumnDescriptions] --sys.columns 
WHERE [ColumnName] IN (SELECT value FROM string_split(@Disease1 ,','))
	AND TableName='ICD10'
  ;
   
-- Verify parameter is a valid column of the target table
DECLARE @TestForValidInputCount INT
SELECT @TestForValidInputCount = COUNT(*)
FROM #Columns

IF @TestForValidInputCount > 0 
BEGIN
	SELECT DISTINCT 
		d.ICD10Code as Diagnosis
		,d.ICD10Description as [ICDDescription]
		,'ICD10' as ICD
		,c.ColumnName
		,c.PrintName
	FROM [LookUp].[ICD10_Vertical] d
	INNER JOIN #Columns c ON c.ColumnName=d.DxCategory
	ORDER BY ColumnName
END
ELSE
	BEGIN
	  PRINT 'Invalid Input'
	END

END