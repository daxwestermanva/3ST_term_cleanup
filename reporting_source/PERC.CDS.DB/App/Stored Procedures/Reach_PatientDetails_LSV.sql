 
 
 
/************************************************************************************
 Author:		<Amy Robinson>
 Create date: <9/19/2016>
 Description:	Main data date for the Persceptive Reach report
 Updates
	2019-02-18	LM	- Added fields from REACH.History table
	2019-10-09	SG  - Updated code with [Config].[REACH_OutreachStatusQuestions]
	2020-01-28	RAS - Removed join to RiskScore so we don't have to worry about MVIPersonSID being outdated. 
					  PatientReport table has the data needed which is pulled in with dynamic MVIPersonSID nightly.
	2020-10-15	LM  - Added SourceEHR to indicate possible Cerner data
	2021-09-17	JEB	- Enclave Refactoring
	2022-05-16	LM	- Added Date of Birth for easier patient lookup in Cerner
	2025-05-06  LM - Updated references to point to REACH 2.0 objects
 
	EXEC [App].[Reach_PatientDetails_LSV] 
		 @User = 'vha21\vhapalrobina'
		,@Station = '528A8'
		,@Patient = 44345627
		,@QuestionStatus = 0 
		,@QuestionNumber = 5
 
************************************************************************************/
CREATE   PROCEDURE [App].[Reach_PatientDetails_LSV]
(
    @User VARCHAR(MAX),
	@Station VARCHAR(MAX),
    @Patient INT,
    @QuestionNumber VARCHAR(10),
    @QuestionStatus INT
)
AS
BEGIN
	--For inline testing
	--DECLARE @User VARCHAR(MAX) = 'vha21\vhapalrobina' ,@Station VARCHAR(MAX) = '528A8' ,@Patient INT = 44345627 ,@QuestionNumber VARCHAR(10) = '0' ,@QuestionStatus INT = 5
 
	DECLARE @PatientSID INT
	SET @PatientSID =
		(
			SELECT PatientSID 
			FROM [REACH].[PatientReport] WITH (NOLOCK)
			WHERE MVIPersonSID = @Patient
		)
 
	DECLARE @PatientICN VARCHAR(50)
	SET @PatientICN =
		(
			SELECT PatientICN 
			FROM Common.MVIPersonSIDPatientPersonSID WITH (NOLOCK)
			WHERE PatientPersonSID = @PatientSID
		)
 
	MERGE [REACH].[Writeback] D
	USING 
		(  
			SELECT DISTINCT 
				 @PatientSID AS PatientSID
				,@Station AS ChecklistID
				,@PatientICN AS EntryDatePatientICN
				,a.QuestionNumber
				,a.Question
				,a.QuestionType
				,@QuestionStatus AS QuestionStatus
				,GETDATE() AS EntryDate
				,@User AS NtLogin 
				,(SELECT LastName +','+FirstName FROM [LCustomer].[LCustomer] WHERE ADDomain + '\' + Adlogin = @User) AS UserName 
				,(SELECT Email FROM [LCustomer].[LCustomer] WHERE ADDomain + '\' + Adlogin = @User) AS UserEmail 
			FROM [Config].[REACH_OutreachStatusQuestions] a WITH (NOLOCK)
			WHERE a.QuestionNumber = @QuestionNumber  
		) m 
		ON D.PatientSID = m.PatientSID 
		AND d.QuestionNumber = m.QuestionNumber
	WHEN NOT MATCHED BY TARGET 
		THEN
			INSERT (ChecklistID,PatientSID,QuestionNumber,Question,QuestionType,QuestionStatus,EntryDate,NtLogin,UserName,UserEmail,EntryDatePatientICN)
			VALUES (ChecklistID,PatientSID,QuestionNumber,Question,QuestionType,QuestionStatus,EntryDate,NtLogin,UserName,UserEmail,EntryDatePatientICN)
	WHEN MATCHED 
		THEN
			UPDATE SET
				 d.ChecklistID = m.ChecklistID
				,d.QuestionStatus = m.QuestionStatus
				,d.NtLogin = m.NtLogin
				,d.UserEmail = m.UserEmail
				,d.UserName = m.UserName
				,d.EntryDate = m.EntryDate
   ;
     
	DELETE [REACH].[Writeback]
	WHERE PatientSID IS NULL
	;
 
	INSERT INTO [Reach].[WritebackHistoric]
	SELECT DISTINCT 
		 @PatientSID AS PatientSID
		,@Station AS ChecklistID
		,a.QuestionNumber
		,a.Question
		,a.QuestionType
		,@QuestionStatus AS QuestionStatus
		,GETDATE() AS EntryDate
		,@User AS NtLogin 
		,(SELECT LastName +','+FirstName FROM [LCustomer].[LCustomer] WHERE ADDomain + '\' + Adlogin = @User) AS UserName 
		,(SELECT Email FROM [LCustomer].[LCustomer] WHERE ADDomain + '\' + Adlogin = @User) AS UserEmail 
		,@PatientICN AS EntryDatePatientICN 
	FROM [Config].[REACH_OutreachStatusQuestions] a WITH (NOLOCK)
	WHERE a.QuestionNumber = @QuestionNumber  
	;
 
	SELECT DISTINCT 
		a.MVIPersonSID
		,a.ChecklistID
		,a.RiskRanking
		,a.RiskScoreSuicide AS RiskScore
		,a.Top01Percent
		,a.DateEnteredDashboard
 
		,sp.PatientICN
		,sp.PatientName
		,sp.PreferredName
		,sp.PatientSSN
		,sp.LastFour
		,sp.Age
		,sp.DisplayGender AS Gender
		,sp.DateOfBirth
		,CASE WHEN sp.PriorityGroup=8 and sp.PrioritySubGroup IN ('e','g')
			THEN CONCAT('Ineligible for care (Priority group ',sp.PriorityGroup,sp.PrioritySubGroup,')')
			ELSE NULL END AS PriorityGroup 
		,a.PCFutureAppointmentDateTime_ICN
		,a.PCFuturePrimaryStopCode_ICN
		,a.PCFutureStopCodeName_ICN
		,a.PCFutureAppointmentFacility_ICN
		,a.MHFutureAppointmentDateTime_ICN
		,a.MHFuturePrimaryStopCode_ICN
		,a.MHFutureStopCodeName_ICN
		,a.MHFutureAppointmentFacility_ICN
		,a.OtherFutureAppointmentDateTime_ICN
		,a.OtherFuturePrimaryStopCode_ICN
		,a.OtherFutureStopCodeName_ICN
		,a.OtherFutureAppointmentFacility_ICN
		,a.MHRecentVisitDate_ICN
		,a.MHRecentStopCode_ICN
		,a.MHRecentStopCodeName_ICN
		,a.MHRecentSta3n_ICN
		,a.PCRecentVisitDate_ICN
		,a.PCRecentStopCode_ICN
		,a.PCRecentStopCodeName_ICN
		,a.PCRecentSta3n_ICN
		,a.OtherRecentVisitDate_ICN
		,a.OtherRecentStopCode_ICN
		,a.OtherRecentStopCodeName_ICN
		,a.OtherRecentSta3n_ICN
		,sp.StreetAddress1
		,sp.StreetAddress2
		,sp.StreetAddress3
		,sp.City
		,sp.State AS StateAbbrev
		,sp.Zip
		,sp.PhoneNumber AS HomePhone
		,sp.WorkPhoneNumber AS WorkPhone
		,sp.CellPhoneNumber AS CellPhone
		,a.Admitted 
 
		,h.MonthsIdentifiedAllTime
		,h.MonthsIdentified12
		,h.MonthsIdentified24
		,h.FirstRVDate
		,h.MostRecentRVDate
		,h.LastIdentifiedExcludingCurrentMonth
 
		,ReleaseDate=(SELECT MAX(ReleaseDate) FROM [REACH].[RiskScoreHistoric])
		,CASE WHEN rf.MVIPersonSID IS NOT NULL THEN 1 ELSE NULL END AS HighRisk
		,c.Facility
		,c.VISN
		,sp.SourceEHR
	FROM [REACH].[PatientReport] a WITH (NOLOCK)
	LEFT JOIN [REACH].[History] h WITH (NOLOCK) 
		ON a.MVIPersonSID = h.MVIPersonSID
	INNER JOIN [Common].[MasterPatient] sp WITH (NOLOCK) 
		ON sp.MVIPersonSID=a.MVIPersonSID 
	LEFT JOIN [PRF_HRS].[ActivePRF] rf WITH (NOLOCK) 
		ON rf.MVIPersonSID=a.MVIPersonSID
	INNER JOIN [LookUp].[ChecklistID] c WITH (NOLOCK) 
		ON c.ChecklistID=a.ChecklistID
	INNER JOIN (SELECT sta3n FROM [App].[Access](@User)) Access 
		ON LEFT(a.ChecklistID,3) = Access.sta3n 
	WHERE (sp.PatientICN=@PatientICN)
 
END