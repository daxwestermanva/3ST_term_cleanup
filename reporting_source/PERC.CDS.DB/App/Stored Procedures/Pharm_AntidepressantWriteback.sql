-- =============================================
-- Author:		Sara Tavakoli
-- Create date: 9/8/2016
-- Description:	Writeback SP for Patient Table
-- Updates:
--	2023-09-19	LM	Remove string 'Enter Text Here' from writeback responses	
-- =============================================
CREATE PROCEDURE [App].[Pharm_AntidepressantWriteback]
    @Sta3n varchar(10),
	@PatientSID varchar(100),
	@User varchar(MAX),
	@Comments varchar(255)

AS
BEGIN
	SET NOCOUNT ON;

INSERT INTO [Pharm].[Antidepressant_Writeback]
SELECT DISTINCT 
	 @Sta3n as Sta3n
	,@PatientSID as PatientSID
	,1 as PatientReviewed
	,GetDate() as ExecutionDate
	,@User as UserID
	,SUBSTRING(REPLACE(@Comments,'Enter Text Here',''),1,255) AS Comments
	,'Antidepressant Cohort' as [VariableName]
	;

DELETE FROM [Pharm].[Antidepressant_Writeback]
WHERE Comments='Enter Text Here' 
	OR Comments IS NULL
	OR Comments = ''
 

END
