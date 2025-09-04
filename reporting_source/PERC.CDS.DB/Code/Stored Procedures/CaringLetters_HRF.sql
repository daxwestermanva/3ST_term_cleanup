

/*=============================================
-- Author:		Liam Mina
-- Create date: 3/17/2023
-- Description:	HRF caring letters sends mailings to patients with inactivated PRFs for suicide for 12 months post-inactivation
-- Updates:
	2023-07-18	LM	Add DoNotSendReason of 'Previously Enrolled in HRF CL'
	2023-07-19	LM	Remove exclusion on patients who previously received VCL CL. Include patients who are not currently recieving VCL CL, including those who did not receive the full course of VCL CL
	2023-08-09	LM	Add updated addresses from NCOA
	2023-10-17	LM	Add patients who are excluded from mailings due to flag reactivations; these patients may have 2 rows in the table eventually because they will be enrolled the next time their flag is inactivated
	2023-11-13	LM	Exclude patients who have had letters returned and securely destroyed, unless they have had a change of address in the meantime
	2024-04-04	LM	Exclude patients whose only VA eligibility is Humanitarian
	2024-06-26	LM	Add code 21 to list of unmailable addresses from NCOA
	2024-09-05	LM	Additional formatting for mailing addresses
	2025-03-13	LM	Consolidate HRF and VCL mailing list code
=========================================================================================================================================*/
CREATE PROCEDURE [Code].[CaringLetters_HRF]
	(@ForceUpdate BIT = 0)

AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.CaringLetters_HRF', @Description = 'Execution of Code.CaringLetters_HRF SP'

DECLARE @Today date = CAST(GETDATE() AS DATE)
DECLARE @Phase1Date date = '2023-06-30'
DECLARE @Phase2Date date = '2024-01-31'

;

--Get week dates for previous week Saturday-Friday (data runs on Saturdays)
DROP TABLE IF EXISTS #WeekEpisodes
SELECT TOP 1
	CAST(DateAdd(day,-6,Date) AS date) AS WeekBegin
	,CAST(date as date) AS WeekEnd
INTO #WeekEpisodes
FROM [Dim].[Date] WITH (NOLOCK)
WHERE DayOfWeek=6 --Friday
AND Date < @Today
ORDER BY Date DESC

-- Find existing data for release date(s) of interest
DROP TABLE IF EXISTS #existingdata
SELECT TOP 1 a.InsertDate
INTO #existingdata
FROM [CaringLetters].[HRF_Cohort] a WITH (NOLOCK)
INNER JOIN #WeekEpisodes b on 
	a.InsertDate > b.WeekEnd
ORDER BY a.InsertDate DESC

--End procedure if there is pre-existing data and @ForceUpdate is not set to 1
IF @ForceUpdate=0 
	AND EXISTS (SELECT * FROM #existingdata)
BEGIN
	DECLARE @msg0 varchar(250) = 'Data for this period already exists in PRF_HRS.CaringLettersCohort. Run SP with @ForceUpdate=1 to overwrite existing data.'
	PRINT @msg0
	
	EXEC [Log].[Message] 'Information','Update not completed'
		,@msg0

	EXEC [Log].[ExecutionEnd] 
	EXEC [Log].[ExecutionEnd] @Status='Error' 
	
	RETURN
END 

--Delete pre-existing data if force update is set 
--add message to log with release dates that were deleted and will be re-computed
IF @ForceUpdate=1 
BEGIN
	DELETE m
	FROM [CaringLetters].[HRF_Cohort] m
	INNER JOIN #existingdata r on 
		r.InsertDate=CAST(m.InsertDate as date)

	DELETE m
	FROM [CaringLetters].[HRF_Mailings] m
	INNER JOIN #existingdata r on 
		r.InsertDate=CAST(m.InsertDate as date)

	DROP TABLE IF EXISTS #MaxLetter
	SELECT MVIPersonSID, MAX(LetterNumber) AS MaxLetter
	INTO #MaxLetter
	FROM [CaringLetters].[HRF_Mailings]
	GROUP BY MVIPersonSID
	
	UPDATE [CaringLetters].[HRF_Mailings]
	SET ActiveRecord=1
	FROM [CaringLetters].[HRF_Mailings] a
	INNER JOIN #MaxLetter b ON a.MVIPersonSID=b.MVIPersonSID AND a.LetterNumber=b.MaxLetter
	WHERE ActiveMailingRecord=1 

	DECLARE @msg2 varchar(250) = 'Force update executed - pre-existing data will be deleted.'
	EXEC [Log].[Message] 'Information','Overwriting data'
		,@msg2
END
	EXEC [Log].[ExecutionEnd]

--Make sure HRF data is updated - execute here since this will run on the weekend
EXEC [Code].[PRF_HRS_ActiveAndHistory];
EXEC [Code].[PRF_HRS_Episodes];


--Patients who should not receive caring letters - opted out, died, can't receive mail, ineligible former service members
DROP TABLE IF EXISTS #NoCaringLetters
SELECT TOP 1 WITH TIES MVIPersonSID 
	,CASE WHEN List LIKE 'PRF_CaringCommNo%' THEN 1 ELSE 0 END AS DoNotSend
	,CASE WHEN List LIKE 'PRF_CaringCommNo%' THEN h.HealthFactorDateTime ELSE NULL END AS DoNotSendDate
	,CASE WHEN List LIKE 'PRF_CaringCommNo%' THEN PrintName ELSE NULL END AS DoNotSendReason
INTO #NoCaringLetters
FROM [OMHSP_Standard].[HealthFactorSuicPrev] h WITH (NOLOCK)
WHERE List LIKE 'PRF_CaringComm%'
ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY HealthFactorDateTime DESC) -- get most recent 

