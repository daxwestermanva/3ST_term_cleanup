CREATE FUNCTION [Dflt].[fxAlex_GetVersionMax] (@GUID VARCHAR(50), @Type VARCHAR(50))
RETURNS TABLE 
AS
RETURN 
(
	SELECT DISTINCT
		ks.KeyID
	FROM [ALEX].[KeySet] ks
	WHERE ks.[GUID] = @GUID
		AND ks.[Type] = @Type
		AND ks.Version = (SELECT MAX(Version) FROM [ALEX].[Definition] ksmv WHERE ksmv.[GUID] = @GUID)
)