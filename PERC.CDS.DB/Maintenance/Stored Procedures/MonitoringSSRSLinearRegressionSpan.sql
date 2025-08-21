
/* =============================================
-- Author:		Justin Chambers
-- Create date: 9/9/2019
-- Description:	Generate all the linear regressions for each report based on report location and environment.
				ColumnName is the datatype to be calculated and date ranges can be modifyed to expand/subtract the range of data.
				If date ranges need to be modifyed, adjust the vwMonitoringSSRSStatistics VIEW as well.
-- Modifications:
	2019-09-24	SG	Removing direct database reference
	2019-09-27	RAS	Added logging. Formatting.
	2021-07-16  EC  Removed Environment field and parameter
	2022-07-11	LM	Replaced reference from App schema object to PDW schema object
-- ============================================= */

CREATE PROCEDURE [Maintenance].[MonitoringSSRSLinearRegressionSpan] 
	(@ReportLocation VARCHAR(50)
	,@Environment VARCHAR(100)
	,@ColumnName VARCHAR(100)
	,@StartedOn DATETIME2(0)
	,@EndedOn DATETIME2(0)
	) 
AS
BEGIN

DECLARE @description varchar(1000) = 'Execution of MonitoringSSRSLinearRegressionSpan ' + @ReportLocation + ', ' + @Environment + ',' + @ColumnName + ', ' + cast(@StartedOn as varchar) + ', ' + cast(@EndedOn as varchar)

