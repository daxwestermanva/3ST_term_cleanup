
CREATE FUNCTION [RiskScore].[VariableID]
(
	@VariableName VARCHAR(100)
)
RETURNS SMALLINT
AS
BEGIN
	RETURN (SELECT [VariableID] FROM [RiskScore].[Variable] WHERE VariableName = @VariableName)

END