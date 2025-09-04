
-- =============================================
-- Author:		Mark Swiderski
-- Create date: 2024-05-04
-- Description:	Prepends a table alias to all values passed in to @ColumnCDS
-- =============================================

/*
	SELECT DeltaView.[fn_BTRT_PrependAliasFromDelimitedColumns]('idStudent,acdmYear', 'B')
	SELECT DeltaView.[fn_BTRT_PrependAliasFromDelimitedColumns]('idStudent', 'B')

*/

CREATE FUNCTION [DeltaView].[fn_BTRT_PrependAliasFromDelimitedColumns] 
(
	@ColumnCDS VARCHAR(1000),
	@TableAlias VARCHAR(100)
)
RETURNS VARCHAR(1000)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @ReturnColumnCDS VARCHAR(1000)

	SELECT
		@ReturnColumnCDS = STRING_AGG(L.ReturnColumnCDS, ', ')
	FROM
	(
		SELECT 
			ReturnColumnCDS = @TableAlias + '.' + [value] 
		FROM 
			STRING_SPLIT(@ColumnCDS, ',')
	) L

	-- Return the result of the function
	RETURN @ReturnColumnCDS;

END