






CREATE FUNCTION [Maintenance].[fn_RemoveFileExtension] (@String VARCHAR(256))
RETURNS VARCHAR(50)
AS
BEGIN
	DECLARE @Index INT = (LEN(@String)) - CHARINDEX('.', REVERSE(@String));
	RETURN SUBSTRING(@String,0,@Index+1);
END