
-- =============================================
-- Author:		Amy Robinson/Meenah Paik
-- Create date: 6/19/2017
-- Description: Combine patient report and patient report_allgroups
-- 01/09/18 SM added parameter for randomization by ChecklistID parameter (Station)
-- 01/14/19  removed randomization parameter, no longer needed.
-- 10/15/20 LM - Added SourceEHR to indicate potential Cerner data
-- 2021-12-15 - TG Added the new Overdose in the past year cohort for STORM update
-- 2021-01-28 - RAS - Changed old DWS join to Common object for deidentified patient list.
-- 2022-02-04 - TG - changing back to PDW reference until Rebecca finishes work on de-identified records
-- 2023-09-14 - CW - adding inpatient information
-- 2024-04-02 - CW - Adding concatenated EntryDateTime for use where Overdose Event is not null. The field has asked 
--					 for the date of event as well as date of report.
-- 2024-12-02 - TG - Adding LTOT cohort to patient report.
-- 2025-01-10 - TG - Implementing PMOP changes to risk mitigations
-- 2025-02-03 - TG - Adding MetricInclusion to the dataset to highlight the mandated risk mitigations
-- 2025-02-06 - TG - handling NULL values for MetricInclusion
-- 2025-04-24 - TG - Adding unexpected drug screen results to facility patient reports.
-- 2025-05-21 - TG - Adding nonVA cannabis and xylazine exposure
-- 2025-06-23 - TG - Adding NLP Concept to link to snippet report
-- =============================================
CREATE PROCEDURE [App].[ORM_PatientReport_LSV]
  
	 @Prescriber nvarchar(max)
	,@Station varchar(255)
	,@RiskGroup varchar(125)
	,@Cohort varchar(10)
	,@NoPHI varchar(10)
	,@Measure varchar(max)
	,@User varchar(100)
	,@GroupType varchar(100)

