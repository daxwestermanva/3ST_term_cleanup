


-- =============================================
-- Author:		Meenah Paik
-- Create date: 9/22/2021
-- Description: Main Dataset for PDSI Patient Report - replaces App.PDSI_PatientReport_LSV
-- Modifications: 
--		2022-05-17	MCP: Optimization changes (Andrey Isayenko recommendations)
--		2025-02-20	MCP: Adding VitalsDate

-- TESTING:
	/*
	EXEC [App].[PDSI_PatientReport_LSV]
		 @Provider	= '8279221'
		,@Station	= '640'
		,@NoPHI		= '1'
		,@Measure	= '1'
		,@User		= 'vha21\vhapalpaikm'
		,@GroupType = '2'
	*/
-- =============================================
CREATE PROCEDURE [App].[PDSI_PatientReport_LSV]
	-- Add the parameters for the stored procedure here
  
	 @Provider nvarchar(max)
	,@Station varchar(255)
	--,@Cohort varchar(10)
	,@NoPHI varchar(10)
	,@Measure varchar(max)
	,@User varchar(100)
	,@GroupType varchar(20)

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	--For inline testing only
	/*
	DECLARE @Provider NVARCHAR(MAX)
	DECLARE @Station varchar(255)
	DECLARE @NoPHI varchar(10)
	DECLARE @Measure varchar(max)
	DECLARE @User varchar(100)
	DECLARE @GroupType varchar(20)

	SET @Provider = '0'
	SET @Station = '640'
	SET @NoPHI = '0'
	SET @Measure = '1116,5119,5125,5154,5155,5156,5157,5158'
	SET @User = 'vha21\vhapalpaikm'
	SET @GroupType = -5
	*/

DROP TABLE IF EXISTS #Cohort;
SELECT DISTINCT st.MVIPersonSID
INTO  #Cohort
FROM (  -- Get all the patients the user is allowed to see
	SELECT MVIPersonSID
	FROM [PDSI].[PatientDetails]
	INNER JOIN (SELECT * FROM [App].[Access] (@User)) as f on f.Sta3n = left(Locations,3) 	
	WHERE Locations = @Station
	) as st
INNER JOIN ( -- then limit to the specific provider selected in the parameter
	SELECT MVIPersonSID
	FROM [PDSI].[PatientDetails]
	WHERE ( @GroupType = -5 --station level OR provider below
			OR (ProviderSID IN (SELECT value FROM string_split(@Provider ,',')) AND GroupID = @GroupType)  
			)
	) as prov on st.MVIPersonSID=prov.MVIPersonSID
INNER JOIN ( -- then limit to patients who are NOT MEETING the chosen measure(s)
	SELECT MVIPersonSID
	FROM [PDSI].[PatientDetails]
	WHERE ( --default is all possible measures from App.p_PDSI_Metrics
			(MeasureID IN (SELECT value FROM string_split(@Measure ,',')))
				AND MeasureUnmet = 1 
			)
	) AS m ON st.MVIPersonSID = m.MVIPersonSID 
WHERE @NoPHI = 0
;

--for De-ID
INSERT INTO #cohort
SELECT MVIPersonSID 
FROM [Common].[MasterPatient] 
WHERE PatientICN IN ( -- TEST PATIENTS
	'1011566187', '1015801211','1015811652','1011555358', '1011525934','1011547668','1018177176','1011494520','1017268821'
	) 
	AND @NoPHI = 1

--Add AUDIT-C score
DROP TABLE IF EXISTS #AUDC
SELECT
	 MVIPersonSID
	,cast(DetailsText as int) as AUDCScore
INTO #AUDC
FROM [PDSI].[PatientDetails] a
WHERE MeasureID = '5119' and DetailsText is not null and MeasureUnmet = 1

DROP TABLE IF EXISTS #PatientDetails
SELECT [MVIPersonSID],[Locations],[LocationName],[LocationsColor],[MeasureID],[Measure],[DetailsText],[DetailsDate]
	  ,[MeasureUnmet],[PTSD],[SUD],[MOUD_Key],[ALC_Top_Key],[PDMP],[NaloxoneKit],[UDS],[Age65_Eligible],[OpioidForPain_Rx]
	  ,[Benzodiazepine5],[Benzodiazepine5_Schedule],[DxId],[Diagnosis],[DxCategory],[Category],[MedID],[DrugName]
	  ,[PrescriberName],[MedType],[MedLocation],[MedLocationName],[MedLocationColor],[MonthsInTreatment],[GroupID]
	  ,[GroupType],[ProviderName],[ProviderSID],[ProviderLocation],[ProviderLocationName],[ProviderLocationColor]
	  ,[AppointmentID],[AppointmentType],[AppointmentStop],[AppointmentDatetime],[AppointmentLocation]
	  ,[AppointmentLocationName],[AppointmentLocationColor],[VisitStop],[VisitDatetime],[VisitLocation],[VisitLocationName]
	  ,[VisitLocationColor],[AUDActiveMostRecent],[OUDActiveMostRecent],[LastCBTSUD],[Vitals],[VitalsDate]
	  ,[MedIssueDate],[MedReleaseDate],[MedRxStatus],[MedDrugStatus],[StimulantADHD_rx]
