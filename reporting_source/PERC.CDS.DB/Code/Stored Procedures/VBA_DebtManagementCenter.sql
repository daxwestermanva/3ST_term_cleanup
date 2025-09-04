
-- ==========================================================================================
-- Author:		Hannemann, Claire 
-- Create date: 2021-09-19
-- Description:	Combine files from VBA's Debt Management Center (DMC) and retain all records 
--				on patient-debt level (one row for each type of debt).
--				Create columns for: 
--				Date of First Demand Letter in last 150 days (if applicable)
--				Date of most recent High Stress letter (if applicable)
--				Total number of debts per patient
--				Total debt amount per patient
--
-- Modifications:
--	2022/07/08	JEB Updated Synonym references to point to Synonyms from Core
--				JEB Also note, no logging is currently implemented within this SP. There is a log execution end, but no corresponding begin
--	2022-07-11	JEB Updated more Synonym references to point to Synonyms from Core (missed some)
--	2023-10-23	LM	Added logic for which message should display on reports based on letter dates
-- ==========================================================================================

CREATE PROCEDURE [Code].[VBA_DebtManagementCenter]

AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.VBA_DebtManagementCenter', @Description = 'Execution of Code.VBA_DebtManagementCenter SP'

--Join together and retain all non-zero debts, combine with Common.MasterPatient to find VHA users
DROP TABLE IF EXISTS #DMC
SELECT DISTINCT c.MVIPersonSID, 
		c.PatientICN,
		a.ADAM_KEY,
		a.TOTAL_AR_AMOUNT,
		a.DEDUCTION_DESC,
		b.Letter_Desc,
		b.Contact_Date
INTO #DMC
FROM [PDW].[VAAUSSQLCAO21_DMC_HRV_dbo_HRV_DEBT] a WITH (NOLOCK)
INNER JOIN [PDW].[VAAUSSQLCAO21_DMC_HRV_dbo_HRV_LETTER] b WITH (NOLOCK) on a.ADAM_KEY=b.ADAM_KEY and a.BATCH_ID=b.BATCH_ID
INNER JOIN Common.MasterPatient c WITH (NOLOCK) on a.SSN=c.PatientSSN
WHERE a.TOTAL_AR_AMOUNT > 0

DROP TABLE IF EXISTS #FirstDemand
SELECT ADAM_KEY
	,CASE WHEN MAX(Letter_Code) LIKE '101%' THEN 1
		ELSE 0 END AS CPDeduction
	,MAX(Contact_Date) AS Contact_Date
INTO #FirstDemand
FROM [PDW].[VAAUSSQLCAO21_DMC_HRV_dbo_HRV_LETTER] WITH (NOLOCK)
WHERE Letter_Code LIKE '100%' OR Letter_Code LIKE '101%'
GROUP BY ADAM_KEY

DROP TABLE IF EXISTS #TreasuryOffset
SELECT ADAM_KEY
	,MAX(Contact_Date) AS Contact_Date
INTO #TreasuryOffset
FROM [PDW].[VAAUSSQLCAO21_DMC_HRV_dbo_HRV_LETTER] WITH (NOLOCK)
WHERE Letter_Code LIKE '123%'
GROUP BY ADAM_KEY

DROP TABLE IF EXISTS #CrossServicing
SELECT ADAM_KEY
	,MAX(Contact_Date) AS Contact_Date
INTO #CrossServicing
FROM [PDW].[VAAUSSQLCAO21_DMC_HRV_dbo_HRV_LETTER] WITH (NOLOCK)
WHERE Letter_Code LIKE '080%'
GROUP BY ADAM_KEY

-- Retain most recent date and letter description for each debt
DROP TABLE IF EXISTS #MostRecent
SELECT  ADAM_KEY,
		Contact_Date as MostRecentContact_Date,
		LETTER_DESC as MostRecentContact_Letter
INTO #MostRecent
FROM 	(	
		SELECT * 
				,row_number() OVER(PARTITION BY ADAM_KEY ORDER BY Contact_Date desc) AS RN
		 FROM #DMC
		 ) a
WHERE a.RN=1

