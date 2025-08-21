
-- =============================================
-- Author:		Amy Robinson 
-- Create date: 7/25/2014
-- Description:	DataSet for Medication definition Report

-- Modification:
	--	8/13 Updated to ref new lookup tables
	-- 20220425	RAS	Changes SP to use vertical national drug table and removed dynamic sql.

-- Testing:
	--	EXEC [App].[Definitions_NationalDrug] 'Antipsychotic'
	--	EXEC [App].[Definitions_NationalDrug] 'OpioidsForPain,Antipsychotic,Benzodiazepines'
-- =============================================
CREATE PROCEDURE [App].[Definitions_NationalDrug]
	@Drug varchar(1000)
AS
BEGIN
	SET NOCOUNT ON;

	--declare @Drug  varchar(1000)
	--set @Drug = 'Antipsychotic'
	--set @Drug = 'OpioidsForPain,Antipsychotic,Benzodiazepines'

DROP TABLE IF EXISTS #Columns;
SELECT ColumnName,PrintName
INTO #Columns
FROM [LookUp].[ColumnDescriptions] WITH (NOLOCK)
WHERE TableName = 'NationalDrug' --Only NationalDrug table columns
	AND PrintName IN  (SELECT value FROM string_split(@Drug ,','))

SELECT DISTINCT nd.DrugNameWithoutDose
	--,ndv.DrugCategory
	--,cd.Category
	,cd.PrintName
	--,cd.ColumnDescription
FROM [Lookup].[NationalDrug_Vertical] ndv WITH (NOLOCK)
INNER JOIN [LookUp].[NationalDrug] nd WITH (NOLOCK) ON ndv.NationalDrugSID = nd.NationalDrugSID
INNER JOIN #Columns cd ON cd.ColumnName = ndv.DrugCategory
ORDER BY PrintName,DrugNameWithoutDose

END