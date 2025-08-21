


/*-- =============================================
-- Author:		<Liam Mina>
-- Create date: <2023-06-07>
-- Description:	Combine VCL and HRF Caring Letters data

-- Modifications:
	2023-07-10	LM	Added ChecklistID
	2024-09-05	LM	Pointed to VCL.CaringLettersCohort for VCL caring letters
					Removed VCL CL extension; extention program ended more than a year ago and is not ongoing

-- Testing execution:
--		EXEC [Code].[Present_CaringLetters]
--
-- =============================================*/
CREATE PROCEDURE [Code].[Present_CaringLetters]
AS
BEGIN

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
EXEC [Log].[ExecutionBegin] @Name = 'Present_CaringLetters', @Description = 'Execution of Code.Present_CaringLetters'

DROP TABLE IF EXISTS #CL
SELECT DISTINCT m.MVIPersonSID
    ,CASE WHEN h.ChecklistID IS NOT NULL THEN h.ChecklistID
		WHEN b.VCL_NearestFacilitySiteCode > 0 THEN CAST(b.VCL_NearestFacilitySiteCode AS varchar)
		ELSE CAST(t.Sta3n AS varchar)
		END AS ChecklistID
	,Program='VCL Caring Letters'
	,b.VCL_Call_Date AS EligibleDate
	,b.EighthLetterDate AS LastScheduledLetterDate
    ,CASE WHEN b.FirstLetterDate IS NULL THEN 0 ELSE 1 END AS EverEnrolled --pre-emptive opt outs and HRF CL opt outs
	,CASE WHEN getdate()<=b.EighthLetterDate --original caring letters project is for 12 months
		AND (b.DoNotSend=0 OR b.DoNotSend IS NULL)
		THEN 1 ELSE 0 END AS CurrentEnrolled
	,CASE WHEN (getdate() between b.EighthLetterDate and DateAdd(month,12,EighthLetterDate) AND DoNotSend=0)
			OR (getdate() between b.DoNotSendDate and DateAdd(month,12,DoNotSendDate) AND DoNotSend=1 AND b.FirstLetterDate IS NOT NULL)
		THEN 1 ELSE 0 END AS PastYearEnrolled
	,b.DoNotSendDate DoNotSend_Date
	,b.DoNotSendReason AS DoNotSend_Reason
INTO #CL
FROM [CaringLetters].[VCL_Cohort] b WITH (NOLOCK) 
INNER JOIN [Common].[MasterPatient] m WITH (NOLOCK)
	ON b.PatientICN = m.PatientICN
LEFT JOIN [Present].[HomestationMonthly] h WITH (NOLOCK)
	ON m.MVIPersonSID = h.MVIPersonSID
LEFT JOIN (SELECT TOP 1 WITH TIES MVIPersonSID
					, Sta3n 
			FROM [Common].[MVIPersonSIDPatientPersonSID] WITH (NOLOCK) 
			WHERE Sta3n>200
			ORDER BY ROW_NUMBER() OVER (PARTITION BY MVIPersonSID ORDER BY UpdateDate DESC) 
			) t
	ON t.MVIPersonSID = m.MVIPersonSID

UNION ALL

SELECT c.MVIPersonSID
	,c.OwnerChecklistID
	,Program='HRF Caring Letters'
	,c.EpisodeEndDateTime AS EligibleDate
	,c.EighthLetterDate AS LastScheduledLetterDate
	,CASE WHEN c.FirstLetterDate IS NULL THEN 0 ELSE 1 END AS EverEnrolled
	,CASE WHEN getdate()<=c.EighthLetterDate AND (DoNotSend=0 OR DoNotSend IS NULL)
		THEN 1 ELSE 0 END AS CurrentEnrolled
	,CASE WHEN (getdate() between c.EighthLetterDate and DateAdd(month,12,EighthLetterDate) AND c.DoNotSend=0)
			OR (getdate() between c.DoNotSendDate and DateAdd(month,12,DoNotSendDate) AND c.DoNotSend=1 AND c.FirstLetterDate IS NOT NULL)
		THEN 1 ELSE 0 END AS PastYearEnrolled
	,c.DoNotSendDate
	,c.DoNotSendReason
FROM [CaringLetters].[HRF_Cohort] c WITH (NOLOCK)
INNER JOIN [Common].[MasterPatient] mp WITH (NOLOCK)
	ON c.MVIPersonSID = mp.MVIPersonSID


EXEC [Maintenance].[PublishTable] 'Present.CaringLetters', '#CL' ;
	
EXEC [Log].[ExecutionEnd] @Status = 'Completed' ;

END