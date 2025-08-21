
-- =============================================
-- Author:		Amy Robinson
-- Create date: 11/16/2014
-- Description:	VISN 21 Stations with National and VISN21 choices
-- MODIFICATIONS:
	-- 2017-05-07	Bhavani, Bandi	Testing by modifying existing SP ([App].[p_VISN])
	-- 2021-04-06	RAS	Created v02 - Added @LSV parameter.
	-- 2021-04-15	RAS	Remvoed National from returned VISN lists.

-- TESTING:
	-- EXEC [App].[p_VISN_v02] @User = 'VHA21\VHAPALSTEPHR6' ,@LSV=1
-- =============================================
CREATE PROCEDURE [App].[p_VISN_v02]
  @LSV BIT 
  ,@User varchar(50) = NULL
 
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- DECLARE @User varchar(50) = 'VHA01\VHATOGSMITHK', @LSV BIT = 0

SELECT DISTINCT 
	f.VISN 
	,CONVERT(CHAR(10),f.VISN ) AS VISNNAME
	--,CASE WHEN CONVERT(CHAR(10),f.VISN ) = '0' THEN 'National' ELSE CONVERT(CHAR(10),f.VISN ) END AS VISNNAME
FROM [LookUp].[ChecklistID] f
WHERE (
		Sta3n IN (SELECT Sta3n FROM [App].[Access] (@User))
		) 
	OR (
		@LSV=0 AND VISN > 0
		)
ORDER BY VISN

END

/***
exec [dbo].[sp_SignAppObject] @ObjectName = 'p_VISN'
***/