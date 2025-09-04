

/* =============================================
-- Author:	Liam Mina
-- Create date: 6/15/2023
-- Description:	Display discrepancies in patient record flags across EHRs
-- Modifications:
	2023-09-20	LM	Add facility names for easier use by end users

   ============================================= */
CREATE PROCEDURE [App].[PRF_Discrepancies]
	@User varchar(50),
	@FlagType varchar(100),
	@SourceEHR varchar(5),
	@PastWeekAction varchar(10),
	@ActiveAnywhere varchar(10)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--DECLARE @User varchar(100)='vha21\vhapalminal', @FlagType varchar(100) = 'HIGH RISK FOR SUICIDE,BEHAVIORAL,MISSING PATIENT', @SourceEHR varchar(5) = 'V,VM', @PastWeekAction varchar(10) ='Yes,No', @ActiveAnywhere varchar(10)='1';

DECLARE @FlagTypeList TABLE ([NationalPatientRecordFlag] VARCHAR(max))
INSERT @FlagTypeList  SELECT value FROM string_split(@FlagType, ',')

DECLARE @PastWeekActionList TABLE ([PastWeekAction] VARCHAR(max))
INSERT @PastWeekActionList  SELECT value FROM string_split(@PastWeekAction, ',')

DECLARE @ActiveAnwyhereList TABLE ([ActiveAnywhere] VARCHAR(max))
INSERT @ActiveAnwyhereList  SELECT value FROM string_split(@ActiveAnywhere, ',')


DECLARE @SourceEHRList TABLE ([SourceEHR] VARCHAR(5))
INSERT @SourceEHRList  SELECT value FROM string_split(@SourceEHR, ',')

DROP TABLE IF EXISTS #DisplayFacility
SELECT DISTINCT MVIPersonSID
	,NationalPatientRecordFlag
	,OwnerFacility
INTO #DisplayFacility
FROM [PRF].[Discrepancies] WITH (NOLOCK)
WHERE OwnerFacility IS NOT NULL

DROP TABLE IF EXISTS #flags
SELECT a.MVIPersonSID
	,a.NationalPatientRecordFlag
	,CASE WHEN a.Sta3n = 200 THEN '(200) Oracle Health' ELSE c1.ADMPARENT_FCDM END AS Sta3n
	,a.Active_Sta3n
	,c2.ADMPARENT_FCDM AS OwnerFacility
	,a.LastActionDateTime
	,CASE WHEN DateAdd(day,7,CAST(MAX(a.LastActionDateTime) OVER (PARTITION BY a.MVIPersonSID, a.NationalPatientRecordFlag) as date)) >= getdate() THEN 'Yes' ELSE 'No' END AS PastWeekAction 
	,a.LastActionType
	,a.PatientRecordFlagHistoryComments
	,a.SourceEHR
	,a.ActiveAnywhere
	,b.PatientName
	,b.DateOfDeath_SVeteran
	,b.PatientICN
	,b.PatientSSN
	,b.EDIPI
  INTO #flags
  FROM [PRF].[Discrepancies] a WITH (NOLOCK)
  INNER JOIN [Common].[MasterPatient] b WITH (NOLOCK)
	ON a.MVIPersonSID = b.MVIPersonSID
  INNER JOIN @FlagTypeList f 
	ON f.NationalPatientRecordFlag = a.NationalPatientRecordFlag
  INNER JOIN @SourceEHRList s
	ON s.SourceEHR = a.SourceEHR
  INNER JOIN #DisplayFacility d
	ON a.MVIPersonSID = d.MVIPersonSID
	AND a.NationalPatientRecordFlag = d.NationalPatientRecordFlag
  INNER JOIN (SELECT Sta3n from [App].[Access] (@User)) as Access 
	ON LEFT(d.OwnerFacility,3)=Access.sta3n
  LEFT JOIN (SELECT * FROM [Lookup].[ChecklistID] WITH (NOLOCK) WHERE Sta3nFlag=1) c1 
	ON a.Sta3n = c1.Sta3n
  LEFT JOIN [Lookup].[ChecklistID] c2 WITH (NOLOCK)
	ON a.OwnerFacility = c2.ChecklistID

  SELECT DISTINCT f.* FROM #flags f
  INNER JOIN @PastWeekActionList l
	ON f.PastWeekAction=l.PastWeekAction
  INNER JOIN @ActiveAnwyhereList a
	ON f.ActiveAnywhere = a.ActiveAnywhere
  ;

END