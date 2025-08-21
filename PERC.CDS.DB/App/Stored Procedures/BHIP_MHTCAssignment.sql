
-- ==========================================================================================
-- Authors:     Catherine Barry
-- Create date: 2023-08-21
-- Description: Create App for SSRS BHIP MHTC Assignment report
--                
-- Modifications:
-- ==========================================================================================



CREATE PROCEDURE [App].[BHIP_MHTCAssignment]

	 @User varchar(25)
	,@Station varchar(1000)

	--EXEC  [App].[BHIP_MHTCAssignment] 'VHA21\vhapalbarryc','554'

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--DECLARE @UserID varchar(100) =  'VHA21\vhapalbarryc'
	--DECLARE @Station varchar(1000) = '554'
	---------------------------------------------------------------
	-- LSV Permissions
	---------------------------------------------------------------
	--First, create a table with all the patients that the user has permission to see
--	DROP TABLE IF EXISTS #PatientLSV;
	SELECT pat.*
	FROM [BHIP].[MHTCAssignment] as pat WITH (NOLOCK)
	INNER JOIN (SELECT Sta3n FROM [App].[Access](@User)) as Access 
		on LEFT(pat.ChecklistID,3) = Access.Sta3n
	WHERE pat.checklistid IN (SELECT value FROM string_split(@Station,',')) ---@Station 


END