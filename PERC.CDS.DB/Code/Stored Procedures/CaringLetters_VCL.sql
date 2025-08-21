

/*=============================================
-- Author:		Liam Mina
-- Create date: 3/7/2024
-- Description:	VCL caring letters sends mailings to patients who have called VCL
-- Updates:
--	2024-08-15	LM	Update to run in PostPDW on Monday mornings to align with historic process
--	2024-09-05	LM	Additional formatting for mailing address
--	2024-10-03	LM	Remove international addresses
--  2024-10-08	LM	Add flag for potential duplicate ICN matches
--	2024-11-07	LM	Add additional eligibility statuses as exclusion criteria for enrollment
--	2024-11-25	LM	Only flag duplicate matches the first time they are identified as a duplicate
--	2025-01-29	LM	Exclude callers marked as active duty by VCL if they also have a service separation date in CDW; re-prioritize address data based on feedback from CL team
--	2025-03-13	LM	Consolidate HRF and VCL mailing list code
--	2025-04-28	LM	Point to new Medoraforce tables
--	2025-07-08	LM	Remove references to pre-Medoraforce tables
--	2025-07-11	LM	Moved patient mapping code to a different procedure so it can be used by another project as well

=========================================================================================================================================*/
CREATE PROCEDURE [Code].[CaringLetters_VCL]


AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.CaringLetters_VCL', @Description = 'Execution of Code.CaringLetters_VCL SP'


DROP TABLE IF EXISTS #Today
SELECT CAST(GETDATE() AS DATE) AS Today
INTO #Today


BEGIN

--Get week dates for previous week Saturday-Friday
DROP TABLE IF EXISTS #WeekEpisodes
SELECT TOP 1
	CAST(DateAdd(day,-6,Date) AS date) AS WeekBegin
	,CAST(Date AS date) AS WeekEnd
	,CAST(DateAdd(day,3,Date) AS date) AS MailingDate
	,CAST(DateAdd(day,10,Date) AS date) AS NextMailingDate
