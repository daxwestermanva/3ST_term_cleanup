/* =============================================
Author:		 <Susana Martins>
Create date: <4/20/2017>
Description: <Inserting top 0.1% into DisplayedPatient table>
Modifications:
	2018-10-24 RAS: Added	code to avoid inserting duplicate data.
	2019-02-22 RAS: Replaced RunDate with EndDate to facilitate checking for existing data from the same analysis period. 
	2019-02-25 RAS: Instead of EndDate, thinking maybe release date should be used for now?  Added ReleaseDate to DisplayedPatient
	2019-04-01 HES: Added code to refresh/copy the new ReachVet monthly data to CDSDev and CDSSbx
	2019-05-08 RAS: Added code from code.REACH_PatientSIDs to just run as part of publishing
	2019-05-22 MIW: Added End log Before RETURN exists the proc
	2019-05-22 RAS: Deleted section that updated PatientCohort - deprecating table
	2019-07-08 RAS: Deleted section that copied data because too tedious to make solution build with direct database references.
					Corrected column names for table changes in RiskScoreHistoric.
	2020-09-09 RAS: Changed ReleaseDate logic to pull in relation to run date instead of date in staging table so that it can run if staging table is epmpty.
					Added existing data warning to add record to run results table for validation
	2020-11-19 RAS: Pointing to VM tables.
	2021-04-14 RAS:	Added Enrollment Priority Group to historic table. Changed "Top01Percent" to 'DashboardPatient"
	2023-06-29 LM:	Added ImpactedByRandomization column
	2023-06-30 JEB: Former field was changed later on 2023/06/29 to [Reach].[RiskScore].[ImpactedByRandomization] in the source table but not in this downstream SP. Did not cause a Build error, but did surface a Build Warning. 
	2025-02-20 AER: Updating for REACH 2.0										
EXAMPLE EXECUTIONS:
EXEC Code.Reach_RiskScorePublish @ForceUpdate=0 --If data already exists in RiskScoreHistoric, it will NOT be overwritten
EXEC Code.Reach_RiskScorePublish @ForceUpdate=1
============================================= */

CREATE PROCEDURE [Code].[Reach_RiskScorePublish] 
	@ForceUpdate BIT = 0
AS
BEGIN
	--DECLARE @ForceUpdate BIT =0

	EXEC [Log].[ExecutionBegin] @Name = 'Code.Reach_RiskScorePublish'
		,@Description = 'Execution of Code.Reach_RiskScorePublish SP'

	
	--Get release date for the month
	DECLARE @ReleaseDate DATE = (
		SELECT ReleaseDate
		FROM [REACH].[ReleaseDates]
		WHERE EOMONTH(ReleaseDate)=EOMONTH(GetDate())
		);

	--If not forcing an update, then check for existing data for the release date month
	IF @ForceUpdate = 0
		AND (
			SELECT count(*)
			FROM [REACH].[RiskScoreHistoric]
			WHERE ReleaseDate = @ReleaseDate and ModelName = 'Reach Vet 2.0' --inserting RV1 and RV2 for a few months
			) > 0
	BEGIN
		PRINT 'Data for this release date has already been published. To override previous data, run procedure with @ForceUpdate=1';

		EXEC [Log].[Message] 'Warning'
			,'Data already published'
			,'Reach risk score data for this release date has already been published. To override previous data, run procedure with @ForceUpdate=1'
		
		INSERT INTO [REACH].[ReachRunResults]
			VALUES ('Code.RiskScorePublish','Exisiting Data Warning',@ReleaseDate,GETDATE(),1,NULL)

		EXEC [Log].[ExecutionEnd] @Status = 'Completed';
		
		RETURN
	END
	
	--Make sure there is data in the stage table 
	----after switch is complete, the stage table will be empty
	IF (
			SELECT count(*)
			FROM [Reach].[Stage_RiskScore]
			) = 0
	BEGIN

		EXEC [Log].[Message] 'Error'
			,'Empty source table'
			,'No data exists in REACH RiskScore_Stage'

		EXEC [Log].[ExecutionEnd] @Status = 'Error';
		
		;THROW 51000,'Empty source table RiskScore_Stage',1 

	END

	/*****Publish RiskScore*******/
	BEGIN TRY
		BEGIN TRANSACTION

			TRUNCATE TABLE [Reach].[RiskScore]

			ALTER TABLE [REACH].[Stage_RiskScore] SWITCH TO [Reach].[RiskScore]

			DECLARE @RowCount INT = (SELECT count(*) FROM [Reach].[RiskScore])
			EXEC [Log].[PublishTable] 'REACH','RiskScore','REACH.Stage_RiskScore','Replace',@RowCount

			PRINT 'RiskScore updated'

		COMMIT
	END TRY

	BEGIN CATCH

		ROLLBACK TRANSACTION
		EXEC [Log].[ExecutionEnd] @Status = 'Error'

		;THROW 51000,'Alter Table Error - transaction rolled back',1 

	END CATCH

	/********************* Updating DisplayedPatient and ReachHistoric tables***/
	
	--DECLARE @ReleaseDate date=
	--   (SELECT min(ReleaseDate)
	--	FROM [REACH].[ReleaseDates] 
	--	WHERE ReleaseDate > 
	--		(SELECT max(RunDate) FROM [Reach].[RiskScore])
	--	)
	--PRINT @ReleaseDate

	/***Delete data for release date if it already exists***/
	DELETE [REACH].[RiskScoreHistoric]
	WHERE ReleaseDate = @ReleaseDate and ModelName = 'Reach Vet 2.0'

	-- adding data to riskscorehistoric
	INSERT INTO [REACH].[RiskScoreHistoric] (
		 PatientPersonSID
		,Sta3n_EHR
		,ChecklistID
		,RunDatePatientICN
		,RiskScoreSuicide
		,RiskRanking
		,DashboardPatient
		,ADRPriorityGroup
		,ReleaseDate
		,RunDate
		,EditError
		,ImpactedByRandomization
    ,Randomized
    ,ModelName
		)
	SELECT PatientPersonSID
		,Sta3n_EHR
		,ChecklistID
		,RunDatePatientICN
		,RiskScoreSuicide
		,RiskRanking
		,DashboardPatient
		,PriorityGroup
		,@ReleaseDate
		,RunDate
		,EditError=NULL
		--Former field was changed later on 2023/06/29 to [Reach].[RiskScore].[ImpactedByRandomization] in the source table but not in this downstream SP. Did not cause a Build error, but did surface a Build Warning. 
		,ImpactedByRandomization
    ,Randomized
    , 'Reach Vet 2.0' as ModelName
	FROM [Reach].[RiskScore];

	EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END --End of procedure