EXEC [Log].[ExecutionBegin] 'EXEC Maintenance.MonitoringSSRSLinearRegressionSpan',@description
	-- Find all Reports that belong to the ReportLocatoin and Environment to be processed
	SELECT DISTINCT ObjectFileName
	INTO #ObjectFileNames
	FROM [Maintenance].[MonitoringSSRSCount] WITH (NOLOCK)
	WHERE [Date] BETWEEN @StartedOn AND @EndedOn 
		AND Environment = @Environment
		AND ReportLocation = @ReportLocation 
		AND CountType='DAY';

	DECLARE @MinDataCount AS INTEGER = 5;
	DECLARE @CurrentDataCount AS INTEGER;
	DECLARE @IsLooping AS INTEGER = 1;
	DECLARE @ObjectFileName AS VARCHAR(100);
	DECLARE @DaysSpan AS INTEGER = DATEDIFF(DAY, @StartedOn, @EndedOn);
	CREATE TABLE #CoordsData (X FLOAT, Y FLOAT);
	DECLARE @AccessCount AS INTEGER = 0;
	DECLARE @UserCount AS INTEGER = 0;
	DECLARE @SqlCommand AS VARCHAR(1000);

	-- Subroutine vairables for individual linear regression processing
	DECLARE @XMin FLOAT;
	DECLARE @XMax FLOAT;
	DECLARE @XBar FLOAT;
	DECLARE @YMin FLOAT;
	DECLARE @YMax FLOAT;
	DECLARE @YBar FLOAT;
	DECLARE @AvgY FLOAT;
	DECLARE @VectorLength FLOAT;
	DECLARE @SlopeDenominator FLOAT;
	DECLARE @Slope FLOAT;
	DECLARE @SlopeNormalized FLOAT;
	DECLARE @Intercept FLOAT;
	DECLARE @Sigma FLOAT;
	DECLARE @Projected FLOAT;
	-- End subroutine vars

	WHILE @IsLooping > 0
	BEGIN
		-- Get first report to process.
		SELECT TOP 1 @ObjectFileName = ObjectFileName FROM #ObjectFileNames;
		-- Clear CoordsData from previous pass.
		TRUNCATE TABLE #CoordsData;
		-- Dynam SQL to get the X,Y coord values from the counts table.  Only processing X,Y for each DAY.
		SET @SqlCommand = 
		'SELECT cast(convert(datetime,[Date]) as float) AS X,' + @ColumnName + ' AS Y ' +
		'FROM [Maintenance].[MonitoringSSRSCount] WITH (NOLOCK) ' +
		'WHERE [Date] BETWEEN ''' + CONVERT(VARCHAR(30), @StartedOn, 111) + ''' AND ''' + CONVERT(VARCHAR(30), @EndedOn, 111) + ''' AND ObjectFileName = ''' + @ObjectFileName + ''' AND ReportLocation = ''' + @ReportLocation + ''' AND Environment = ''' + @Environment + ''' AND CountType=''DAY'';';
		
		-- Insert the Dynamic SQL into XYCoords User Defined Table.
		INSERT INTO #CoordsData
		EXEC (@SqlCommand);

		-- Get user and access counts for the time span period.
		SELECT @UserCount = COUNT(DISTINCT UserName), @AccessCount = COUNT(*) FROM [PDW].[BISL_SSRSLog_DOEx_ExecutionLog]
		WHERE ObjectFileName = @ObjectFileName AND TimeStart BETWEEN @StartedOn AND @EndedOn AND Environment = @Environment;
		
		SELECT @Sigma = STDEV(Y) FROM #CoordsData; -- Preserve original sigma
		SELECT @AvgY = AVG(Y) FROM #CoordsData; -- Preserve original avg
		-- We are going to remove outliers to avoid data spikes (>95th percentile) 
		DELETE FROM #CoordsData WHERE Y < (@AvgY - 2*@Sigma) OR Y > (@AvgY + 2*@Sigma);

		SELECT @CurrentDataCount = COUNT(*) FROM #CoordsData;
		-- We are not going to attempt to process small datasets since results will be less reliable.
		IF @CurrentDataCount >= @MinDataCount
		BEGIN			
			-- Initilaize vars
			SELECT @XMin = MIN(X) FROM #CoordsData;
			SELECT @XMax = MAX(X) FROM #CoordsData;
			SELECT @XBar = AVG(X) FROM #CoordsData;
			SELECT @YMin = MIN(Y) FROM #CoordsData;
			SELECT @YMax = MAX(Y) FROM #CoordsData;
			SELECT @YBar = AVG(Y) FROM #CoordsData;
			SELECT @VectorLength = @YMax - @YMin;
			SELECT @SlopeDenominator = SUM((X - @XBar)*(X - @XBar)) FROM #CoordsData;
			
			-- Slope of the linear regression
			SELECT @Slope = 
			CASE WHEN @SlopeDenominator <> 0
				THEN (SELECT SUM((X - @XBar)*(Y - @YBar)) / @SlopeDenominator FROM #CoordsData)
				ELSE 0
				END;

			-- Normalization of the slope give us relative bases to compare between multiple report slopes
			SELECT @SlopeNormalized = 
			CASE WHEN @VectorLength <> 0
				THEN @Slope / @VectorLength
				ELSE 0
				END;

			SET @Intercept = @YBar - @XBar * @Slope;
			
			-- Projected value represents what we belive the value should be giving the day of processing.
			-- This could be calculated for all points along the timeline since the results for all reports are stored in MonitoringSSRSLinearRegression table. 
			SET @Projected = (@XMax*@Slope) + @Intercept;
			
			-- Store the results in the final table
			INSERT INTO [Maintenance].[MonitoringSSRSLinearRegression]
			SELECT @ObjectFileName
				  ,@ReportLocation
				  ,@Environment
				  ,@AccessCount AS AccessCount
				  ,@UserCount AS UserCount
				  ,@ColumnName AS ColumnName
				  ,@DaysSpan AS DaysSpan
				  ,@StartedOn AS StartedOn
				  ,@EndedOn AS EndedOn
				  ,ISNULL(@XMin, 0) AS XMin
				  ,ISNULL(@XMax, 0) AS XMax
				  ,ISNULL(@XBar, 0) AS XBar
				  ,ISNULL(@YMin, 0) AS YMin
				  ,ISNULL(@YMax, 0) AS YMax
				  ,ISNULL(@YBar, 0) AS YBar
				  ,ISNULL(@AvgY, 0) AS AvgY
				  ,ISNULL(@VectorLength, 0) AS VectorLength
				  ,ISNULL(@Slope, 0) AS Slope
				  ,ISNULL(@Intercept, 0) AS Intercept
				  ,ISNULL(@SlopeNormalized, 0) AS SlopeNormalized
				  ,ISNULL(@Projected, 0) AS Projected
				  ,ISNULL(@Sigma, 0) AS Sigma;
		
		END
		
		-- Remove the report that we just finished processing.
		DELETE FROM #ObjectFileNames WHERE ObjectFileName = @ObjectFileName;
		
		-- Do we have any more reports to process?
		SET @IsLooping = (SELECT COUNT(*) FROM #ObjectFileNames);
	
	END

EXEC [Log].[ExecutionEnd]

END;