

/* =============================================
-- Author: Rebecca Stephens (RAS)		 
-- Create date: 2017-06-28
-- Description:	Main dataset for high risk patient tracking report
-- Modifications:
--	2020-09-16	LM	Pointed to _VM tables
--	2025-03-06	LM	Updates for caring letters and MHTC team
--Notes:
	--'VHA21\vhapalmacraf' --this person has only 640 acess

 EXEC [App].[PRF_HRS_Tracking] @User = 'VHA21\vhapalminal',@VISN=20,@Facility='668',@ProviderType='All SPCs/SPCMs',@LastActionType='1,2,4',@NoPHI=0
   ============================================= */

CREATE PROCEDURE [App].[PRF_HRS_Tracking]
   @User varchar(50)
	,@VISN varchar(12)
	,@Facility varchar(12)
	,@ProviderType varchar(max)
	,@LastActionType varchar(10)
	,@NoPHI bit

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--DECLARE @USER varchar(50), @VISN varchar(12), @Facility varchar(12), @ProviderType varchar(max),@LastActionType varchar(10), @NoPHI bit; 
--SET @User = 'vha21\vhapalminal'; SET @VISN='19'; SET @Facility='436'; SET @ProviderType ='All SPCs/SPCMs';SET @LastActionType='1,2,4'; SET @NoPHI=0

DECLARE @ProviderList TABLE ([AssignedSPC] VARCHAR(max))
INSERT @ProviderList  SELECT value FROM string_split(@ProviderType, ',')

DECLARE @ActionList TABLE ([LastActionType] VARCHAR(5))
INSERT @ActionList  SELECT value FROM string_split(@LastActionType, ',')
;
;
DROP TABLE IF EXISTS #HRF
SELECT hrf.MVIPersonSID
	  ,hrf.ActiveFlag
	  ,hrf.InitialActivation
	  ,hrf.LastActionDateTime
	  ,hrf.MostRecentActivation
	  ,ISNULL(hrf.MostRecentActivation,hrf.LastActionDateTime) AS ReferenceDateTime
	  ,hrf.OwnerChecklistID
	  ,hrf.LastActionType
	  ,hrf.LastActionDescription
	  ,hrf.IP_Current
	  ,hrf.IP_DateTime
	  ,hrf.IP_BedSection
	  ,hrf.IP_Location
	  ,CASE WHEN hrf.IP_Current=0 AND hrf.IP_DateTime >= DATEADD(d,-30,getdate()) THEN ISNULL(pde.NumberOfMentalHealthVisits,-1)
			ELSE NULL END AS PDEVisits
	  ,hrf.LastSafetyPlanDateTime
	  ,hrf.LastFlagReviewDateTime
	  ,hrf.SuicideBehaviorReport
	  ,CASE WHEN hrf.SuicideEventCount IS NULL THEN 0 ELSE hrf.SuicideEventCount END AS SuicideEventCount
	  ,hrf.CSRE
	  ,hrf.VisitsM1
	  ,hrf.VisitsM2
	  ,hrf.VisitsM3
	  ,hrf.SP_DateTime
	  ,hrf.SP_Met
	  ,hrf.SP_DayCountAbs
	  ,hrf.NextReviewDate
	  ,hrf.MinReviewDate
	  ,hrf.MaxReviewDate
	  ,hrf.AssignedSPC
	  ,hrf.LastVisitDateTime
	  ,hrf.LastVisitDetail
	  ,hrf.NextApptDateTime
	  ,hrf.LastNoShowDateTIme
	  ,hrf.CountNS30Days
	  ,hrf.FutureCancelDateTime
	  ,hrf.FutureCancelApptDateTime
	  ,hrf.UnsuccessDate
	  ,hrf.UnsuccessCount
	  ,hrf.SuccessDate
	  ,hrf.SuccessCount
	  ,CASE WHEN hrf.CaringLetters = 2 THEN 'National' 
		WHEN hrf.CaringLetters = 0 THEN 'No-Removed/Opted Out'
		ELSE 'N/A' END AS CaringLetters
	  ,CASE WHEN SP2ConsultActionable=1 THEN CONCAT('Eligible: SSDV on ',CONVERT(varchar,hrf.SP2EligibleDate,101))
		WHEN hrf.SP2ConsultActionable=0 THEN CONCAT('Most recent consult on ',CONVERT(varchar,hrf.SP2ConsultRequestDate,101))
		ELSE NULL END AS SP2
	  ,hrf.StaffName_PCP
	  ,hrf.CountPCP
	  ,hrf.Sta6a_PCP
	  ,hrf.StaffName_MHTC
	  ,hrf.CountMHTC
	  ,hrf.Sta6a_MHTC
	  ,hrf.Team_MHTC
	  ,ad.StreetAddress1
	  ,ad.StreetAddress2
	  ,ad.StreetAddress3
	  ,ad.City
	  ,ad.State
	  ,ad.Zip
	  ,ad.Country
	  ,CASE WHEN ad.TempAddress=1 THEN 'Yes' ELSE 'No' END AS TempAddress
	  ,cm.PhoneNumber AS HomePhone
	  ,cm.CellPhoneNumber AS CellPhone
	  ,hrf.UpdateDate
	  ,cm.PatientICN
	  ,cm.PatientName
	  ,cm.PreferredName
	  ,cm.FirstName
	  ,cm.LastName
	  ,cm.PatientSSN
	  ,cm.LastFour as Last4
	  ,cm.DateOfBirth
	  ,cm.Age
	  ,cm.DisplayGender
	  ,cm.Homeless
	  ,ReachStatus=CASE WHEN r.Top01Percent=1 THEN 1
			WHEN r.MVIPersonSID IS NOT NULL THEN 2
			ELSE 0 END
	  ,cs.Status1 AS CommunityStatus1
	  ,cs.Status2 AS CommunityStatus2
	  ,cs.Comments AS CS_Comments
	  ,cs.HealthFactorDateTime AS CS_HealthFactorDateTime
	  ,cs.ChecklistID AS CS_ChecklistID
	  ,CASE WHEN hrf.DateOfDeath IS NOT NULL THEN 1 ELSE 0 END AS Deceased
	  ,CASE WHEN CAST(getdate() AS date) BETWEEN e.EpisodeBeginDate AND e.EpisodeEndDate THEN 1 ELSE 0 END AS ActiveCOMPACTEpisode
	  ,CASE WHEN CAST(getdate() AS date) BETWEEN e.EpisodeBeginDate AND e.EpisodeEndDate THEN e.EpisodeEndDate ELSE NULL END AS COMPACTEndDate
	  ,hrf.DateOfDeath
	  ,hrf.CernerVistADiff
	  ,CASE WHEN o.MVIPersonSID IS NULL AND v.MVIPersonSID IS NULL THEN 2 ELSE 1 END AS AnyVisits
	  ,CASE WHEN v.MVIPersonSID IS NULL THEN 2 ELSE 1 END AS PossMissingCernerVisits
	  ,CASE WHEN cm.SourceEHR LIKE '%M%' THEN 'C' ELSE NULL END AS SourceEHR
