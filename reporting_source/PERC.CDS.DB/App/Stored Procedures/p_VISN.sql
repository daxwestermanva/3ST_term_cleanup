-- =============================================
-- Author:		Amy Robinson
-- Create date: 11/16/2014
-- Description:	VISN 21 Stations with National and VISN21 choices
-- Bhavani, Bandi, 5/7/2017 - Testing by modifying existing SP ([App].[p_VISN])
-- EXEC [App].[p_VISN] @User = 'VHA21\VHAPALBANDIH'
-- =============================================
CREATE PROCEDURE [App].[p_VISN]
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
	  ,CASE WHEN CONVERT(CHAR(10),VISN ) = '0' THEN 'National' ELSE CONVERT(CHAR(10),VISN ) END AS VISNNAME
	  ,MAX(CASE WHEN a.IOCDate < getdate() THEN 1 ELSE 0 END) OVER (PARTITION BY VISN) AS Active_OracleH
FROM [LookUp].[ChecklistID] as a
where visn >= 0 
order by VISN 


END