--Check for VCL pre-emptive opt outs - these are deceased patients that VCL has identified who should never be enrolled in caring letters
DROP TABLE IF EXISTS #PreEmptiveOptOut
SELECT b.PatientICN, a.DateAdded
INTO #PreEmptiveOptOut
FROM [CaringLetters].[VCL_PreEmptiveOptOuts] a  WITH (NOLOCK)
INNER JOIN [Common].[MasterPatient] b  WITH (NOLOCK)
	ON a.SSN = b.PatientSSN AND a.LastName = b.LastName AND a.FirstName = b.FirstName

--Get patients with newly inactivated flags who should begin receiving caring letters this week
DROP TABLE IF EXISTS #Cohort
SELECT DISTINCT a.MVIPersonSID
	,b.PatientICN
	,MAX(a.EpisodeEndDateTime) OVER (PARTITION BY a.MVIPersonSID) AS EpisodeEndDateTime
	,a.OwnerChecklistID
	,COALESCE(n.DoNotSendDate
		,b.DateOfDeath_Combined
		,p.DateAdded
		,CASE WHEN (d.LastScheduledLetterDate >= @Phase1Date AND DoNotSend_date IS NULL AND r.StartDate = @Phase1Date)
			OR (d.LastScheduledLetterDate >= @Phase2Date AND DoNotSend_date IS NULL AND r.StartDate = @Phase2Date)
			THEN d.EligibleDate END
		,e.EpisodeBeginDateTime
			,cl.InsertDate
			)  AS DoNotSendDate
	,CASE WHEN n.DoNotSendReason IS NOT NULL THEN n.DoNotSendReason
		WHEN b.DateOfDeath_Combined IS NOT NULL OR p.PatientICN IS NOT NULL THEN 'Deceased'
		WHEN (d.LastScheduledLetterDate >= @Phase1Date AND DoNotSend_date IS NULL AND r.StartDate = @Phase1Date)
			OR (d.LastScheduledLetterDate >= @Phase2Date AND DoNotSend_date IS NULL AND r.StartDate = @Phase2Date)
			THEN 'Enrolled in VCL CL' --Exclude patients who are currently recieving VCL CL
		WHEN cl.MVIPersonSID IS NOT NULL THEN 'Previously Enrolled in HRF CL'
		WHEN e.MVIPersonSID IS NOT NULL THEN 'Reactivated'
		END AS DoNotSendReason
	,InsertDate = @Today
	,c.WeekBegin
	,c.WeekEnd
INTO #Cohort
FROM [PRF_HRS].[EpisodeDates] a WITH (NOLOCK)
INNER JOIN [Common].[MasterPatient] b WITH (NOLOCK)
	ON a.MVIPersonSID=b.MVIPersonSID
