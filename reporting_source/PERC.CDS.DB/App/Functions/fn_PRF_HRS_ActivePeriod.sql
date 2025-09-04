/* =============================================
-- Author:		Rebecca Stephens (RAS)
-- Create date: 2018-03-30
-- Description:	Pulls last flag record for patients who had an active 
	PRF High Risk for Suicide during the indicated time period (@startdate,@enddate)
-- =============================================*/
CREATE FUNCTION [App].[fn_PRF_HRS_ActivePeriod] 
(
	 @StartDate date
	,@EndDate date
)

--TESTING:
--SELECT * FROM [App].[fn_PRF_HRS_ActivePeriod] (DATEADD(YEAR,-1,CAST(GetDate() AS DATE)),CAST(GetDate() AS DATE)) --WHERE ActiveFlag=1

RETURNS TABLE 
	RETURN
 (
	--DECLARE @StartDate date = DATEADD(YEAR,-1,CAST(GetDate() AS DATE))
	--,@EndDate date = CAST(GetDate() AS DATE)
	SELECT f.MVIPersonSID
		  ,f.ActionType
		  ,f.ActionDateTime
		  ,ActiveFlag=CASE WHEN a.MVIPersonSID IS NULL THEN 0 ELSE 1 END 
		  ,ISNULL(f.OwnerChecklistID,a.OwnerChecklistID) OwnerChecklistID
	FROM (
			--DECLARE @StartDate date = DATEADD(YEAR,-1,CAST(GetDate() AS DATE))
			--,@EndDate date = CAST(GetDate() AS DATE)		
  		SELECT MVIPersonSID,ActionType,ActionDateTime,OwnerChecklistID
		FROM [OMHSP_Standard].[PRF_HRS_CompleteHistory]
		WHERE EntryCountDesc=1
			AND (
				(ActionDateTime<@StartDate AND HistoricStatus='Y') --The latest action is before target start date and the action did NOT result in inactivation
				OR ActionDateTime BETWEEN @StartDate AND @EndDate  --The latest action ocurred within the target time period
				)
		) f
	--add flag for currently active PRF-HRS
	LEFT JOIN [PRF_HRS].[ActivePRF] a on a.MVIPersonSID=f.MVIPersonSID
  )