AS
BEGIN
	SET NOCOUNT ON;


	--For inline testing only
	--DECLARE @Prescriber NVARCHAR(MAX), @Station varchar(255),@RiskGroup varchar(20),@Cohort varchar(10),@NoPHI varchar(10),@Measure varchar(max),@User varchar(100),@GroupType varchar(20); SET @Prescriber = '0';  SET @Station = '570'; SET @RiskGroup = '4'; SET @Cohort = '2';SET  @NoPHI = '0'; SET @Measure = '12'; SET @User = 'vha21\vhapalmartins';  SET @GroupType = '-5'


	DROP TABLE IF EXISTS #cohort;
	SELECT DISTINCT mp.PatientICN, a.MVIPersonSID  
	INTO  #cohort
	FROM (  
		SELECT MVIPersonSID
			  ,Locations 
		FROM [ORM].[PatientDetails] WITH(NOLOCK)
		INNER JOIN (SELECT Sta3n FROM [App].[Access] (@User)) as f on f.Sta3n = left(Locations,3) 	
		WHERE Locations = @Station	
		) as s
	INNER JOIN (
		SELECT MVIPersonSID
		FROM [ORM].[PatientDetails] WITH(NOLOCK)
		WHERE (@NoPHI = 0 
			AND (
				(ProviderSID in (SELECT value FROM string_split(@Prescriber ,',')) and GroupID = @GroupType) 
				OR @GroupType = -5
				) 
			)
		) as a on s.MVIPersonSID=a.MVIPersonSID
	INNER JOIN (
		SELECT MVIPersonSID	
		FROM [ORM].[RiskMitigation] WITH(NOLOCK)
		WHERE -5  IN (SELECT value FROM string_split(@Measure ,',')) 
			OR (
				-5 NOT IN (SELECT value FROM string_split(@Measure ,',')) 
				AND (
					Checked = 0 
					AND (@NoPHI = 0 AND MitigationID IN (SELECT value FROM string_split(@Measure ,',')))
					AND MetricInclusion = 1 
					)
				)
		) AS b ON a.MVIPersonSID = b.MVIPersonSID 
	INNER JOIN [Common].[MasterPatient] mp WITH(NOLOCK) ON mp.MVIPersonSID=s.MVIPersonSID
	;

	INSERT INTO #cohort
	SELECT PatientICN,MVIPersonSID 
	FROM [Common].[MasterPatient] WITH(NOLOCK)
	WHERE PatientICN IN (
		'1011566187', '1015801211','1015811652','1011555358', '1011525934','1011547668','1018177176','1011494520','1017268821'
		)
		AND @NoPHI = 1

	SELECT DISTINCT	
		   mp.[PatientICN]
		  ,b.[Locations]
		  ,b.[LocationName]
		  ,b.[LocationsColor]
		  ,mp.[PatientName]
		  ,mp.[PatientSSN]
		  ,mp.[DateofBirth]
		  ,mp.[Age]
		  ,mp.[Gender]
		  ,mp.[LastFour]
		  ,mp.StreetAddress1
		  ,mp.StreetAddress2
		  ,mp.City
		  ,mp.State
		  ,mp.Zip
		  ,b.[OUD]
		  ,b.[OpioidForPain_Rx]
		  ,b.[SUDdx_poss]
		  ,b.[Hospice]
		  ,b.ODPastYear
		  ,b.ChronicOpioid
		  ,b.[RiskCategory]
		  ,b.[RiskCategorylabel]
		  ,b.[RiskAnyCategory]
		  ,b.[RiskAnyCategorylabel]
		  ,b.[RiskScore]
		  ,b.[RiskScoreAny]
		  ,b.[RiskScoreAnyOpioidSedImpact]
		  ,b.[RiskScoreOpioidSedImpact]
		  ,b.[RM_ActiveTherapies_Key]
		  ,b.[RM_ActiveTherapies_Date]
		  ,b.[RM_ChiropracticCare_Key]
		  ,b.[RM_ChiropracticCare_Date]
		  ,b.[RM_OccupationalTherapy_Key]
		  ,b.[RM_OccupationalTherapy_Date]
		  ,b.[RM_OtherTherapy_Key]
		  ,b.[RM_OtherTherapy_Date]
		  ,b.[RM_PhysicalTherapy_Key]
		  ,b.[RM_PhysicalTherapy_Date]
		  ,b.[RM_SpecialtyTherapy_Key]
		  ,b.[RM_SpecialtyTherapy_Date]
		  ,b.[RM_PainClinic_Key]
		  ,b.[RM_PainClinic_Date]
		  ,b.[CAM_Key]
		  ,b.[CAM_Date]
		  ,b.[riosordscore]
		  ,b.[riosordriskclass]
		  ,b.[RiskMitScore]
		  ,b.[MaxMitigations]
		  ,b.[PatientRecordFlag_Suicide]
		  ,b.[REACH_01]
		  ,b.[REACH_Past]
		  ,b.[MitigationID]
		  ,[RiskMitigation]=CASE WHEN b.[RiskMitigation] LIKE 'MEDD%' THEN CONCAT(b.[RiskMitigation],' (30 Day Avg)') ELSE b.[RiskMitigation] END
		  ,b.[DetailsText]
		  ,b.[DetailsDate]
		  ,b.[Checked]
		  ,b.[Red]
		  ,b.[MitigationIDRx]
          ,b.[PrintNameRx]
          ,b.[CheckedRx]
		  ,ISNULL(b.MetricInclusion,0) AS MetricInclusion
          ,b.[RedRx]
		  ,b.[DxId]
		  ,b.[Diagnosis]
		  ,b.[ColumnName]
		  ,b.[Category]
		  ,b.[MedID]
		  ,b.[DrugNameWithoutDose]
		  ,b.[PrescriberName]
		  ,b.[MedType]
		  ,b.CHOICE
		  ,b.[MedLocation]
		  ,b.[MedLocationName]
		  ,b.[MedLocationColor]
		  ,Case when MonthsinTreatment < 1 and MonthsinTreatment > 0 then '< 1' 
			else convert(varchar,convert(decimal(8,0),MonthsinTreatment)) end MonthsinTreatment
		  ,b.[GroupID]
		  ,b.[GroupType]
		  ,b.[ProviderName]
		  ,b.[ProviderSID]
		  ,b.[ProviderLocation]
		  ,b.[ProviderLocationName]
		  ,b.[ProviderLocationColor]
		  ,b.[AppointmentID]
		  ,b.[AppointmentType]
		  ,b.[AppointmentStop]
		  ,b.[AppointmentDatetime]
		  ,b.[AppointmentLocation]
		  ,b.[AppointmentLocationName]
		  ,b.[AppointmentLocationColor]
		  ,b.[VisitStop]
		  ,b.[VisitDatetime]
		  ,b.[VisitLocation]
		  ,b.[VisitLocationName]
		  ,b.[VisitLocationColor]
		  ,b.ReceivingCommunityCare
		  ,b.ActiveMOUD_Patient
		  ,b.NonVA_Meds
		  --,b.BaselineMitigationsMet
		  ,mp.SourceEHR
		  ,Census=ISNULL(i.Census,0)
		  ,InpatientFacility=CASE WHEN i.Census=1 THEN i.Facility ELSE NULL END
		  ,CASE WHEN b.DetailsText='Overdose Event On'
			    THEN CONCAT('Overdose Reported On ',FORMAT(sp.EntryDateTime,'M/d/yyyy'))
			    ELSE NULL END AS OverdoseReportDetails
          ,b.Details
		  ,b.NonVACannabis
		  ,b.XylazineExposure
		  ,b.Concept
	FROM  #Cohort as c
	INNER JOIN [ORM].[PatientDetails] as b WITH(NOLOCK)
		ON c.MVIPersonSID = b.MVIPersonSID
	INNER JOIN [Common].[MasterPatient] as mp WITH(NOLOCK)
		ON c.MVIPersonSID=mp.MVIPersonSID
	LEFT JOIN (SELECT MVIPersonSID,c.Facility,Census=MAX(Census) FROM Inpatient.BedSection b WITH(NOLOCK) 
			   INNER JOIN LookUp.ChecklistID c WITH(NOLOCK) ON b.ChecklistID=c.ChecklistID
			   GROUP BY MVIPersonSID,c.Facility) i 
		ON mp.MVIPersonSID=i.MVIPersonSID
	LEFT JOIN OMHSP_Standard.SuicideOverdoseEvent sp WITH (NOLOCK)
		ON b.MVIPersonSID=sp.MVIPersonSID 
		AND CAST(b.DetailsDate as DATE)=CAST(ISNULL(sp.EventDateFormatted,sp.EntryDateTime) as date) 
		AND Overdose=1
	WHERE @NoPHI = 1 
		OR (b.RiskCategory IN (SELECT value FROM string_split(@RiskGroup ,',')) 
			AND (
				(@Cohort=3) -- All patients in table 			
				OR (@Cohort = 1 and OUD = 1) 
				OR (@Cohort = 2 and OpioidForPain_Rx = 1) 
				OR (@Cohort = 4 and SUDdx_poss=1) 
				OR (@Cohort = 5 and ReceivingCommunityCare=1) 
				OR (@Cohort = 6 and ActiveMOUD_Patient = 0)
				OR (@Cohort = 7 and ODPastYear = 1)
				OR (@Cohort = 8 and ChronicOpioid = 1)
			)
		)

END