-- =============================================
-- Author:		Mark Swiderski
-- Create date: 2024-05-02
-- Description:	Assembles a table join specification from delimited string of column names
-- =============================================

/*
	SELECT DeltaView.fn_BTRT_GetJoinSpecFromDelimitedColumns('idStudent,acdmYear', 'L', 'R')

*/

CREATE FUNCTION [DeltaView].[fn_BTRT_GetJoinSpecFromDelimitedColumns] 
(
	@ColumnCDS VARCHAR(1000),
	@LeftAlias VARCHAR(100),
	@RightAlias VARCHAR(100)
)
RETURNS VARCHAR(1000)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @ReturnJoinSpec VARCHAR(1000)

	SELECT
		@ReturnJoinSpec = STRING_AGG(L.JoinSpec, ' AND ')
	FROM
	(
		SELECT 
			JoinSpec = @LeftAlias + '.' + [value] + ' = ' + @RightAlias +  '.'  + [value]
			-------JoinSpec = 'L.' + [value] + ' = R.'  + [value]
		FROM 
			STRING_SPLIT(@ColumnCDS, ',')
	) L

	-- Return the result of the function
	RETURN @ReturnJoinSpec;

END