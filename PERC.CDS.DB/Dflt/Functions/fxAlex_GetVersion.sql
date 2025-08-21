CREATE FUNCTION [Dflt].[fxAlex_GetVersion] (@GUID VARCHAR(50), @Type VARCHAR(50), @Version int)
RETURNS TABLE 
AS
RETURN 
(
	SELECT DISTINCT
		ks.KeyID
	FROM [ALEX].[KeySet] ks
	WHERE ks.[GUID] = @GUID AND ks.[Type] = @Type AND Version=@Version
)