INTO #HRF
FROM [PRF_HRS].[PatientReport_v02] as hrf WITH(NOLOCK)
INNER JOIN [Common].[MasterPatient] cm WITH(NOLOCK) on 
	cm.MVIPersonSID=hrf.MVIPersonSID 
INNER JOIN (SELECT Sta3n from [App].[Access] (@User)) as Access on LEFT(hrf.OwnerChecklistID,3) = Access.sta3n
INNER JOIN [PRF_HRS].[PatientAddress] as ad WITH(NOLOCK) ON hrf.MVIPersonSID=ad.MVIPersonSID
LEFT JOIN [PRF_HRS].[OutpatDetail] AS o WITH (NOLOCK)
	ON o.MVIPersonSID = hrf.MVIPersonSID
LEFT JOIN [OracleH_QI].[PossibleMHVisits] v WITH (NOLOCK)
	ON hrf.MVIPersonSID = v.MVIPersonSID
LEFT JOIN [REACH].[PatientReport] r WITH(NOLOCK) on r.MVIPersonSID=hrf.MVIPersonSID
LEFT JOIN [PDE_Daily].[PDE_PatientLevel] as pde WITH(NOLOCK) on 
	hrf.MVIPersonSID=pde.MVIPersonSID 
	AND hrf.IP_DateTime=pde.DischargeDateTime
LEFT JOIN (
	SELECT MVIPersonSID,Status1,Status2,Comments,HealthFactorDateTime,ChecklistID 
	FROM [Present].[CommunityStatusNote] WITH(NOLOCK)
	WHERE PastThreeMonths=1 
		AND MostRecent=1
	) cs on hrf.MVIPersonSID=cs.MVIPersonSID
LEFT JOIN (SELECT * FROM [COMPACT].[Episodes] WITH (NOLOCK) WHERE EpisodeRankDesc = 1) e ON hrf.MVIPersonSID = e.MVIPersonSID
INNER JOIN @ProviderList spc ON spc.AssignedSPC = hrf.AssignedSPC OR spc.AssignedSPC = 'All SPCs/SPCMs'
INNER JOIN @ActionList act ON act.LastActionType = hrf.LastActionType
WHERE hrf.OwnerChecklistID=@Facility

--for de-identified report
UPDATE #HRF 
SET StreetAddress1 = '17 Cherry Tree Lane'
	,StreetAddress2 = NULL
	,StreetAddress3 = NULL
	,City = 'London'
	,State = 'UK'
	,Zip = '99999'
	,Country = NULL
	,PatientICN = '1' --prevent click through to other reports
	,PatientName = 'Name, Patient'
	,FirstName = 'FirstName'
	,LastName = 'LastName'
	,PatientSSN = '999-99-9999'
	,Last4 = '9999'
	,DateOfBirth = '1900-01-01'
	,HomePhone = '999-999-9999'
	,CellPhone = '999-999-9999'
	,Age = 100
	,DateOfDeath = '1900-01-01'
WHERE @NoPHI=1


;
SELECT DISTINCT a.*
FROM #HRF a

;

END