

-- =============================================
-- Author:		Tolessa Gurmessa
-- Create date: 3/21/2024
-- Description:	Adopted from ORM measure parameter to populate the quarter parameter in DoD OUD report
-- =============================================
CREATE PROCEDURE [App].[p_ORM_Quarters]

@User VARCHAR(MAX)

AS
BEGIN
	
	SET NOCOUNT ON;

   
SELECT DISTINCT FYQ	  
FROM [ORM].[DoDOUDPatientReport]
WHERE EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
ORDER BY FYQ DESC

END