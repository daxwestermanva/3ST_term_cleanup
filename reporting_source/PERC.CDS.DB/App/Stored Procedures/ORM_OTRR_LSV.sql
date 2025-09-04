
/*=============================================
-- Author:		Tolessa Gurmessa
-- Create date: 2021-11-05
-- Description: Summary patient info - 1 row per patient location 
      (Modification of ORM_PatientQuickView_LSV)
-- 2021-11-16 TG - made changes to add new variables from AD; renamed sp
-- 2022-08-03 TG - making changes to the SP to match the new OTRR requirements.
-- 2022-08-09 TG - adding opioid agonists to the list of opioids, last pcp contact
-- 2022-08-30 RAS - Removed 3 ICNs from test list that are not appropriate for deid report.

=============================================*/
CREATE PROCEDURE [App].[ORM_OTRR_LSV]
	-- Add the parameters for the stored procedure here
  
  @Prescriber nvarchar(max), --Team/Provider
  @Station varchar(255),
  @Cohort varchar(10),
  @NoPHI varchar(10),
  @User varchar(100),
  @GroupType varchar(20)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--DECLARE @Station varchar(255) =  '640'
--DECLARE @User varchar(100) = 'vha21\vhapalstephr6'
--DECLARE @NoPHI varchar(10) = '1'
--DECLARE @Measure varchar(max) = '-5'


DROP TABLE IF EXISTS #cohort;
SELECT DISTINCT mp.PatientICN
	,s.MVIPersonSID
	,mp.PatientSSN
	,mp.LastFour
	,mp.PatientName
	,mp.SourceEHR
INTO  #cohort
FROM (  
	SELECT MVIPersonSID
		  ,ChecklistID 
	FROM [ORM].[PatientOTRRView] 
	WHERE ChecklistID = @Station	
	) as s
INNER JOIN (SELECT Sta3n FROM [App].[Access] (@User)) as f on f.Sta3n = LEFT(ChecklistID,3)
INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK) ON mp.MVIPersonSID=s.MVIPersonSID
;

INSERT INTO #cohort
SELECT PatientICN,MVIPersonSID,PatientSSN,RIGHT(4,PatientSSN),PatientName,SourceEHR='V'
FROM [Common].[MasterPatient] WITH (NOLOCK)
WHERE PatientICN IN (
	'1013673699','1019376947'
	)
	AND @NoPHI = 1

SELECT DISTINCT	c.PatientICN
	,c.PatientName
	,c.PatientSSN
	,c.LastFour
	,b.DateOfBirth
	,b.Age
	,b.Gender
	,b.MEDD30d
	,c.SourceEHR
	,b.ChecklistID
	,b.Facility
    ,b.MOUD
    ,b.OpioidForPain_Rx
	,b.Benzodiazepine_Rx
    ,b.SedatingPainORM_Rx
    ,b.TramadolOnly
    ,b.PatientRecordFlag_Suicide
    ,b.RiosordScore
    ,b.RiosordRiskClass
    ,b.RiskCategory
    ,b.RiskCategoryLabel
    ,b.RiskScore
	,b.UDSDate
    ,b.DaysSinceUDS
    ,b.ConsentDate
	,b.DaysSinceConsent
	,b.PDMPDate
	,b.DaysSincePDMP
	,b.ChronicOpioid
    ,b.ApptDateTime_PC
    ,b.ApptLocation_PC
    ,b.ApptStop_PC
    ,b.ApptDateTime_MH
    ,b.ApptLocation_MH
    ,b.ApptStop_MH
    ,b.PCP
    ,b.PCPsid
    ,b.MHTC
    ,b.MHTCsid
    ,b.BHIP
    ,b.BHIPsid
    ,b.PACT
    ,b.PACTsid
	,b.CCP
	,b.CCPsid
    ,b.LocalPrescriberSID
    ,b.LocalPrescriber
    ,b.OtherPrescriber
    ,b.OtherPrescriberSID
    ,b.OtherPrescriberLocation
	,b.NaloxoneDate
	,b.NaloxoneContext
,op.Opioids
	,pm.Sedatives
	,sd.SedatingPain
	,StopCodeName = PrimaryStopCodeName
	,a.VisitDatetime AS AppointmentDatetime
FROM  #Cohort as c
INNER JOIN [ORM].[PatientOTRRView] as b WITH (NOLOCK) on c.MVIPersonSID = b.MVIPersonSID
LEFT JOIN (SELECT MVIPersonSID, STRING_AGG(DrugNameWithDose, ', ') AS Opioids
            FROM [Present].[Medications] WITH (NOLOCK)
            WHERE 1 IN ([OpioidForPain_Rx],[OpioidAgonist_Rx])
            GROUP BY MVIPersonSID) op  ON c.MVIPersonSID = op.MVIPersonSID
LEFT JOIN (SELECT MVIPersonSID, STRING_AGG(DrugNameWithDose, ', ') AS Sedatives
            FROM [Present].[Medications] WITH (NOLOCK)
            WHERE 1 IN ([Benzodiazepine_Rx])
            GROUP BY MVIPersonSID) pm  ON c.MVIPersonSID = pm.MVIPersonSID
LEFT JOIN (SELECT MVIPersonSID, STRING_AGG(DrugNameWithDose, ', ') AS SedatingPain
            FROM [Present].[Medications] WITH (NOLOCK)
            WHERE 1 IN ([SedatingPainORM_rx])
            GROUP BY MVIPersonSID) sd  ON c.MVIPersonSID = sd.MVIPersonSID
LEFT JOIN (SELECT MVIPersonSID, PrimaryStopCodeName, PrimaryStopCode, VisitDatetime, Sta3n, ChecklistID ,ApptCategory, SecondaryStopCode
			FROM [Present].[AppointmentsPast] WITH (NOLOCK)
			WHERE MostRecent_ICN=1
				AND ApptCategory IN ('PCRecent')
					) a
					ON a.MVIPersonSID = c.MVIPersonSID
WHERE @NoPHI = 1 
	OR (
	--b.RiskCategory IN (SELECT value FROM string_split(@RiskGroup ,',')) 
		(
			(@Cohort=1 and b.MOUD = 1) 
			OR (@Cohort=2 and b.OpioidForPain_Rx = 1) 
			OR (@Cohort=3 and b.MOUD in (1,0)) 
			OR (@Cohort=4 and b.TramadolOnly=1)  
			OR (@Cohort=5 and b.ChronicOpioid=1)
			)
		AND b.ChecklistID=@Station
		AND (
			 (@GroupType=2 AND PCPSID  IN (SELECT value FROM string_split(@Prescriber ,','))	)
		  OR (@GroupType=4 AND PACTsid IN (SELECT value FROM string_split(@Prescriber ,','))	)
		  OR (@GroupType=5 AND MHTCsid IN (SELECT value FROM string_split(@Prescriber ,','))	)
		  OR (@GroupType=3 AND BHIPsid IN (SELECT value FROM string_split(@Prescriber ,','))	)
		  OR (@GroupType=1 AND LocalPrescriberSID in (SELECT value FROM string_split(@Prescriber ,','))	) 
		  OR (@GroupType=-5)
		  OR (@GroupType=6 AND CCPsid IN (SELECT value FROM string_split(@Prescriber ,','))	)
			)	
		)
 			 
END