INTO #WeekEpisodes
FROM [Dim].[Date] WITH (NOLOCK)
WHERE DayOfWeek=6 --Friday - week end
AND Date < (SELECT * FROM #Today) 
ORDER BY Date DESC

--Find existing data for release date(s) of interest
DROP TABLE IF EXISTS #existingdata
SELECT TOP 1 a.InsertDate
INTO #existingdata
FROM [CaringLetters].[VCL_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b on 
	a.InsertDate > b.WeekEnd
ORDER BY a.InsertDate DESC

IF EXISTS (SELECT * FROM #existingdata)
BEGIN

	DECLARE @msg0 varchar(250) = 'Data for this period already exists in VCL.CaringLettersCohort.'
	PRINT @msg0
	
	EXEC [Log].[Message] 'Information','Update not completed'
		,@msg0

	EXEC [Log].[ExecutionEnd] 
	EXEC [Log].[ExecutionEnd] @Status='Error' 
	
	RETURN
END

DROP TABLE IF EXISTS #VCLHotlineCalls
SELECT h.PatientICN
	  ,h.ICNSource
	  ,h.vcl_ID
	  ,h.VCL_Call_Date
      ,h.VCL_NearestFacilitySiteCode
      ,h.VCL_IsVet
      ,h.VCL_IsActiveDuty
	  ,h.VCL_VeteranStatus
      ,h.VCL_MilitaryBranch
	 ,ROW_NUMBER() OVER (PARTITION BY h.MVIPersonSID ORDER BY VCL_Call_Date) AS RN
INTO #VCLHotlineCalls
FROM [CaringLetters].[VCL_PatientMapping] h WITH (NOLOCK)
WHERE h.CaringLetterEligible=1

DELETE FROM #VCLHotlineCalls 
WHERE RN>1

--Stop code from running if missing data for new enrolled patients 
DECLARE @NewThreshold INT = 1000
DECLARE @NewCount BIGINT = (SELECT COUNT(*) FROM #VCLHotlineCalls a WITH (NOLOCK) 
							INNER JOIN #WeekEpisodes b on a.VCL_Call_Date>b.WeekBegin WHERE a.PatientICN IS NOT NULL) --Check for non-null ICNs to ensure that ID to ICN mapping has run successfully first
IF 	@NewCount  < @NewThreshold
BEGIN

DECLARE @msg1 varchar(500)= 'Row count insufficient to proceed with Code.VCL_CaringLetters'
	PRINT @msg1
	
	EXEC [Log].[Message] 'Error','Row Counts',@msg1
	EXEC [Log].[ExecutionEnd] @Status='Error' --Log end in case of error

	PRINT @Msg1;
	THROW 51000,@Msg1,1

END

--Get history of HRF and VCL caring letters to exclude repeats
DROP TABLE IF EXISTS #History
SELECT TOP 1 WITH TIES
	MVIPersonSID
	,EligibleDate
	,Program
	,EverEnrolled
	,DoNotSend_Date
	,DoNotSend_Reason
INTO #History
FROM [Present].[CaringLetters]  WITH (NOLOCK)
WHERE (DoNotSend_Reason IS NULL OR DoNotSend_Reason<>'Reactivated')
ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY EligibleDate)

--Check for VCL pre-emptive opt outs - these are deceased patients that VCL has identified who should never be enrolled in caring letters
DROP TABLE IF EXISTS #PreEmptiveOptOut
SELECT b.PatientICN, a.DateAdded
INTO #PreEmptiveOptOut
FROM [CaringLetters].[VCL_PreEmptiveOptOuts] a WITH (NOLOCK)
INNER JOIN [Common].[MasterPatient] b WITH (NOLOCK)
	ON a.SSN = b.PatientSSN AND a.LastName = b.LastName AND a.FirstName = b.FirstName

--Get patients with newly inactivated flags who should begin receiving caring letters this week
DROP TABLE IF EXISTS #Cohort
SELECT DISTINCT b.MVIPersonSID
	,b.PatientICN
	,a.ICNSource
	,a.VCL_ID
	,CAST(a.VCL_Call_Date AS date) AS VCL_Call_Date
	,a.VCL_NearestFacilitySiteCode
	,a.VCL_IsVet
	,a.VCL_IsActiveDuty
	,a.VCL_VeteranStatus
	,a.VCL_MilitaryBranch
	,MIN(COALESCE(b.DateOfDeath_Combined
		,p.DateAdded
		,d.EligibleDate --previous date of enrollment in CL
		--,v.VCL_Call_Date --remove at go-live; here for testing
		,CASE WHEN c.StreetAddress1 IS NULL AND c.MailStreetAddress1 IS NULL AND c.TempStreetAddress1 IS NULL THEN getdate() END
		,CASE WHEN a.VCL_IsActiveDuty='True' AND b.ServiceSeparationDate>a.VCL_Call_Date THEN getdate() END
			)) OVER (PARTITION BY b.MVIPersonSID) AS DoNotSendDate
	,CASE WHEN b.DateOfDeath_Combined IS NOT NULL OR d.DoNotSend_Reason LIKE '%Deceased' OR p.PatientICN IS NOT NULL THEN 'Deceased'
		WHEN d.MVIPersonSID IS NOT NULL AND d.Program='VCL Caring Letters' AND EverEnrolled=1 THEN 'Previously Enrolled in VCL CL' --Exclude patients who have received VCL CL
		WHEN v.MVIPersonSID IS NOT NULL THEN 'Previously Enrolled in VCL CL' 
		WHEN d.MVIPersonSID IS NOT NULL AND d.Program='HRF Caring Letters' AND EverEnrolled=1 THEN 'Previously Enrolled in HRF CL' --Exclude patients who have received VCL CL
		WHEN (c.StreetAddress1 IS NULL AND c.MailStreetAddress1 IS NULL AND c.TempStreetAddress1 IS NULL) OR d.DoNotSend_Reason IN ('Bad Address','Unable to receive mail') THEN 'Bad Address' --new enrollments that have no CDW address
		WHEN d.DoNotSend_Reason LIKE 'Ineligible%' 
			OR (a.VCL_IsActiveDuty='True' AND b.ServiceSeparationDate>a.VCL_Call_Date) THEN 'Ineligible for VA Care'
		WHEN d.DoNotSend_Reason LIKE '%opted out' THEN 'Opted Out'
		ELSE d.DoNotSend_Reason
		END AS DoNotSendReason
	,InsertDate = CAST(getdate() AS date)
INTO #Cohort
FROM #VCLHotlineCalls a
INNER JOIN [Common].[MasterPatient] b WITH (NOLOCK)
	ON a.PatientICN=b.PatientICN
LEFT JOIN [Common].[MasterPatient_Contact] c WITH (NOLOCK)
	ON b.MVIPersonSID=c.MVIPersonSID
LEFT JOIN #History d WITH (NOLOCK) 
	ON b.MVIPersonSID = d.MVIPersonSID
LEFT JOIN [CaringLetters].[VCL_Cohort] v WITH (NOLOCK) 
	ON b.MVIPersonSID = v.MVIPersonSID
LEFT JOIN #PreEmptiveOptOut p
	ON a.PatientICN = p.PatientICN
WHERE v.MVIPersonSID IS NULL


--Add dates of letters 
DROP TABLE IF EXISTS #LetterDates
SELECT TOP 1
	CAST(a.date as date) AS FirstLetterDate
	,CAST(DateAdd(month,1,a.date) as date) AS SecondLetterDate -- one month
	,CAST(DateAdd(month,2,a.date) as date) AS ThirdLetterDate -- two months
	,CAST(DateAdd(month,3,a.date) as date) AS FourthLetterDate -- three months
	,CAST(DateAdd(month,5,a.date) as date) AS FifthLetterDate -- six months
	,CAST(DateAdd(month,7,a.date) as date) AS SixthLetterDate -- eight months
	,CAST(DateAdd(month,9,a.date) as date) AS SeventhLetterDate -- ten months
	,CAST(DateAdd(month,11,a.date) as date) AS EighthLetterDate -- twelve months
INTO #LetterDates
FROM [Dim].[Date] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b ON a.Date>b.WeekEnd
WHERE DayOfWeek=2 --lists for mailings are pulled on Mondays
ORDER BY ROW_NUMBER() OVER (PARTITION BY DayOfWeek ORDER BY a.Date)

DROP TABLE IF EXISTS #AddLetterDates
SELECT a.VCL_ID
	,a.MVIPersonSID
	,a.PatientICN
	,a.ICNSource
	,a.VCL_NearestFacilitySiteCode
	,a.VCL_IsVet
	,a.VCL_IsActiveDuty
	,a.VCL_VeteranStatus
	,a.VCL_MilitaryBranch
	,a.VCL_Call_Date
	,CASE WHEN a.DoNotSendDate IS NOT NULL THEN 1 ELSE 0 END AS DoNotSend
	,a.DoNotSendDate
	,a.DoNotSendReason
	,b.FirstLetterDate
	,b.SecondLetterDate
	,b.ThirdLetterDate
	,b.FourthLetterDate
	,b.FifthLetterDate
	,b.SixthLetterDate
	,b.SeventhLetterDate
	,b.EighthLetterDate
	,LetterFrom = CASE WHEN b.FirstLetterDate IS NOT NULL THEN 'Peer' ELSE NULL END --after PERC starts running this data, all new patients will get Peer letter. Historic patients were randomized to Peer or Provider
	,a.InsertDate
INTO #AddLetterDates
FROM #Cohort a
LEFT JOIN #LetterDates b ON b.FirstLetterDate >= a.VCL_Call_Date AND a.DoNotSendDate IS NULL

INSERT INTO [CaringLetters].[VCL_Cohort] (
	VCL_ID
	,MVIPersonSID
	,PatientICN
	,ICNSource
	,VCL_NearestFacilitySiteCode
	,VCL_IsVet
	,VCL_IsActiveDuty
	,VCL_VeteranStatus
	,VCL_MilitaryBranch
	,VCL_Call_Date
	,DoNotSend
	,DoNotSendDate
	,DoNotSendReason
	,FirstLetterDate
	,SecondLetterDate
	,ThirdLetterDate
	,FourthLetterDate
	,FifthLetterDate
	,SixthLetterDate
	,SeventhLetterDate
	,EighthLetterDate
	,LetterFrom
	,InsertDate
	)
SELECT DISTINCT
	VCL_ID
	,MVIPersonSID
	,PatientICN
	,ICNSource
	,VCL_NearestFacilitySiteCode
	,VCL_IsVet
	,VCL_IsActiveDuty
	,VCL_VeteranStatus
	,VCL_MilitaryBranch
	,VCL_Call_Date
	,DoNotSend
	,DoNotSendDate
	,DoNotSendReason
	,FirstLetterDate
	,SecondLetterDate
	,ThirdLetterDate
	,FourthLetterDate
	,FifthLetterDate
	,SixthLetterDate
	,SeventhLetterDate
	,EighthLetterDate
	,LetterFrom
	,InsertDate
FROM #AddLetterDates

----Update with opt-outs since the last run
----Writebacks
UPDATE [CaringLetters].[VCL_Cohort]
SET DoNotSend = o.DoNotSend
	,DoNotSendDate = o.InsertDate
	,DoNotSendReason = o.DoNotSendReason
FROM (SELECT * FROM [CaringLetters].[VCL_Mailings] WITH (NOLOCK) WHERE DoNotSend=1 AND ActiveRecord=1) o
INNER JOIN [CaringLetters].[VCL_Cohort] AS c WITH (NOLOCK)
	ON o.MVIPersonSID = c.MVIPersonSID AND o.VCL_ID=c.VCL_ID
	AND c.DoNotSend = 0

----Update with deaths since last run
UPDATE [CaringLetters].[VCL_Cohort]
SET DoNotSend = 1
	,DoNotSendDate = (SELECT * FROM #Today)
	,DoNotSendReason = 'Deceased'
FROM [Common].[MasterPatient] o WITH (NOLOCK)
INNER JOIN [CaringLetters].[VCL_Cohort] AS c WITH (NOLOCK)
	ON o.MVIPersonSID = c.MVIPersonSID 
	AND o.DateOfDeath_Combined IS NOT NULL
	AND c.DoNotSend = 0

UPDATE [CaringLetters].[VCL_Cohort]
SET DoNotSend = 1
	,DoNotSendDate = DateAdded
	,DoNotSendReason = 'Deceased'
FROM #PreEmptiveOptOut o
INNER JOIN [CaringLetters].[VCL_Cohort] AS c 
	ON o.PatientICN = c.PatientICN
	AND c.DoNotSend = 0


----Update with bad addresses from NCOA. Bad addresses will be sent weekly from NCOA and imported into [VCL].NCOA_BadAddress; these patients should be removed from future mailings
UPDATE [CaringLetters].[VCL_Cohort]
SET DoNotSend = 1
	,DoNotSendDate = (SELECT * FROM #Today)
	,DoNotSendReason = 'Bad Address'
FROM [CaringLetters].[VCL_Cohort] AS c 
INNER JOIN [CaringLetters].[VCL_NCOA_BadAddress] AS ad 
	ON ad.VCL_ID = c.VCL_ID 
	AND c.DoNotSend = 0


--Remove patients who are not eligible for any VA care (e.g., humanitarian emergency)
DROP TABLE IF EXISTS #PossIneligible
SELECT c.MVIPersonSID, m.PatientICN, s.PatientPersonSID
INTO #PossIneligible
FROM [CaringLetters].[VCL_Cohort] c
INNER JOIN [Common].[MasterPatient] m WITH (NOLOCK)
	ON c.MVIPersonSID = m.MVIPersonSID
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] s WITH (NOLOCK)
	ON c.MVIPersonSID=s.MVIPersonSID
WHERE c.DoNotSend=0 AND m.PriorityGroup=-1 AND m.COMPACTEligible=0
AND c.EighthLetterDate >= getdate()

--List of ineligible statuses decided by VCL CL stakeholders on 10/31/2024
DROP TABLE IF EXISTS #Eligibility
SELECT MVIPersonSID, EligibilitySum INTO #Eligibility FROM (
	SELECT DISTINCT b.MVIPersonSID
		,SUM(CASE WHEN Eligibility in ('ACTIVE DUTY'
			,'CHAMPVA'
			,'COLLATERAL OF VET.'
			,'DOD DEPENDENT'
			,'EMPLOYEE'
			,'EXPANDED MH CARE NON-ENROLLEE'
			,'HUMANITARIAN EMERGENCY'
			,'NON-VET OTHER/HUMAN EMRG'
			,'SHARING AGREEMENT'
			,'SHARING DOD-FALLON'
			,'TRICARE'
			,'TRICARE FAMILY PRACTICE'
			,'TRICARE PRIME'
			,'VOLUNTEER'
			,'VOLUNTEER NON-VETERAN'
			,'WILLOW CLINIC'
		)  THEN 0 ELSE 1 END) OVER (PARTITION BY b.MVIPersonSID) AS EligibilitySum
	FROM [SPatient].[SPatient] a WITH (NOLOCK)
	INNER JOIN #PossIneligible b ON a.PatientSID=b.PatientPersonSID
) a WHERE EligibilitySum=0

UPDATE [CaringLetters].[VCL_Cohort]
SET DoNotSendDate = getdate()
	,DoNotSendReason = 'Ineligible for VA Care'
	,DoNotSend=1
WHERE MVIPersonSID IN (SELECT MVIPersonSID FROM #Eligibility WHERE EligibilitySum=0)
AND DoNotSend=0

;
--Populate Mailing List
IF (SELECT COUNT(*) FROM [CaringLetters].[VCL_Mailings] WHERE MailingDate > (SELECT WeekEnd FROM #WeekEpisodes)) = 0
BEGIN
EXEC  [Code].[CaringLetters_Mailings] @RunType='VCL'
END
;

--Execute Code.Present_CaringLetters to udpate data on downstream report
EXEC [Code].[Present_CaringLetters]
;

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END;

END