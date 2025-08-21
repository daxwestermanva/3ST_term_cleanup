/* =============================================
-- Author: Rebecca Stephens (RAS)		 
-- Create date: 2017-09-20
-- Description:	Main dataset for post discharge engagement dashboard

 EXEC [App].[PDE_RecentApptsSub] 
    @MVIPersonSID=''
   ,@DisDay=''
   ============================================= */
CREATE PROCEDURE [App].[PDE_RecentApptsSub]

  @MVIPersonSID INT
 ,@DisDay date

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT DISTINCT 
		ra.*
		,mp.PatientName
		,mp.LastFour
		,mp.EDIPI
		,CAST(mp.DateOfBirth AS DATE) as DateOfBirth
	    ,CASE WHEN v.PDE=1 THEN 1 ELSE 0 END AS PossMissingCernerVisits
		,p.MVIPersonSID AS MVIPersonSID_Pass
		,p.ChecklistID_Metric
		,ch.VISN
FROM [PDE_Daily].[RecentAppts] as ra WITH (NOLOCK)
LEFT JOIN [OracleH_QI].[PossibleMHVisits] v WITH (NOLOCK)
	ON ra.MVIPersonSID = v.MVIPersonSID and PDE=1
LEFT JOIN [Common].[MasterPatient] mp WITH (NOLOCK)
	ON mp.MVIPersonSID=ra.MVIPersonSID
INNER JOIN [PDE_Daily].[PDE_PatientLevel] p WITH (NOLOCK)
	ON ra.MVIPersonSID=p.MVIPersonSID
INNER JOIN Lookup.ChecklistID ch WITH (NOLOCK)
	ON p.ChecklistID_Metric=ch.ChecklistID
WHERE ra.MVIPersonSID=@MVIPersonSID
	AND ra.DisDay=@DisDay
UNION ALL
--cases where no visits are being counted currently but there are possible missing MH visits from Oracle Health
SELECT	DISTINCT ra.*
		,mp.PatientName
		,mp.LastFour
		,mp.EDIPI
		,CAST(mp.DateOfBirth AS DATE) as DateOfBirth
	    ,CASE WHEN v.PDE=1 THEN 1 ELSE 0 END AS PossMissingCernerVisits
		,p.MVIPersonSID AS MVIPersonSID_Pass
		,p.ChecklistID_Metric
		,ch.VISN
FROM [PDE_Daily].[PDE_PatientLevel] p WITH (NOLOCK)
LEFT JOIN [PDE_Daily].[RecentAppts] as ra WITH (NOLOCK)
	ON p.MVIPersonSID=ra.MVIPersonSID
INNER JOIN [OracleH_QI].[PossibleMHVisits] v WITH (NOLOCK)
	ON p.MVIPersonSID = v.MVIPersonSID and v.PDE=1
INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK)
	ON mp.MVIPersonSID=p.MVIPersonSID
INNER JOIN Lookup.ChecklistID ch WITH (NOLOCK)
	ON p.ChecklistID_Metric=ch.ChecklistID
WHERE p.MVIPersonSID=@MVIPersonSID
	AND p.DisDay=@DisDay
	AND ra.MVIPersonSID IS NULL
ORDER BY ra.MVIPersonSID,VisitDateTime desc
;

END