DROP TABLE IF EXISTS #DMC2
SELECT DISTINCT a.MVIPersonSID,
				a.PatientICN,
				a.ADAM_KEY,
				CAST(ROUND(a.TOTAL_AR_AMOUNT,0) as int) as TOTAL_AR_AMOUNT,
				a.DEDUCTION_DESC, 
				b.MostRecentContact_Date,
				b.MostRecentContact_Letter
INTO #DMC2
FROM #DMC a 
LEFT JOIN #MostRecent b on a.ADAM_KEY=b.ADAM_KEY


--Add in columns for total number of debts per patient and total debt amount per patient
DROP TABLE IF EXISTS #Patient_Level
SELECT MVIPersonSID,
		SUM(TOTAL_AR_AMOUNT) as Patient_Debt_Sum,
		COUNT(ADAM_KEY) as Patient_Debt_Count
INTO #Patient_Level
FROM #DMC2
GROUP BY MVIPersonSID

--Retain all records on patient-debt level (one row for each type of debt)
DROP TABLE IF EXISTS #DMC_Final
SELECT a.MVIPersonSID
		,a.PatientICN
		,a.ADAM_KEY
		,CASE WHEN a.TOTAL_AR_AMOUNT = 0 THEN 1 ELSE a.TOTAL_AR_AMOUNT END AS TOTAL_AR_AMOUNT
		,a.DEDUCTION_DESC
		,a.MostRecentContact_Date
		,a.MostRecentContact_Letter
		,b.Patient_Debt_Count
		,CASE WHEN b.Patient_Debt_Sum = 0 THEN 1 ELSE b.Patient_Debt_Sum END AS Patient_Debt_Sum
		,c.CPDeduction
		,c.CONTACT_DATE AS FirstDemandDate
		,d.CONTACT_DATE AS TreasuryOffsetDate
		,e.CONTACT_DATE AS ReferToCSDate
		,DisplayMessage = CASE WHEN getdate() <= DateAdd(day,180,c.Contact_Date)  OR (e.Contact_Date IS NULL AND d.Contact_Date IS NULL) THEN 1 --First six months from First Demand Letter, or no further referral: DMC message
							WHEN e.Contact_Date IS NOT NULL THEN 3 --greater than 6 months from first demand letter and referred to treasury cross-servicing: Treasury CS message
							WHEN d.Contact_Date IS NOT NULL THEN 2 --greater than 6 months from first demand letter and referred to treasury offset: Treasury offset message
							ELSE NULL END
INTO #DMC_Final
FROM #DMC2 a 
INNER JOIN #Patient_Level b on a.MVIPersonSID=b.MVIPersonSID
LEFT JOIN #FirstDemand c ON a.ADAM_KEY=c.ADAM_KEY
LEFT JOIN #TreasuryOffset d ON a.ADAM_KEY=d.ADAM_KEY
LEFT JOIN #CrossServicing e ON a.ADAM_KEY=e.ADAM_KEY

DROP TABLE IF EXISTS #MessageCombined
SELECT MVIPersonSID
	,STRING_AGG(DisplayMessage,',') AS MessageCombined
INTO #MessageCombined
FROM (SELECT DISTINCT MVIPersonSID, DisplayMessage FROM #DMC_Final) a
GROUP BY MVIPersonSID

--Update message if patient has debts in multiple statuses
UPDATE #DMC_Final
SET DisplayMessage = 
	CASE WHEN b.MessageCombined='1' THEN 1
		WHEN b.MessageCombined='2' THEN 2
		WHEN b.MessageCombined='3' THEN 3
		WHEN b.MessageCombined IN ('1,2','2,1') THEN 4
		WHEN b.MessageCombined IN ('1,3','3,1') THEN 5
		WHEN b.MessageCombined IN ('2,3','3,2') THEN 6
		WHEN b.MessageCombined IN ('1,2,3','1,3,2','2,1,3','2,3,1','3,2,1','3,1,2') THEN 7
		END
FROM #DMC_Final a
INNER JOIN #MessageCombined b
	ON a.MVIPersonSID=b.MVIPersonSID

EXEC [Maintenance].[PublishTable] 'VBA.DebtManagementCenter', '#DMC_Final'

EXEC [Log].[ExecutionEnd]

END