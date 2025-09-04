

-- =============================================
-- Author:		<Sara Tavakoli>
-- Description:	<Quick View Patient Summary - 1 row per patient>
-- Create date: <9/15/16>

	-- 2023-02-07	RAS	Commented out SP to resolve build warnings - delete after review.
	-- 2023-03-21	MCP revamped SP 
	-- 2024-06-10	MCP added stimrx details
	-- 2025-01-06	MCP updating with Phase 6 + adding mailing addresses
	-- 2025-02-04	MCP adding inpatient and outpatient stop code group types
	-- 2025-02-20	MCP adding UDS and Vitals dates
	-- 2025-04-21	MCP	adding AUDIT-C recent scores and dates and nolocks
/*
	EXEC [App].[PDSI_PatientQuickView_LSV]
		 @Provider	= '8279221'
		,@Station	= '640'
		,@NoPHI		= '1'
		,@Measure	= '1'
		,@User		= 'vha21\vhapalpaikm'
		,@GroupType = '2'
*/
-- =============================================
CREATE PROCEDURE [App].[PDSI_PatientQuickView_LSV]
	 @Provider nvarchar(max)
	,@Station varchar(255)
	,@NoPHI varchar(10)
	,@Measure varchar(max)
	,@User varchar(100)
	,@GroupType varchar(20)
AS
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	--DECLARE @Station varchar(255) =  '640'
	--DECLARE @User varchar(100) = 'vha21\vhapalpaikm'
	--DECLARE @NoPHI varchar(10) = '0'
	--DECLARE @Measure varchar(max) = '-5'
	--DECLARE @Provider varchar(max) = ''
	--DECLARE @GroupType varchar(20) = '6'

	--Set @Measure ='1116,5119,5125,5154,5155,5156,5157,5158,5161,5162,5163,5164' 


DROP TABLE IF EXISTS #cohort;
SELECT DISTINCT mp.PatientICN
	,s.MVIPersonSID
	,mp.PatientSSN
	,mp.DateOfBirth
	,mp.LastFour
	,mp.PatientName
	,mp.SourceEHR
	,mp.StreetAddress1
	,mp.StreetAddress2
	,mp.City
	,mp.State
	,mp.Zip
INTO  #cohort
FROM (  
	SELECT MVIPersonSID
		  ,Locations 
	FROM [PDSI].[PatientDetails] WITH (NOLOCK)
	WHERE Locations = @Station	
	) as s
INNER JOIN (SELECT Sta3n FROM [App].[Access] (@User)) as f on f.Sta3n = LEFT(Locations,3)
INNER JOIN (
	SELECT MVIPersonSID	
	FROM [PDSI].[PatientDetails] as b WITH (NOLOCK)
	WHERE -5 IN (SELECT value FROM string_split(@Measure ,',')) 
		OR (
			-5 NOT IN (SELECT value FROM string_split(@Measure ,',')) 
			AND (MeasureUnmet = 1
				AND (@NoPHI = 0 AND MeasureID IN (SELECT value FROM string_split(@Measure ,',')))
				)		
			)
	) AS b ON s.MVIPersonSID = b.MVIPersonSID 
INNER JOIN [Common].[MasterPatient] mp  WITH (NOLOCK) ON mp.MVIPersonSID=s.MVIPersonSID
;

INSERT INTO #cohort
SELECT PatientICN,MVIPersonSID,PatientSSN,DateOfBirth,RIGHT(4,PatientSSN),PatientName,SourceEHR='V',StreetAddress1
	,StreetAddress2
	,City
	,State
	,Zip
FROM [Common].[MasterPatient] WITH (NOLOCK)
WHERE PatientICN IN (
	'1013673699','1019376947'
	)
	AND @NoPHI = 1

--------------
--Add in patient reviewed and maybe relevant med?
SELECT DISTINCT	c.PatientICN
	,c.PatientName
	,c.PatientSSN
	,c.LastFour
	,c.DateOfBirth
	,c.SourceEHR
	,c.StreetAddress1
	,c.StreetAddress2
	,c.City
	,c.State
	,c.Zip
	,b.ChecklistID
	,b.Facility
	,b.SUD16
	,b.ALC_top1
	,b.GBENZO1
	,b.BENZO_Opioid_OP
	,b.BENZO_PTSD_OP
	,b.BENZO_SUD_OP
	,b.PDMP_Benzo
	,b.Naloxone_StimUD
	,b.STIMRX1
	,b.CoRx_RxStim
	,b.EBP_StimUD
	,b.Off_Label_RxStim
	,b.CLO1
	,b.APDEM1
	,b.APGLUC1
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
    ,b.PrescriberSID
    ,b.Prescriber
	,b.Outpat
	,b.Outpatsid
	,b.Inpat
	,b.Inpatsid
	,ISNULL(p.AUDActiveMostRecent,0) AS AUDActiveMostRecent
	,ISNULL(p.OUDActiveMostRecent,0) AS OUDActiveMostRecent
	,CASE WHEN wb.ActionType IS NULL THEN 1 ELSE 2 END AS ReviewSort
	,ISNULL(wb.Patientreviewed,0) AS PatientReviewed
	,wb.LastReviewDate
	,wb.UserID
	,wb.ActionType
	,wb.Comments
	,b.DrugName
	,b.PrescriberName
	,b.MedIssueDate
	,b.MedReleaseDate
	,b.MedRxStatus
	,b.MedDrugStatus
	,b.UDSDate
	,b.VitalsDate
	,b.AUDCScore
	,b.AUDCDate
FROM #Cohort as c
INNER JOIN [PDSI].[PatientQuickView] as b  WITH (NOLOCK) on c.MVIPersonSID = b.MVIPersonSID
LEFT OUTER JOIN [PDSI].[PatientDetails] as p  WITH (NOLOCK) on c.MVIPersonSID = p.MVIPersonSID
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
WHERE @NoPHI = 1 
	OR (ChecklistID=@Station
		AND (
			 (@GroupType=2 AND PCPSID  IN (SELECT value FROM string_split(@Provider ,','))	)
		  OR (@GroupType=4 AND PACTsid IN (SELECT value FROM string_split(@Provider ,','))	)
		  OR (@GroupType=5 AND MHTCsid IN (SELECT value FROM string_split(@Provider ,','))	)
		  OR (@GroupType=3 AND BHIPsid IN (SELECT value FROM string_split(@Provider ,','))	)
		  OR (@GroupType=1 AND PrescriberSID IN (SELECT value FROM string_split(@Provider ,','))	)
		  OR (@GroupType=6 AND Inpatsid IN (SELECT value FROM string_split(@Provider ,','))	)
		  OR (@GroupType=7 AND Outpatsid IN (SELECT value FROM string_split(@Provider ,','))	)
		  OR (@GroupType=-5)
			)	
		)
 			 
END