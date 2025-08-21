
/* =============================================
-- Author:		Justin Chambers
-- Create date: 9/9/2019
-- Description:	Main build process to compute all of the datasets required for MonitoringSSRS reports.
-- =============================================
*/

CREATE PROCEDURE [Code].[Maintenance_MonitoringSSRSBuild] AS
BEGIN

EXEC [Log].[ExecutionBegin] 'EXEC Code.Maintenance_MonitoringSSRSBuild','Execution of SP Code.Maintenance_MonitoringSSRSBuild'

	DECLARE @EndedOn AS DATE = GETDATE();
	DECLARE @StartedOn AS DATETIME2(0) = DATEADD(DD, -30, @EndedOn); -- This will determine the range for the linear regression, update vwMonitoringSSRSStatistics View as well.
	DECLARE @ReportLocation AS VARCHAR(50);
	DECLARE @Environment AS VARCHAR(50);
	DECLARE @IsLooping AS INTEGER = 1;

	--Generate all the counts used for Reports each DAY and Group for each MONTH and FISCAL_YEAR
	EXEC [Code].[Maintenance_MonitoringSSRSCount];
	
	/*
	Get all ReportLocation, Environment pairs to loop process each of the linear regression date spans.  We only
	process day count: Skiping MONTH and FISCAL_YEAR.
	*/
	DROP TABLE IF EXISTS #ReportLocation;
	SELECT DISTINCT ReportLocation, Environment
	INTO #ReportLocation
	FROM [Maintenance].[MonitoringSSRSCount] WITH (NOLOCK)
	WHERE [Date] BETWEEN @StartedOn AND @EndedOn
		AND CountType='DAY';

	/*
	Main loop body.  We iterate through each pair (ReportLocation, Environment) and calculate a 
	linear regression row according to the type of regression analyzed e.g. RuntimeAvg.
	*/
	TRUNCATE TABLE [Maintenance].[MonitoringSSRSLinearRegression];
	
	SET @IsLooping = (SELECT COUNT(*) FROM #ReportLocation);
	WHILE @IsLooping > 0
	BEGIN
		SELECT TOP 1 @ReportLocation = ReportLocation, @Environment = Environment FROM #ReportLocation;
		
	
		-- Calculate linear regression for the last XX days for as many data sets as needed.  Currently only 4, but there are more such as Row/Byte or Min/Max/Sum etc.
		EXEC Maintenance.MonitoringSSRSLinearRegressionSpan @ReportLocation, @Environment, 'TimeDataRetrievalAvg', @StartedOn, @EndedOn;
		EXEC Maintenance.MonitoringSSRSLinearRegressionSpan @ReportLocation, @Environment, 'TimeProcessingAvg', @StartedOn, @EndedOn;
		EXEC Maintenance.MonitoringSSRSLinearRegressionSpan @ReportLocation, @Environment, 'TimeRenderingAvg', @StartedOn, @EndedOn;
		EXEC Maintenance.MonitoringSSRSLinearRegressionSpan @ReportLocation, @Environment, 'RuntimeAvg', @StartedOn, @EndedOn;
		
		-- Now that we have computed this (ReportLocation, Environment) pair, remove it from the loop set.
		DELETE FROM #ReportLocation WHERE ReportLocation = @ReportLocation AND Environment = @Environment;
		
		-- Are we still looping? If any element remains this will be true.
		SET @IsLooping = (SELECT COUNT(*) FROM #ReportLocation);
	END

	-- Copy status into table from view.  This is only to help monitoring report display performance.
	EXEC [Maintenance].[PublishTable] 'Maintenance.MonitoringSSRSStatus','Maintenance.vwMonitoringSSRSStatus'

EXEC [Log].ExecutionEnd

END;