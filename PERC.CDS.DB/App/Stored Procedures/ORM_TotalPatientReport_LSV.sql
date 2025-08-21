
/*-- =============================================
-- Author:		Tolessa Gurmessa
-- Create date: 7/11/2024
-- Code borrowed from [App].[ORM_PatientReport_LSV]
-- Description: This sp is created to feed a drill through report from the Summary Report, because PatientReport pulled unmet measures.
                By changing the cohort to MetricInclusion = 1, instead of checked = 0, we are pulling total patients for a measure of interest

-- =============================================*/
CREATE PROCEDURE [App].[ORM_TotalPatientReport_LSV]
  
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
					MetricInclusion = 1
					AND (@NoPHI = 0 AND MitigationID IN (SELECT value FROM string_split(@Measure ,',')))
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
			)
		)

END