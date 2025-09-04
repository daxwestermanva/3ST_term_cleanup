
/*******************************************************************
DESCRIPTION: Script will update functions for use against ALEX tables, based on latest import from the ALEX database.
TEST:
	EXEC [Maintenance].[UpdateAlexFunction]
UPDATE:
	2021-02-02	RAS	Created SP and added to SSIS job AlexImport.

TO DO: Add clean up of blueprint table or decide to truncate before import.
*******************************************************************/

CREATE PROCEDURE [Maintenance].[UpdateAlexFunction]
AS
BEGIN

DROP TABLE IF EXISTS #AlexFx;
CREATE TABLE #AlexFx (
	FxID INT IDENTITY(1,1)
	,FxName VARCHAR(50)
	,FxCode VARCHAR(1000)
	,NewFn BIT
	)
;WITH CTE_Import AS (
	SELECT TOP 1 WITH TIES 
		[Name] FxName
		,REPLACE(
			REPLACE(
				REPLACE(
					SUBSTRING([Code],CHARINDEX('CREATE ',[Code]),LEN([Code]) - CHARINDEX('CREATE ',[Code])+1),'GO',''
					)
				,'Dflt.Alex_KeySet','[ALEX].[KeySet]')
			,'Dflt.Alex_Definition','[ALEX].[Definition]'
			) FxCode
	FROM [Alex].[Blueprint]
	WHERE Type = 'function'
	ORDER BY ROW_NUMBER() OVER(PARTITION BY [Name] ORDER BY LastModifiedOn DESC,ETLLoadDateTime DESC)
	)
INSERT INTO #AlexFx (FxName,FxCode,NewFn)
SELECT 
	src.FxName
	,src.FxCode
	,CASE WHEN sysfn.name IS NULL THEN 1 ELSE 0 END
FROM CTE_Import src
LEFT JOIN (
	SELECT name from sys.all_objects 
	WHERE type='IF'
	) sysfn ON sysfn.name = src.FxName

DECLARE @counter INT = 1

WHILE @counter <= (SELECT MAX(fxID) FROM #AlexFx)
	BEGIN
		DECLARE @SQL VARCHAR(4000) = (
			SELECT 
				CASE WHEN NewFn = 0 THEN REPLACE(FxCode,'CREATE ','ALTER ') ELSE FxCode END 
			FROM #AlexFx 
			WHERE FxID=@counter
			)
		PRINT @SQL
		EXEC (@SQL)

		SET @counter = @counter + 1
	END

END