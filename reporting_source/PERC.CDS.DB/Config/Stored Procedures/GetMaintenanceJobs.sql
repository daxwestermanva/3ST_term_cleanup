
/********************************************************************************************************************
DESCRIPTION: Retrieves config values from Maintenance_Jobs for a given [Schedule] and for a specifc sequence (optional).

UPDATE:
	2019-05-21	- Matt Wollner	- Create
	2020-03-03	- Jason Bacani	- Updated Sequence use to be greater than the optional Sequence number provided

EXAMPLE 1:
	EXEC [Config].[GetMaintenanceJobs] @Schedule = 'B.Nightly'
	EXEC [Config].[GetMaintenanceJobs] @Schedule = 'B.Nightly', @Sequence = 0
	EXEC [Config].[GetMaintenanceJobs] @Schedule = 'B.Nightly', @Sequence = 1001
	
********************************************************************************************************************/
CREATE PROCEDURE [Config].[GetMaintenanceJobs]
	@Schedule VARCHAR(20)
	,@Sequence INT = 0
AS
BEGIN
	
	SELECT [Schedule], [SpName], [Sequence], [StopOnFailure] 
	FROM [Config].[Maintenance_Jobs] 
	WHERE 
		[Schedule] = @Schedule 
		AND (@Sequence = 0 OR [Sequence] >= @Sequence)
	ORDER BY [Sequence]

END