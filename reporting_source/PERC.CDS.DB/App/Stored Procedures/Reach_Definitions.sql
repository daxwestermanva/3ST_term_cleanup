-- =============================================
-- Author:		Amy Robinson
-- Create date: 1/4/17
-- Description:	
-- =============================================
CREATE PROCEDURE [App].[Reach_Definitions]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT * FROM [REACH].[Definitions] WHERE Risk is not null;


END