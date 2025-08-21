
-- =============================================
-- Author:		Claire Hannemann
-- Create date: 6/9/2025
-- Description:	[App].[ORM_NewOpioidNoRiskReview_LSV]
-- Test in Dev: EXEC [App].[ORM_NewOpioidNoRiskReview_LSV] 'VHA21\vhapalhannec','640','804151268'

-- MODIFICATIONS:

-- =============================================
CREATE PROCEDURE [App].[ORM_NewOpioidNoRiskReview_LSV]
	
	 @UserID varchar(25)
	,@Station varchar(100)
	,@Prescriber varchar(max)


AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

---------------------------------------------------------------
-- Parameters
---------------------------------------------------------------
--Create presciber parameter table
DECLARE @Prescriber1 TABLE (Prescriber INT)
INSERT @Prescriber1 SELECT value FROM string_split(@Prescriber, ',')

-- LSV Permissions
DROP TABLE IF EXISTS #PatientLSV;
SELECT DISTINCT MVIPersonSID
INTO  #PatientLSV
FROM [ORM].[NewOpioidNoRiskReview] as pat WITH (NOLOCK)
INNER JOIN (SELECT Sta3n FROM [App].[Access](@UserID)) as Access 
	on LEFT(pat.ChecklistID,3) = Access.Sta3n
WHERE ChecklistID=@Station 


SELECT a.*
FROM [ORM].[NewOpioidNoRiskReview] as a WITH (NOLOCK) 
INNER JOIN @Prescriber1 p on a.ProviderSID=p.Prescriber


END