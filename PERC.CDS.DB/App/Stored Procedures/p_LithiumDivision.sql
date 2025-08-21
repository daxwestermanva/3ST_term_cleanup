-- =============================================
-- Author:		<Robinson,Amy>
-- Create date: <3/30/18>
-- Description:	list of lithium divisions for parameter
-- =============================================
CREATE PROCEDURE [App].[p_LithiumDivision]
	
	@Station varchar(1000)
  
AS
BEGIN

	SET NOCOUNT ON;
/*
  Declare @Station varchar(20)
	 
  Set @Station =640
	
*/


SELECT DISTINCT
	DivisionName
	,sta6a       
FROM [Pharm].[LithiumPatientReport]
WHERE checklistid=@Station

END