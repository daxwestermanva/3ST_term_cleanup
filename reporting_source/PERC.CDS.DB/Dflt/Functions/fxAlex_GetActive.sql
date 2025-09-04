CREATE FUNCTION [Dflt].[fxAlex_GetActive] (@GUID VARCHAR(50), @Type VARCHAR(50))
RETURNS TABLE 
AS
RETURN 
(
	SELECT DISTINCT
		ks.KeyID
	FROM [ALEX].[KeySet] ks
	WHERE ks.[GUID] = @GUID AND ks.[Type] = @Type AND ks.Version IN (SELECT TOP 1 [Version] FROM [ALEX].[Definition] WHERE GUID=@GUID AND ActivateOn < GETDATE() ORDER BY ActivateOn DESC)
)