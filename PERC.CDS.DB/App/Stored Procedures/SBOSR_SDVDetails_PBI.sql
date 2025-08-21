
-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	5/18/2023
-- Description:	Main dataset for Suicide Behavior and Overdose Summary Report (PowerBI). 
--				Data source: [Code].[SBOSR_SDVDetails_PBI] 
--
--				Row duplication is expected in this dataset.
--				
-- Modifications:
--
-- 2023-08-02   CW   Removing unknown facility locations; may revisit how to assign these cases in the 
--					 future but for now they will be excluded (bulk are from historical SPAN entries)
-- 2025-02-12	CW	 Adding EventCountIndicator and taking out unused columns in the report
-- 2025-07-15   CW   Adding DataSource
-- =======================================================================================================
CREATE PROCEDURE [App].[SBOSR_SDVDetails_PBI]

AS
BEGIN
	
	SET NOCOUNT ON;

	SELECT 
		 [MVIPersonSID]
		,[PatientICN]
		,[SPANPatientID]
		,[ActivePatient]
		,[PatientKey]
		,[PatientNameLastFour]
		,[ChecklistID]
		,[ADMPARENT_FCDM]
		,[Facility]
		,[SDVCntType]
		,[EventType]
		,[Date]
		,[DataSource]
		,[Month]
		,[MonthName]
		,[Year]
		,[EventDate]
		,[EventDateCombined]
		,[EventDateNULL]
		,[ReportDate]
		,[SDVClassification]
		,[Seen7Days]
		,[Seen30Days]
		,[VAProperty]
		,[SevenDaysDx]
		,[MethodForVisuals]
		,[Outcome]
		,[Overdose]
		,[FatalvNonFatal]
		,[BHAP_FITC_DueDate]
		,[Fatal]
		,[PreparatoryBehavior]
		,[UndeterminedSDV]
		,[SuicidalSDV]
		,[HRFType]
		,[MedType]
		,[RV_Status]
		,[RV_Status_Number]
		,[HRFNumber]
		,CAST([Month_Number] as INT) as MonthNumber
		,[MethodPrintName]
		,[MonthYear]
		,[AdmitYearMonth_Number]
		,[EventCountIndicator]
	FROM [SBOSR].[SDVDetails_PBI]
	WHERE Facility<>'Unknown';

	END