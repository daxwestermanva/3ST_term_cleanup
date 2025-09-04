 
 
 
-- =============================================
-- Author:		Amy Robinson
-- Create date: 11/16/2014
-- Description:	VISN 21 Stations with National and VISN21 choices
-- =============================================
CREATE PROCEDURE [App].[p_VISN_LSV]
  --@FiscalYear varchar(50)
  @User varchar(50)
 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
 
		/***
exec [dbo].[sp_SignAppObject] @ObjectName = 'p_VISN_LSV'
***/
 
SELECT DISTINCT
	VISN
FROM [Dim].[VistaSite] as a
INNER JOIN (
	SELECT STA3N FROM [App].[Access] (@User)
	) as Access on a.Sta3n = Access.Sta3n
WHERE VISN > 0 
ORDER BY VISN 
 
 
END