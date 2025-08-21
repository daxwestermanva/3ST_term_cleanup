





/* =============================================
-- Author:		Justin Chambers
-- Create date: 9/9/2019
-- Description:	Report group classification.
-- =============================================
*/
CREATE FUNCTION [Maintenance].[fn_ParseFolderName] (@String VARCHAR(256))
RETURNS VARCHAR(50)
AS
BEGIN
	DECLARE @Result VARCHAR(50);
	DECLARE @StartToken VARCHAR(50) = 'CDS'; -- Expected SSRS root folder.
	DECLARE @Index INT = CHARINDEX(@StartToken, @String);
	DECLARE @TempResult VARCHAR(50) = SUBSTRING(@String,@Index+LEN(@StartToken),LEN(@String));

	IF @Index > 0 --Check if path has AnalyticsReports in string, if not complete path will default to Other.
	BEGIN
		SET @Index = CHARINDEX('/', @TempResult); -- Check to see if in home directory, if true place report in Home group.
		IF @Index > 0
		BEGIN
			SET @TempResult = SUBSTRING(@TempResult,@Index+1,LEN(@TempResult));
			SET @Index = CHARINDEX('/', @TempResult); -- Check to see if there is a nested folder.  If so, group all other folders into single group called Other.
			IF @Index = 0
			BEGIN
				SET @Result = @TempResult;
			END
			ELSE
			BEGIN
				SET @Result = 'Other';
			END
		END
		ELSE
		BEGIN
			SET @Result = 'Home';
		END
	END
	ELSE
	BEGIN
		SET @Result = 'Other';
	END

	RETURN @Result;
END