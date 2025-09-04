
-- =============================================
-- Author:		<Robinson,Amy>
-- Create date: <6/19/17>
-- Description:	<main data set for patient report >
-- =============================================
CREATE PROCEDURE [App].[Pharm_Antidepressant_mdd43h_PatientReport_LSV]
	
	@Facility varchar(20),
	@Measure varchar(1000),
	@User varchar(50),
	@MeasureStatus varchar(1000),
	@ClinicalStatus varchar(100),
	@Prescriber varchar(max)
  
AS
BEGIN

	SET NOCOUNT ON;
/*
  Declare @Facility varchar(20)
  Declare @Measure varchar(1000)
  Declare @User varchar(50)
  Declare @MeasureStatus varchar(1000)
  Declare @ClinicalStatus varchar(100)
  Declare @Prescriber varchar(max)
  
  Set @Facility =640
  Set @Measure = 'MDD47h'
  Set @User = 'vha21\vhapalrobina' 
  Set @MeasureStatus ='1,0' 
  Set @ClinicalStatus =1
  Set @Prescriber = '1465072, 803286010, 804254177, 1328092, 5160644, 805953363, 1458703, 7593279, 12578125, 1328911, 1302496, 10506348, 806344400, 805908932, 803395699, 1334587, 804730930, 8236300, 13675051, 800638187, 800464379, 803120809, 801550316, 802377330, 803322234, 805935693, 1293574, 11161349, 802745024, 1340879, 803090934, 1486157, 1356886, 1333185, 800332346, 800948546, 805950438, 806147913, 806903125, 1298701, 7169370, 806387231, 10794391, 1403498, 1313036, 1302857, 805716567, 804730956, 804730919, 805160470, 1295117, 803834602, 806974838, 804730939, 801604929, 1304108, 802601057, 800633221, 805764284, 805036234, 805935986, 1301810, 5169996, 801305119, 801610832, 1300931, 803123904, 13058342, 804475955, 805746420, 1347028, 1329630, 1456079, 1338478, 806015834, 8779139, 1465645, 806134205, 803921727, 806890791, 804627304, 1345322, 805889614, 10594598, 805797526, 1435747, 1334147, 10105691, 8872080, 805643601, 804730951, 803676289, 803901819, 801654834, 803911723, 803801590, 802794691, 804741940, 803625867, 10990278, 801006749, 800884170, 802365389, 800897801, 805196031, 8279221, 1318335, 806890554, 1329078, 1348952, 805615297, 1292012, 802367347, 14004237, 803876406, 802692155, 13676034, 805935448, 804756464, 1311431, 806833445, 805797581, 1347753, 1320840, 803160255, 1328088, 1350939, 1368205, 803890547, 1354308, 1357966, 1347169, 804748481, 802486723, 1363505, 805925009, 12227396, 805382354, 1301278, 1476463, 1471348, 803960674, 802936666, 806798309, 802762632, 800117162, 801125962, 1346837, 1296458, 1308930, 1350052, 803939266, 1366840, 806645354, 801104637, 1457494, 1427092, 800489224, 8862635, 8180573, 804630325, 12158497, 803013406, 8236491, 804268886, 12079379, 802118486, 805936050, 803856507, 803239471, 805883232, 803154522, 805797473, 1441845, 1314048, 1431331, 5155957, 1295150, 1353633, 805887944, 1359106, 806231152, 803120422, 1292036, 801151782, 1346703, 802442851, 805804821, 805935435, 1403500, 10337740, 803877973, 806807627, 806558150, 800413541, 1404768, 803090747, 1335800, 803913118, 13058547, 800168578, 802304148, 802963282, 805801578, 8418732, 805935575, 805884921, 1359962, 805899740, 804730935, 801006750, 802441972, 14004819, 7070921, 1412520, 800535250, 1398219, 804630326, 1479275, 804730924, 804652401, 805841226, 800547175, 804701389, 804730938, 802523727, 1332374, 806879243, 805220057, 806170617, 1408126, 803876642, 806052103, 11903728, 12389343, 803876519, 804634113, 802645072, 806879014, 1455013, 1321016, 1295162, 1487785, 806749445'
*/

SELECT a.* 
INTO #Writeback
FROM ( 
	SELECT ChecklistID
		  ,PatientSID
		  ,PatientReviewed
		  ,ExecutionDate
		  ,UserID
		  ,Comments
		  ,MAX(ExecutionDate) OVER(PARTITION BY w.PatientSID) as LastReviewDate		
	FROM [Pharm].[Antidepressant_Writeback] as w
    WHERE ChecklistID = @Facility 
	) as a
WHERE LastReviewDate = ExecutionDate
;

--Get list of relavant patients for the permissioned station
SELECT sa.MVIPersonSID
	  ,sa.ChecklistID
INTO #Patients
FROM [Present].[StationAssignments] sa  WITH (NOLOCK) --display at every facility in StationAssignments (add WHERE statement if need to limit)
INNER JOIN [LookUp].[ChecklistID] c  WITH (NOLOCK) ON c.ChecklistID=sa.ChecklistID
INNER JOIN (SELECT Sta3n FROM [App].[Access] (@User)) as f on f.Sta3n = c.Sta3n
WHERE sa.ChecklistID = @Facility

SELECT DISTINCT
	mp.PatientName
	,mp.Age
	,mp.DateOfBirth
	,mp.PatientSSN
	,a.ChecklistID
	,a.PatientSID
	,a.MeasureType
	,a.LastFillBeforeIndex
	,a.IndexDate
	,a.DaysSinceIndex
	,a.MeasureEndDate
	,a.TotalDaysSupply
	,a.PassedMeasure
	,a.DrugNameWithoutDose
	,a.RefillRequired
	,a.Prescriber
	,a.PrescriberSID
	,a.LastRelease
	,a.DaysSinceLastFill
	,a.RxType
	,a.LastDaysSupply
	,LastDayPillsOnHand = DateAdd(day,a.LastDaysSupply,a.LastRelease)
	,a.MPRToday
	,a.PCFutureAppointmentDateTime
	,a.PCFutureStopCodeName
	,a.MHRecentVisitDate
	,a.MHRecentStopCodeName
	,a.PCRecentVisitDate
	,a.PCRecentStopCodeName
	,a.MHFutureAppointmentDateTime
	,a.MHFutureStopCodeName
	,a.RxStatus
	,a.PrescriberName_Type
	,a.PrescriberType
	,w.PatientReviewed
	,w.ExecutionDate
	,w.UserID 
	,w.Comments 
	,w.LastReviewDate
	,mp.SourceEHR
FROM [Pharm].[AntiDepressant_MPR_PatientReport] as a  WITH (NOLOCK)
INNER JOIN [Common].[MasterPatient] mp  WITH (NOLOCK) on mp.MVIPersonSID=a.MVIPersonSID 
INNER JOIN #Patients sa ON
	sa.MVIPersonSID=a.MVIPersonSID
	AND sa.ChecklistID=a.ChecklistID
LEFT JOIN #writeback as w on a.PatientSID = w.PatientSID
WHERE a.MeasureType IN (SELECT value FROM string_split(@Measure ,','))
	AND PassedMeasure IN (SELECT value FROM string_split(@MeasureStatus ,','))
	AND (@ClinicalStatus = 1 
		OR (@ClinicalStatus = 2 AND a.MPRToday < 0.6)
		OR (@ClinicalStatus = 3 AND a.RefillRequired is not null)
		)
	AND PrescriberSID IN (SELECT value FROM string_split(@Prescriber ,','))



END