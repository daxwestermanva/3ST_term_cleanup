CREATE FUNCTION [Dflt].[fxAlex_GetActiveOn] (@GUID VARCHAR(50), @Type VARCHAR(50), @SessionOn [datetime2](0))
RETURNS TABLE 
AS
RETURN 
(
	SELECT DISTINCT
		ks.KeyID
	FROM [ALEX].[KeySet] ks
	WHERE ks.[GUID] = @GUID AND ks.[Type] = @Type AND ks.Version IN (SELECT TOP 1 [Version] FROM [ALEX].[Definition] WHERE GUID=@GUID AND ActivateOn < @SessionOn ORDER BY ActivateOn DESC)
)