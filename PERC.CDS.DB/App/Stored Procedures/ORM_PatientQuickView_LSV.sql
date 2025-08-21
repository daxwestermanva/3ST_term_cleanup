-- =============================================
-- Author:		Rebecca Stephens
-- Create date: 2018-01-03
-- Description: Summary patient info - 1 row per patient location
-- 2021-12-21 TG pulled overdose information for Quick View report.
-- 2021-04-22 TG added Preparatory Behavior flag
-- 2022-08-08 TG Informed Consent appears as required for many patients because of OTRR changes
-- 2022-08-30 RAS - Removed 3 ICNs from test list that are not appropriate for deid report.
-- 2023-04-24 TG   - Adding Community Care Providers
-- =============================================
CREATE PROCEDURE [App].[ORM_PatientQuickView_LSV]
	-- Add the parameters for the stored procedure here
  
  @Prescriber nvarchar(max), --Team/Provider
  @Station varchar(255),
  @RiskGroup varchar(20),
  @Cohort varchar(10),
  @NoPHI varchar(10),
  @Measure varchar(max),
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
INNER JOIN (
	SELECT MVIPersonSID, MetricInclusion	
	FROM [ORM].[RiskMitigation] as b
	WHERE -5 IN (SELECT value FROM string_split(@Measure ,',')) 
		OR (
			-5 NOT IN (SELECT value FROM string_split(@Measure ,',')) 
			AND (Checked = 0 
				AND (@NoPHI = 0 AND MitigationID IN (SELECT value FROM string_split(@Measure ,',')))
				)		
			)
	) AS b ON s.MVIPersonSID = b.MVIPersonSID AND b.MetricInclusion = 1
INNER JOIN [Common].[MasterPatient] mp ON mp.MVIPersonSID=s.MVIPersonSID
;

INSERT INTO #cohort
SELECT PatientICN,MVIPersonSID,PatientSSN,RIGHT(4,PatientSSN),PatientName,SourceEHR='V'
FROM [Common].[MasterPatient]
WHERE PatientICN IN (
	'1013673699','1019376947'
	)
	AND @NoPHI = 1

SELECT DISTINCT	c.PatientICN
	,c.PatientName
	,c.PatientSSN
	,c.LastFour
	,c.SourceEHR
	,b.ChecklistID
	,b.Facility
    ,b.OUD
    ,b.OpioidForPain_Rx
    ,b.SUDdx_poss
	,b.ODPastYear
    ,b.Hospice
    ,b.PatientRecordFlag_Suicide
    ,b.RiosordScore
    ,b.RiosordRiskClass
    ,b.RiskCategory
    ,b.RiskCategoryLabel
    ,b.RiskScore
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
	--,b.BaselineMitigationsMet
	,b.NaloxoneDate
	,b.NaloxoneContext
	,b.SafetyPlanDate
	,b.SafetyPlanContext
	,b.ODdate
	,b.ODContext
	,b.PreparatoryBehavior
FROM  #Cohort as c
INNER JOIN [ORM].[PatientOTRRView] as b on c.MVIPersonSID = b.MVIPersonSID
WHERE @NoPHI = 1 
	OR (b.RiskCategory IN (SELECT value FROM string_split(@RiskGroup ,',')) 
		AND (
			(@Cohort=1 and b.OUD = 1) 
			OR (@Cohort=2 and b.OpioidForPain_Rx = 1) 
			OR (@Cohort=3 and b.OUD in (1,0)) 
			OR (@Cohort=4 and b.SUDdx_poss=1) 
			OR (@Cohort=5 and b.ODPastYear=1)
			)
		AND ChecklistID=@Station
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