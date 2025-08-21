
CREATE PROCEDURE [App].[CrosswalkStopCode]
	@Stop1 VARCHAR(500) 
AS
BEGIN

	SET NOCOUNT ON;

SELECT DISTINCT
	[StopCodeDescription] 
	,[StopCode] 
	,[Stop] as Stop1
FROM [ORM].[DefinitionsReportStopCode]
WHERE [Stop] IN (SELECT value FROM string_split(@Stop1,','))

END