INNER JOIN [Config].[PRF_HRS_CaringLetterRollout] r WITH (NOLOCK)
	ON a.OwnerChecklistID = r.ChecklistID AND r.StartDate <= @Today
INNER JOIN #WeekEpisodes c
	ON CAST(a.EpisodeEndDateTime AS date) BETWEEN DateAdd(day,-7,c.WeekBegin) AND c.WeekEnd --extend episode window to catch cases where we might have had delayed data
LEFT JOIN [Present].[CaringLetters] d WITH (NOLOCK) --Exclude patients who have ever received VCL caring letters
	ON b.MVIPersonSID = d.MVIPersonSID AND d.Program = 'VCL Caring Letters'
LEFT JOIN #NoCaringLetters n
	ON a.MVIPersonSID = n.MVIPersonSID AND CAST(n.DoNotSendDate AS date) >= CAST(DateAdd(day,-7,a.EpisodeEndDateTime) AS date) --opt outs documented within 7 days of the end of the episode
LEFT JOIN [PRF_HRS].[EpisodeDates] e WITH (NOLOCK)
	ON a.MVIPersonSID = e.MVIPersonSID AND e.EpisodeBeginDateTime BETWEEN a.EpisodeEndDateTime AND DateAdd(day,3,a.EpisodeEndDateTime) --episodes restarted within 3 days of inactivation
LEFT JOIN (SELECT * FROM [CaringLetters].[HRF_Cohort] WITH (NOLOCK) WHERE DoNotSendReason IS NULL OR DoNotSendReason <> 'Reactivated') cl 
	--exclude if the patient has previously been enrolled or classified as do not send, unless they were 'do not send' because of a previous flag reactivation
	ON a.MVIPersonSID = cl.MVIPersonSID --AND a.EpisodeEndDateTime > cl.EpisodeEndDateTime --this join on the date isn't working quite right; since this scenario won't come up for a while I'm removing for now and will fix later
LEFT JOIN #PreEmptiveOptOut p
	ON b.PatientICN = p.PatientICN
WHERE --e.MVIPersonSID IS NULL--exclude patients whose flag was inactivated and immediately reactivated within 3 days
	 ((a.EpisodeEndDateTime >= @Phase1Date AND r.StartDate = @Phase1Date) OR (a.EpisodeEndDateTime >= @Phase2Date AND r.StartDate = @Phase2Date)) --two phases of rollout
AND cl.MVIPersonSID IS NULL --exclude patients who have already been enrolled in HRF CL

--Prevent extra entries for DoNotSend entries for reactivations
DELETE FROM #Cohort
WHERE MVIPersonSID IN (
SELECT a.MVIPersonSID FROM #Cohort a
INNER JOIN [CaringLetters].[HRF_Cohort] b
	ON a.MVIPersonSID=b.MVIPersonSID AND a.EpisodeEndDateTime=b.EpisodeEndDateTime)
	
--Remove patients who are not eligible for any VA care (humanitarian emergency)
DROP TABLE IF EXISTS #PossIneligible
SELECT c.MVIPersonSID, m.PatientICN, s.PatientPersonSID
INTO #PossIneligible
FROM #Cohort c
INNER JOIN [Common].[MasterPatient] m WITH (NOLOCK)
	ON c.MVIPersonSID = m.MVIPersonSID
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] s WITH (NOLOCK)
	ON c.MVIPersonSID=s.MVIPersonSID
WHERE c.DoNotSendDate IS NULL AND m.PriorityGroup=-1 AND m.COMPACTEligible=0

DROP TABLE IF EXISTS #Eligibility
SELECT MVIPersonSID, MIN(Exclude) AS Exclude
INTO #Eligibility
	FROM(
	SELECT c.MVIPersonSID--, s.Eligibility
		,CASE WHEN s.Eligibility IN ('HUMANITARIAN EMERGENCY','NON-VET OTHER/HUMAN EMRG')
			THEN 1 ELSE 0 END AS Exclude
	FROM #PossIneligible c
	INNER JOIN [SPatient].[SPatient] s WITH (NOLOCK)
		ON c.PatientPersonSID=s.PatientSID
	) a
GROUP BY MVIPersonSID