INTO #PatientDetails
FROM [PDSI].[PatientDetails] t
WHERE MVIPersonSID IN (SELECT MVIPersonSID FROM #Cohort)

CREATE NONCLUSTERED INDEX NCIX_00
ON #PatientDetails ([MVIPersonSID])
INCLUDE (
	 [Locations],[LocationName],[LocationsColor],[MeasureID],[Measure],[DetailsText],[DetailsDate],[MeasureUnmet],[PTSD]
	,[SUD],[MOUD_Key],[ALC_Top_Key],[PDMP],[NaloxoneKit],[UDS],[Age65_Eligible],[OpioidForPain_Rx],[Benzodiazepine5]
	,[Benzodiazepine5_Schedule],[DxId],[Diagnosis],[DxCategory],[Category],[MedID],[DrugName],[PrescriberName],[MedType]
	,[MedLocation],[MedLocationName],[MedLocationColor],[MonthsInTreatment],[GroupID],[GroupType],[ProviderName]
	,[ProviderSID],[ProviderLocation],[ProviderLocationName],[ProviderLocationColor],[AppointmentID],[AppointmentType]
	,[AppointmentStop],[AppointmentDatetime],[AppointmentLocation],[AppointmentLocationName],[AppointmentLocationColor]
	,[VisitStop],[VisitDatetime],[VisitLocation],[VisitLocationName],[VisitLocationColor],[AUDActiveMostRecent]
	,[OUDActiveMostRecent],[LastCBTSUD],[Vitals],[VitalsDate],[MedIssueDate],[MedReleaseDate],[MedRxStatus],[MedDrugStatus],[StimulantADHD_rx])

DROP TABLE IF EXISTS #MasterPatient
SELECT
	[MVIPersonSID],[PatientName],[PatientSSN],[DateofBirth],[Age],[Gender],[LastFour],[StreetAddress1],[StreetAddress2]
	,[City],[State],[Zip],[PhoneNumber],[SourceEHR]
INTO #MasterPatient
FROM [Common].[MasterPatient] t
WHERE MVIPersonSID IN (SELECT MVIPersonSID FROM #Cohort)

CREATE CLUSTERED INDEX CIX ON #MasterPatient (MVIPersonSID)

SELECT DISTINCT	
      c.MVIPersonSID
	  ,PatientICN = NULL
	  ,b.[Locations]
      ,b.[LocationName]
      ,b.[LocationsColor]
      ,mp.[PatientName]
      ,mp.[PatientSSN]
      ,mp.[DateofBirth]
      ,mp.[Age]
      ,mp.[Gender]
      ,mp.[LastFour]
	  ,mp.[StreetAddress1]
	  ,mp.[StreetAddress2]
	  ,mp.[City]
	  ,mp.[State]
	  ,mp.[Zip]
	  ,mp.[PhoneNumber]
	  ,mp.[SourceEHR]
	  ,b.[MeasureID]
      ,b.[Measure]
      ,b.[DetailsText]
      ,b.[DetailsDate]
	  ,b.[MeasureUnmet]
	  ,b.[PTSD]
	  ,b.[SUD]
	  ,b.[MOUD_Key]
	  ,b.[ALC_Top_Key]
      ,b.[PDMP]
      ,b.[NaloxoneKit]
      ,b.[UDS]
      ,b.[Age65_Eligible]
      ,b.[OpioidForPain_Rx]
      ,b.[Benzodiazepine5]
      ,b.[Benzodiazepine5_Schedule]
      ,b.[DxId]
      ,b.[Diagnosis]
	  ,b.[DxCategory]
      ,b.[Category]
      ,b.[MedID]
	  ,b.[DrugName]
      ,b.[PrescriberName]
      ,b.[MedType]
      ,b.[MedLocation]
      ,b.[MedLocationName]
      ,b.[MedLocationColor]
      ,CASE WHEN b.MonthsinTreatment < 1 and MonthsinTreatment > 0 THEN '< 1' 
		ELSE convert(varchar,convert(decimal(8,0),MonthsinTreatment)) END MonthsinTreatment
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
	  ,CASE WHEN wb.ActionType IS NULL THEN 1 ELSE 2 END AS ReviewSort
	  ,ISNULL(wb.Patientreviewed,0) as PatientReviewed
	  ,wb.LastReviewDate
	  ,wb.UserID
	  ,wb.ActionType
	  ,wb.Comments
	  ,b.[AUDActiveMostRecent]
	  ,b.[OUDActiveMostRecent]
	  ,b.[LastCBTSUD]
	  ,b.[Vitals]
	  ,b.[VitalsDate]
	  ,b.[MedIssueDate]
	  ,b.[MedReleaseDate]
	  ,b.[MedRxStatus]
	  ,b.[MedDrugStatus]
	  ,b.[StimulantADHD_rx]
	  ,ac.[AUDCScore]
FROM  #Cohort as c
INNER JOIN #PatientDetails as b on c.MVIPersonSID = b.MVIPersonSID
INNER JOIN #MasterPatient  as mp on c.MVIPersonSID=mp.MVIPersonSID
LEFT JOIN #AUDC as ac on c.MVIPersonSID = ac.MVIPersonSID
LEFT OUTER JOIN (
	SELECT a.*
	FROM (
		SELECT Sta3n
			  ,MVIPersonSID
			  ,PatientReviewed
			  ,ExecutionDate
			  ,UserID
			  ,ActionType
			  ,Comments
			  ,MAX(ExecutionDate) OVER (PARTITION BY MVIPersonSID) as LastReviewDate
		FROM [PDSI].[Writeback]
		) AS a
	WHERE LastReviewDate = ExecutionDate -- only the most recent writeback record
	) AS wb ON c.MVIPersonSID = wb.MVIPersonSID
WHERE @NoPHI = 0

 
END