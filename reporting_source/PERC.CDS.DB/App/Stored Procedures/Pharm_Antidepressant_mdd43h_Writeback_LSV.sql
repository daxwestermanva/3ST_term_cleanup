-- =============================================
-- Author:		<Robinson,Amy>
-- Create date: <6/19/17>
-- Description:	<main data set for patient report >
-- =============================================
CREATE PROCEDURE [App].[Pharm_Antidepressant_mdd43h_Writeback_LSV]
	
	@User varchar(50),
	@PatientSID varchar (100)
  
AS
BEGIN

	SET NOCOUNT ON;

SELECT DISTINCT a.*	  
	  ,w.PatientReviewed
	  ,w.ExecutionDate
	  ,w.UserID 
	  ,w.Comments 
	  ,w.LastReviewDate
	  ,mp.PatientSSN
	  ,mp.PatientName
FROM [Pharm].[AntiDepressant_MPR_PatientReport] as a  WITH (NOLOCK)
LEFT JOIN (
	SELECT ChecklistID
		  ,PatientSID
		  ,PatientReviewed
		  ,ExecutionDate
		  ,UserID
		  ,Comments
		  ,LastReviewDate
	FROM (   
		SELECT ChecklistID
			  ,PatientSID
			  ,PatientReviewed
			  ,ExecutionDate
			  ,UserID
			  ,Comments
			  ,MAX(ExecutionDate) OVER(PARTITION BY PatientSID) as LastReviewDate
		FROM [Pharm].[Antidepressant_Writeback]  WITH (NOLOCK)
		) as MaxWB
	WHERE LastReviewDate = ExecutionDate
	) as w on a.Patientsid = w.PatientSID
INNER JOIN [Present].[StationAssignments] sa  WITH (NOLOCK) on sa.MVIPersonSID=a.MVIPersonSID AND sa.ChecklistID=a.ChecklistID
INNER JOIN [Common].[MasterPatient] mp  WITH (NOLOCK) on mp.MVIPersonSID=a.MVIPersonSID
INNER JOIN (SELECT Sta3n FROM [App].[Access] (@User)) as f on f.Sta3n = sa.Sta3n_Loc
WHERE @PatientSID = a.PatientSID


END