UPDATE #Cohort
SET DoNotSendDate = getdate()
	,DoNotSendReason = 'Ineligible former service member'
WHERE MVIPersonSID IN (SELECT MVIPersonSID FROM #Eligibility WHERE Exclude=1)


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
SELECT a.MVIPersonSID
	,a.PatientICN
	,a.OwnerChecklistID
	,a.EpisodeEndDateTime
	,a.InsertDate
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
INTO #AddLetterDates
FROM #Cohort a
LEFT JOIN #LetterDates b ON b.FirstLetterDate >= a.WeekEnd AND a.DoNotSendDate IS NULL

INSERT INTO [CaringLetters].[HRF_Cohort] (
	MVIPersonSID
	,PatientICN
	,OwnerChecklistID
	,EpisodeEndDateTime
	,InsertDate
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
	)
SELECT
	MVIPersonSID
	,PatientICN
	,OwnerChecklistID
	,EpisodeEndDateTime
	,InsertDate
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
FROM #AddLetterDates



--Update with opt-outs since the last run
--Health factors
UPDATE [CaringLetters].[HRF_Cohort]
SET DoNotSend = o.DoNotSend
	,DoNotSendDate = o.DoNotSendDate
	,DoNotSendReason = o.DoNotSendReason
FROM (SELECT * FROM #NoCaringLetters WHERE DoNotSend=1) o
INNER JOIN [CaringLetters].[HRF_Cohort] AS c 
	ON o.MVIPersonSID = c.MVIPersonSID 
	AND o.DoNotSendDate BETWEEN c.InsertDate AND c.EighthLetterDate
	AND c.DoNotSend = 0

--Writebacks
UPDATE [CaringLetters].[HRF_Cohort]
SET DoNotSend = o.DoNotSend
	,DoNotSendDate = o.InsertDate
	,DoNotSendReason = o.DoNotSendReason
FROM (SELECT * FROM [CaringLetters].[HRF_Mailings] WHERE DoNotSend=1 AND ActiveRecord=1) o
INNER JOIN [CaringLetters].[HRF_Cohort] AS c 
	ON o.MVIPersonSID = c.MVIPersonSID 
	AND c.DoNotSend = 0

--Update with deaths since last run
UPDATE [CaringLetters].[HRF_Cohort]
SET DoNotSend = 1
	,DoNotSendDate = @Today
	,DoNotSendReason = 'Deceased'
FROM Common.MasterPatient o WITH (NOLOCK)
INNER JOIN [CaringLetters].[HRF_Cohort] AS c 
	ON o.MVIPersonSID = c.MVIPersonSID 
	AND o.DateOfDeath_Combined IS NOT NULL
	AND c.DoNotSend = 0

UPDATE [CaringLetters].[HRF_Cohort]
SET DoNotSend = 1
	,DoNotSendDate = DateAdded
	,DoNotSendReason = 'Deceased'
FROM #PreEmptiveOptOut o
INNER JOIN [CaringLetters].[HRF_Cohort] AS c 
	ON o.PatientICN = c.PatientICN 
	AND c.DoNotSend = 0


--Update with bad addresses from NCOA. Bad addresses will be sent weekly from NCOA and imported into PRF_HRS.NCOA_BadAddress_DoNotSend; these patients should be removed from future mailings
UPDATE [CaringLetters].[HRF_Cohort]
SET DoNotSend = 1
	,DoNotSendDate = @Today
	,DoNotSendReason = 'Bad Address'
FROM [CaringLetters].[HRF_Cohort] AS c 
INNER JOIN [CaringLetters].[HRF_NCOA_BadAddress_DoNotSend] AS ad 
	ON ad.MVIPersonSID = c.MVIPersonSID 
	AND c.DoNotSend = 0
	AND ad.RC IN (21,23,27,33) --ignore other codes. these are the highest likelihood of being undeliverable

;
--Populate Mailing List
IF (SELECT COUNT(*) FROM [CaringLetters].[HRF_Mailings] WHERE MailingDate > (SELECT WeekEnd FROM #WeekEpisodes)) = 0
BEGIN
EXEC  [Code].[CaringLetters_Mailings] @RunType='HRF'
END
;


--Execute Code.Present_CaringLetters to udpate data on downstream reports
EXEC [Code].[Present_CaringLetters]

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END