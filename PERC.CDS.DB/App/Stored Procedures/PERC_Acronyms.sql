

-- =============================================
-- Author:	Liam Mina	 
-- Create date: 05/17/2022
-- Description:	Lookup for common PERC acronyms

-- =============================================
CREATE PROCEDURE [App].[PERC_Acronyms]
	@LookupOrSubmit varchar(15),
	@Acronym varchar(max)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--DECLARE @Acronym varchar(max) = 'oat'; DECLARE @LookupOrSubmit varchar(15) = 'Look Up'

  SELECT Acronym
		,Definition
		,Description
  FROM [Config].[PERC_Acronyms]
  WHERE Acronym LIKE '%'+@Acronym+'%'
  AND @LookupOrSubmit='Look Up'
 -- AND @Acronym <> ''
  UNION ALL
  SELECT Acronym
		,Definition
		,Description + ' (Not yet validated; submitted on ' + CONVERT(varchar,DateSubmitted,101) + ' by ' + UserID + ')'
  FROM [CDS].[PERC_Acronyms_Writeback]
  WHERE Acronym LIKE '%'+@Acronym+'%'
  AND @LookupOrSubmit='Look Up'
 -- AND @Acronym <> ''
  ORDER BY Acronym

END