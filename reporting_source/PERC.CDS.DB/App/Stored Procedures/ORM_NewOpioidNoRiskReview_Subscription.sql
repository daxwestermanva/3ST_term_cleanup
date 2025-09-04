-- =============================================
-- Author:		Claire Hannemann
-- Create date: 7/9/2025
-- Description:	ORM New Opioid No Risk Review - For automating emails

-- =============================================
CREATE PROCEDURE [App].[ORM_NewOpioidNoRiskReview_Subscription]

AS
BEGIN
	SET NOCOUNT ON;
 
 SELECT 'claire.hannemann@va.gov' as Email
 --UNION
 --SELECT 'amy.robinson8@va.gov' as Email
 --UNION
 --SELECT 'liam.mina@va.gov' as Email

--select distinct EmailAddress
--from ORM.NewOpioidNoRiskReview
--where EmailAddress is not null and DaysOld <= 80
		
 
END