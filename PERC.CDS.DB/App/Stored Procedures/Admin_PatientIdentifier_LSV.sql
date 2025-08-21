

-- =============================================
-- Author:		<Susana Martins>
-- Create date: <June 2017>
-- Description:	Create look-up table for patient IDs 
--				Input is first four letters of a patient name and the last 4 digits of the patient ssn
-- Updates
--	2019/01/18 - Jason Bacani - Formatting; NOLOCKs
--  2021/09/13 - Jason Bacani - Enclave Refactoring - Counts confirmed; Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
--
-- EXEC [App].[Admin_PatientIdentifier_LSV] @User = 'vha21\vhapalrobina' ,@Patient = 'NORR1234'
-- =============================================
CREATE PROCEDURE [App].[Admin_PatientIdentifier_LSV]
(
	@User varchar(max),
	@Patient varchar(1000)
)
AS
BEGIN
	SET NOCOUNT ON; 
 	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	--For inlne testing only
	--DECLARE @User varchar(max), @Patient varchar(1000), @Report varchar(100); SELECT @User = 'vha21\vhapalrobina' ,@Patient = 'NORR1234'

	SELECT DISTINCT 
		ck.VISN
		,sp.Sta3n
		,ck.Facility 
		,sp.PatientName
		,sp.PatientSID
		,sp.PatientSSN
		,sp.PatientICN
		,sp.BirthDateTime
		,sp.DeathDateTime
		,sp.DeceasedFlag
	FROM [SPatient].[SPatient] sp WITH (NOLOCK)
	LEFT JOIN [LookUp].[ChecklistID] ck WITH (NOLOCK)
		ON ck.Sta3n = sp.Sta3n --cast(sp.Sta3n AS varchar)
	INNER JOIN (SELECT Sta3n FROM [App].[Access](@User)) Access 
		ON sp.Sta3n = Access.sta3n 
	WHERE LEFT(sp.PatientName,4) + SUBSTRING(sp.PatientSSN,6,4) = @Patient
	ORDER BY sp.PatientName, ck.VISN, sp.Sta3n

END