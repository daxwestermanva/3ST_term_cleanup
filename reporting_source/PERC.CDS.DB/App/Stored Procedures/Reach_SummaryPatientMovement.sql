-- =============================================
-- Author:		Amy Robinson
-- Create date: 9/19/16
-- Description:	Transfer dataset for summary report
/*
EXEC [App].[Reach_SummaryPatientMovement] 'VHA21\VHAPALSTEPHR6','640',21,1
*/
-- =============================================
CREATE PROCEDURE [App].[Reach_SummaryPatientMovement]
	-- Add the parameters for the stored procedure here
	@User varchar(MAX),
    @Station varchar(10),
	@VISN varchar(max), 
	@TopPercent varchar(10)


AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

SELECT MVIPersonSID
INTO #patients
FROM [REACH].[PatientReport]
WHERE Top01Percent IN (SELECT value FROM string_split(@TopPercent ,','))

SELECT q19.MVIPersonSID
	,AssignedChecklistID =CASE WHEN q0.ChecklistID IS NULL THEN q19.ChecklistID + ' Pending' ELSE q19.ChecklistID END 
	,AssignedStation=CASE WHEN q0.ChecklistID IS NULL THEN q19.AssignedStation + ' Pending' ELSE AssignedStation END 
	,AssignedVISN
	,q0.ChecklistID as NewSta6aID
	,NewVISN
	,NewStation
FROM (
	SELECT m.MVIPersonSID
		  ,w.ChecklistID
		  ,c.ADMPARENT_FCDM as AssignedStation
		  ,c.VISN AS AssignedVISN
    FROM [REACH].[Writeback] AS w
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] m WITH(NOLOCK) on w.PatientSID=m.PatientPersonSID
    INNER JOIN #patients p ON m.MVIPersonSID = p.MVIPersonSID
    INNER JOIN [LookUp].[ChecklistID] AS c ON w.ChecklistID = c.ChecklistID
	WHERE  QuestionNumber = 19 
		AND QuestionStatus = 1
	) AS q19 --a
LEFT OUTER JOIN (
	SELECT mm.MVIPersonSID
		  ,ww.ChecklistID
		  ,cc.ADMPARENT_FCDM as NewStation
		  ,cc.VISN AS NewVISN
	FROM [REACH].[Writeback] AS ww
	INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mm WITH(NOLOCK) ON ww.PatientSID=mm.PatientPersonSID
	INNER JOIN #patients pp ON mm.MVIPersonSID = pp.MVIPersonSID
	INNER JOIN [LookUp].[ChecklistID] AS cc ON ww.ChecklistID = cc.ChecklistID
	WHERE QuestionNumber = 0 
		AND QuestionStatus = 1
	) AS q0 ON q0.MVIPersonSID = q19.MVIPersonSID --b
WHERE (q19.ChecklistID <> q0.ChecklistID 
		OR q0.ChecklistID IS NULL) 
	AND (q19.AssignedVISN IN  (SELECT value FROM string_split(@VISN ,','))
		OR NewVISN IN (SELECT value FROM string_split(@VISN ,','))
		)
END