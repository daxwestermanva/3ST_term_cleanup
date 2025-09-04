
-- =============================================
-- Author:		<Marcos Lau>
-- Create date: <8/4/18>
-- Description:	<App.Admin_DefaultParametersUpdate>
-- =============================================
CREATE PROCEDURE [App].[Admin_DefaultParametersUpdate]
	@UserID varchar(100)
	, @ReportName varchar(100) 
	, @Parameter1 varchar(1000) = ''
	, @Parameter2 varchar(1000) = ''
	, @Parameter3 varchar(1000) = ''
	, @Parameter4 varchar(1000) = ''
	, @Parameter5 varchar(1000) = ''
	, @Parameter6 varchar(1000) = ''
	, @Parameter7 varchar(1000) = ''
	, @Parameter8 varchar(1000) = ''


AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DROP TABLE IF EXISTS #temp;

    SELECT *
	INTO #Temp
	FROM (
		SELECT CASE
				WHEN @ReportName = 'SPPRITE_PatientReport_LSV' THEN 'HideInstructions' 
				END as ParameterName
			,Value as ParameterValue
		FROM STRING_SPLIT(@Parameter1, ',')

		UNION ALL

		SELECT CASE
				WHEN @ReportName = 'SPPRITE_PatientReport_LSV' THEN 'HidePHI' 
				END as ParameterName
			,value as ParameterValue
		FROM STRING_SPLIT(@Parameter2, ',')

		UNION ALL

		SELECT NULL as ParameterName
			,value as ParameterValue
		FROM STRING_SPLIT(@Parameter3, ',')

		UNION ALL

		SELECT CASE
				WHEN @ReportName = 'SPPRITE_PatientReport_LSV' THEN 'Provider'
				END as ParameterName
			,value as ParameterValue
		FROM STRING_SPLIT(@Parameter4, ',')

		UNION ALL

		SELECT CASE 
				WHEN @ReportName = 'SPPRITE_PatientReport_LSV' THEN 'RiskFactors' 
				END as ParameterName
			,value as ParameterValue
		FROM STRING_SPLIT(@Parameter5, ',')

		UNION ALL

		SELECT NULL as ParameterName
			,value as ParameterValue
		FROM STRING_SPLIT(@Parameter6, ',')

		UNION ALL

		SELECT NULL as ParameterName
			,value as ParameterValue
		FROM STRING_SPLIT(@Parameter7, ',')

		UNION ALL

		SELECT NULL as ParameterName
			,value as ParameterValue
		FROM STRING_SPLIT(@Parameter8, ',')
	) as a
	WHERE ParameterName IS NOT NULL 
;
-- remove the old parameter settings
DELETE FROM [App].[Admin_DefaultParameters] 
WHERE UserID = @UserID 
	AND ReportName = @ReportName 
	;

-- insert the new parameter settings 
INSERT INTO [App].[Admin_DefaultParameters] (UserID,ReportName,ParameterName,ParameterValue,LastUpdated) 
SELECT @UserID
	,@ReportName
	,ParameterName
	,ParameterValue
	,GETDATE() 
FROM #Temp
;

END
