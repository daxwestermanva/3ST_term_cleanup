

-- =============================================
-- Author:		Liam Mina (Code adapted from Amsler Roland and Jose Cosme from VHA Office of Revenue and Budget)
-- Create date: 4/15/2025
-- Description: COMPACT Act Copays for Mental Health-Crisis Intervention visits
-- Modifications:
	
-- Two output tables created for reporting
/*
Below is the listing of reports as of 01/15/2025:
i.	For RX Copays:
	1.	Pulling all RX Copays within 90 days of an outpatient T2034 CPT code with CPAC/VISN/Station/Sta6aDivision, as well as the RX Name and RX #.
ii.	For Outpatient Copays (Note: if the copay is linked to any other clinic visits on that DOS such as in a Dermatology clinic, the copay would still stand and therefore not display on this report):
	2.  Outpatient Copays directly linked to a visit with an ICD-10 code of R45.851. (NOTE: These need to be reviewed by the PATS team to ensure they are not related to COMPACT. The rest of the outpatient & inpatient copays for report #'s 3-9 will be cancelled without question).
	3.	Outpatient Copays directly linked to a visit with a T2034 CPT Code
	4.	Outpatient Copays directly linked to a visit with one of the three T14.91X_ Diagnosis Codes.
	5.	Outpatient Copays directly linked to a visit with both an ICD-10 code of R45.851 AND a CPT of 90839.
iii.	For Inpatient Copays (including the main inpatient copay charge, the inpatient per diem copays, and observation stays):
	6.	Where an outpatient visit occurred with a T2034 CPT code during the inpatient stay.
	7.	Where an outpatient visit occurred with both an ICD-10 code of R45.851 AND a CPT of 90839 during the inpatient stay.
	8.	Where one of the three T14.91X_ Diagnosis Codes is coded on the inpatient stay PTF or occurred immediately during the inpatient stay.
	9.	Where the ICD-10 code of R45.851 is coded as the Primary/Principal diagnosis on the inpatient stay (PTF). (Updated on 1/15/2025 from an R45.851 diagnosis coded anywhere on the inpatient stay or on an outpatient visit during the inpt stay, to only those with a Primary diagnosis of R45.851).

-- Updated on 4/6/2023 to left join to the Admin Parent site based on the RX Sta6a.
-- Update on 01/29/2024 to begin including copays in an On-Hold status per request from Daniel and Tamara on 01/25/2024.
-- Updated on 6/4/2024 for the inpatient copay section because we need to begin excluding the "Hospital Admission" and "LTC Admission" Brief Description Copay types, since these are placeholders for the main inpatient stay and LTC stay, but will not generate a copay, so these dont need to be cancelled.
-- Updated on 1/15/2025 & 03/06/2025 per emails from the Policy Analysts between 11/14/24 and 1/14/25 to change the inpatient section from pulling all inpatient stays with an R45.851 ICD-10 diagnosis code to only those with the R45.851 as the Primary/Principal diagnosis code. 

*/
-- =============================================


CREATE PROCEDURE [Code].[COMPACT_ORB_Copay]
AS
BEGIN
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	EXEC [Log].[ExecutionBegin] @Name = 'Code.COMPACT_ORB_Copay', @Description = 'Execution of Code.COMPACT_ORB_Copay SP'
	
DROP TABLE IF EXISTS #CPT
SELECT CPTSID, CPTCode
INTO #CPT
FROM Dim.CPT WITH (NOLOCK) 
WHERE CPTCode IN ('T2034','90839','99058','99281','99282','99283','99284','99285')

DROP TABLE IF EXISTS #ICD
SELECT ICD10SID, ICD10Code
INTO #ICD
FROM Dim.ICD10 WITH (NOLOCK) 
WHERE ICD10Code = 'R45.851' OR ICD10Code LIKE 'T14.91X%'

-- RX Copays within 90 days of the T2034 CPT Code (CRISIS INTERVENTION WAIVER/DIEM): First pull T2034 visits and then pull RX copays within 90 days of that date. This took 30 seconds to run for 913 rows.
DROP TABLE IF EXISTS #T2034CPTVisits
SELECT DISTINCT d.STA6A
	,v.PatientSID
	,mvi.MVIPersonSID
	,VP.VisitSID
	,C.CPTCode
	,VP.VisitDateTime
	,DATEADD(DD,90,VP.VisitDateTime) AS COMPACTActEligibilityRXCopayExemptionEndDate
INTO #T2034CPTVisits
FROM Outpat.Visit AS V WITH (NOLOCK) 
INNER JOIN Outpat.VProcedure AS VP WITH (NOLOCK) 
	ON V.VisitSID=VP.VisitSID
LEFT JOIN Dim.Division AS D WITH (NOLOCK) 
	ON V.DivisionSID=D.DivisionSID
INNER JOIN #CPT AS C WITH (NOLOCK) 
	ON VP.CPTSID=C.CPTSID
INNER JOIN Common.vwMVIPersonSIDPatientPersonSID mvi WITH (NOLOCK)
	ON v.PatientSID = mvi.PatientPersonSID
WHERE C.CPTCode='T2034' --CRISIS INTERVENTION WAIVER/DIEM
AND VP.VisitDateTime >= '2023-01-17' -- Legislation start date is 1/17/2023.
;


-- RX Copays from the IBAction table that occurred within 90 days of the T2034 CPT code. Excluding cancelled copays. This took 1:30 minutes to run and had 19 results.
DROP TABLE IF EXISTS #RxCopays
SELECT V.MVIPersonSID
	,C.EventDateTime
	,L.LocalDrugNameWithDose
	,Rx.RxNumber
	,S.StaffName AS PrescribingProvider
	,v.Sta6a
	,CASE WHEN RX.Sta6a = '*Unknown at this time*' THEN CONVERT(VARCHAR(50),C.Sta3n) 
				  WHEN RX.Sta6a = '*Missing*' THEN CONVERT(VARCHAR(50),C.Sta3n) 
				  WHEN RX.Sta6a IS NULL THEN CONVERT(VARCHAR(50),C.Sta3n) 
				  ELSE RX.Sta6a END AS PrescriptionSta6aDivision
	,V.CPTCode
	,CONVERT(VARCHAR(50),'N/A') AS ICD10Code
	,CONVERT(VARCHAR(255),'N/A') AS ICD10CodeDescription
	,V.VisitDateTime
	,V.COMPACTActEligibilityRXCopayExemptionEndDate
	,C.ARBillNumber
	,C.IBActionSID
	,C.TotalCharge
	,C.BillFromDateTime  -- Added IBActionSID field effective 1/29/2024
	,CONVERT(VARCHAR(33),'RX Copay with T2034') AS COMPACTCategory,'COMPACT NEEDS REVIEW' AS COMPACTAction
INTO #RxCopays
FROM #T2034CPTVisits AS V
INNER JOIN [IB].[IBAction] C WITH (NOLOCK)
	ON V.PatientSID=C.PatientSID
	AND C.EventDateTime >= V.VisitDateTime
	AND C.EventDateTime <= V.COMPACTActEligibilityRXCopayExemptionEndDate
LEFT JOIN Dim.IBActionType AS T WITH (NOLOCK) 
	ON C.IBActionTypeSID=T.IBActionTypeSID
LEFT JOIN RxOut.RxOutpat AS RX WITH (NOLOCK) 
	ON C.RxOutpatSID=RX.RxOutpatSID AND RX.PatientSID=C.PatientSID AND C.RxOutpatSID > 1 AND RX.IssueDate >= '2018-01-01' -- Joining RX fills based on the RXSID and the IssueDate is greater than 1/1/2018 to speed up the query (a couple years before the copay entered date because the prescriptions may have been written a year or so before that date).
LEFT JOIN SStaff.SStaff S WITH (NOLOCK) 
	ON RX.ProviderSID=S.StaffSID
LEFT JOIN Dim.LocalDrug AS L WITH (NOLOCK) 
	ON RX.LocalDrugSID=L.LocalDrugSID	
WHERE (C.RxOutpatFillSID >0 OR C.RxOutpatSID >0)
AND C.IBChargeRemoveReasonSID < 0 -- Exclude Cancelled bills, which may be cancelled due to SC/SA, billing errors, or already cancelled due to COMPACT Act.
AND C.EnteredDateTime >= '2023-01-17'
AND (C.RxOutpatFillSID >0 OR C.RxOutpatSID >0 OR T.IBActionType LIKE '%RX%')
AND C.IBChargeRemoveReasonSID < 0
--AND C.ARBillNumber IS NOT NULL -- Exclude unbilled copays.  -- Update as of 01/29/2024: Daniel and Tamara would like to include those copays that are in an On-Hold status (with NULL AR Bill Numbers) so the copays can get cancelled before they "drop" to the patient statement.

;
-- Now pull the comments on the Copay bill number to see if they have been previously reviewed and validated.
DROP TABLE IF EXISTS #Comments
SELECT DISTINCT r.MVIPersonSID
	,r.EventDateTime
	,r.LocalDrugNameWithDose
	,r.RxNumber
	,r.PrescribingProvider
	,r.Sta6a
	,r.PrescriptionSta6aDivision
	,r.CPTCode
	,r.ICD10Code
	,r.ICD10CodeDescription
	,r.VisitDateTime
	,r.COMPACTActEligibilityRXCopayExemptionEndDate
	,r.ARBillNumber
	,r.IBActionSID
	,r.TotalCharge
	,r.BillFromDateTime  -- Added IBActionSID field effective 1/29/2024
	,CONVERT(VARCHAR(33),'RX Copay with T2034') AS COMPACTCategory
	,'COMPACT NEEDS REVIEW' AS COMPACTAction
	,AR.AccountsReceivableSID
	,T.Comment
	,T.TransactionDateTime
INTO #Comments
FROM #RxCopays R
LEFT JOIN IB.AccountsReceivable AS AR WITH (NOLOCK) 
	ON R.ARBillNumber=AR.BillNumber AND AR.BillPreparedDateTime >= CONVERT(DATETIME2(0),'1/1/2022')AND R.ARBillNumber IS NOT NULL  -- Added BillPreparedDateTime to speed up the query.  Added R.ARBillNumber IS NOT NULL on 1/29/2024 to exclude bills in an On-Hold status from being joined to the AR table since these wont have an AR entry yet.
LEFT JOIN IB.ARTransaction AS T WITH (NOLOCK) 
	ON AR.AccountsReceivableSID=T.AccountsReceivableSID AND T.Comment IS NOT NULL -- Pull all Brief Comments on the Copay bill.
WHERE T.Comment LIKE '%PATS-R CREATED%' OR T.Comment LIKE '%VALIDATED NON COMPACT%' -- This line was added on 3/28/2023 to add a column on the NEEDS REVIEW report when a PATS-R has been created for a provider to review the copay, but it has not yet been either cancelled or valided as not related to COMPACT Act.
;

-- This will pull all RX Copays from the #RxCopays temp table above, but exclude ones that have already been reviewed and have a comment that says "VALIDATED NON COMPACT".
;

DROP TABLE IF EXISTS #NeedsReview
SELECT DISTINCT r.MVIPersonSID
	,r.EventDateTime
	,r.LocalDrugNameWithDose
	,r.RxNumber
	,r.PrescribingProvider
	,CASE WHEN R.PrescriptionSta6aDivision = 'N/A' THEN R.Sta6a 
		WHEN R.PrescriptionSta6aDivision IS NULL THEN R.Sta6a 
		ELSE R.PrescriptionSta6aDivision 
		END AS Sta6a
	,r.CPTCode
	,r.ICD10Code
	,VisitSID=CONVERT(bigint,NULL)
	,r.COMPACTActEligibilityRXCopayExemptionEndDate
	,r.ARBillNumber
	,r.IBActionSID
	,r.TotalCharge
	,r.COMPACTCategory
	,r.COMPACTAction
	,CASE WHEN C.Comment LIKE '%PATS-R CREATED%' THEN 'PATS-R CREATED' ELSE '' END AS PATS_R_Status -- This line was added on 3/28/2023 to add a column on the NEEDS REVIEW report when a PATS-R has been created for a provider to review the copay, but it has not yet been either cancelled or valided as not related to COMPACT Act.
INTO #NeedsReview
FROM #RxCopays R
INNER JOIN (SELECT IBActionSID,MIN(VisitDateTime) AS MinVisitDateTime FROM #RxCopays GROUP BY IBActionSID) AS RX ON R.VisitDateTime=RX.MinVisitDateTime AND R.IBActionSID=RX.IBActionSID -- This Inner Join was added on 3/29/23 to eliminate the duplicates by identifying the earliest T2034 Visit Date for each Copay Bill #. In the sample/test, there were 3,186 rows with duplicates, but only 1,671 unique bill numbers. By joining to the same table based on the bill number and MIN visit date (earliest T2034 date of service), it eliminated the duplicates and now shows only 1,671 rows. Updated on 1/29/2024 from ARBillNumber to IBActionSID since copays in an On-Hold status wont have an ARBillNumber populated and therefore would get left off.
LEFT JOIN #Comments AS C ON R.IBActionSID=C.IBActionSID  -- This line was added on 3/28/2023 to add a column on the NEEDS REVIEW report when a PATS-R has been created for a provider to review the copay, but it has not yet been either cancelled or valided as not related to COMPACT Act. Updated on 1/29/2024 from ARBillNumber to IBActionSID
WHERE R.IBActionSID NOT IN (SELECT IBActionSID FROM #Comments WHERE Comment LIKE '%VALIDATED NON COMPACT%') -- Exclude Copay bill #'s that have the Comment Validated Non-Compact. Updated 1/29/2024 from ARBillNumber to IBActionSID to prevent excluding NULL ARBillNumbers in an On-Hold Status.

;
-- ii.	For Outpatient Copays (Note: if the copay is linked to any other clinic visits on that DOS such as in a Dermatology clinic, the copay would still stand and therefore not display on this report):
	--2.	Outpatient Copays directly linked to a visit with an ICD-10 code of R45.851. (Note: These will require a PATS-R Review to determine if the visit was related to COMPACT Act care or not since this diagnosis alone would not necessarily indicate an acute suicide crisis).
	--3.	Outpatient Copays directly linked to a visit with a T2034 CPT Code
	--4.	Outpatient Copays directly linked to a visit with one of the three T14.91X_ Diagnosis Codes.
	--5.	Outpatient Copays directly linked to a visit with both an ICD-10 code of R45.851 AND a CPT of 90839.
	
-- Note: Before #2 runs (The visits with just an R45.851 diagnosis), I am pulling the visits with an R45.851 AND a 90839 CPT code to ensure those visits arent listed on both reports:

DROP TABLE IF EXISTS #SuicidalPsychotherapyVisits
SELECT DISTINCT V.VisitSID
	,V.PatientSID
	,mvi.MVIPersonSID
	,V.VisitDateTime
	,D.Sta6a
	,C.CPTCode
	,I.ICD10Code
INTO #SuicidalPsychotherapyVisits
FROM Outpat.Visit V WITH (NOLOCK)
INNER JOIN Outpat.VProcedure AS VP WITH (NOLOCK)
	ON V.VisitSID=VP.VisitSID
INNER JOIN Outpat.VDiagnosis AS VD WITH (NOLOCK)
	ON V.VisitSID=VD.VisitSID
INNER JOIN #CPT AS C WITH (NOLOCK)
	ON C.CPTSID=VP.CPTSID
INNER JOIN #ICD AS I WITH (NOLOCK)
	ON VD.ICD10SID=I.ICD10SID
INNER JOIN Common.vwMVIPersonSIDPatientPersonSID mvi WITH (NOLOCK)
	ON v.PatientSID=mvi.PatientPersonSID
LEFT JOIN Dim.Division AS D WITH (NOLOCK)
	ON V.DivisionSID=D.DivisionSID
WHERE V.VisitDateTime >= '2023-01-17'
AND I.ICD10Code = 'R45.851' -- Suicidal Ideations
AND C.CPTCode = '90839' -- PsychoTherapy for Crisis, Initial Visit up to 60-min.
;

-- Outpatient Copays directly linked to a visit with an ICD-10 code of R45.851 (Note: This was added back into the reports effective 03/06/2023 after a call with Dr. Smith where it was determined that some of the visits were in an ER and may be Emergent Suicide cases. These R45.851 copays will require a review from the PATS team to determine if they are related to COMPACT or not).  The first part took 7:30 minutes to run and had 770,000 rows, and the second half took 2 minutes and had 2,625 rows. After changing the date to 1/17/23, it took 1 minute and identified 11,936 visits, and the second half took 9 seconds and had 37 rows.
DROP TABLE IF EXISTS #SuicidalIdeationVisits
SELECT DISTINCT V.VisitSID
	,V.PatientSID
	,mvi.MVIPersonSID
	,V.VisitDateTime
	,D.Sta6a
	,I.ICD10Code
INTO #SuicidalIdeationVisits
FROM Outpat.Visit V WITH (NOLOCK)
INNER JOIN Outpat.VDiagnosis AS VD WITH (NOLOCK)
	ON V.VisitSID=VD.VisitSID
INNER JOIN #ICD AS I WITH (NOLOCK)
	ON VD.ICD10SID=I.ICD10SID
INNER JOIN Outpat.VProcedure AS VP WITH (NOLOCK)
	ON V.VisitSID=VP.VisitSID
INNER JOIN #CPT AS C WITH (NOLOCK)
	ON C.CPTSID=VP.CPTSID
INNER JOIN Common.vwMVIPersonSIDPatientPersonSID mvi WITH (NOLOCK)
	ON v.PatientSID=mvi.PatientPersonSID
LEFT JOIN Dim.Division D WITH (NOLOCK)
	ON V.DivisionSID=D.DivisionSID
WHERE V.VisitDateTime >= '2023-01-17' -- COMPACT Act begin date.
AND I.ICD10Code = 'R45.851' -- Suicidal Ideations
AND C.CPTCode IN ('99058','99281','99282','99283','99284','99285') -- ER/Emergent Care CPT codes (which indicate a potential Suicidal Emergency, possibly related to COMPACT Act care).
AND V.VisitSID NOT IN (SELECT VisitSID FROM #SuicidalPsychotherapyVisits) -- This excludes R45.851 Visits if the same visit is already identified in the Suicidal Psychotherapy visits table above (which are R45.851 diagnosis with a 90839 CPT code on the same visit since these will automatically be cancelled and do not require a review).
;

DROP TABLE IF EXISTS #R45851Copays
SELECT DISTINCT p.MVIPersonSID
	,C.EventDateTime
	,'N/A' AS LocalDrugNameWithDose
	,RxNumber=NULL
	,'N/A' AS PrescribingProvider -- This is for the RX Copays w/in 90 days of a T2034 CPT.
	,'N/A' AS RxCopayStationName
	,PrescriptionSta6aDivision=-1 -- This is for the RX Copays w/in 90 days of a T2034 CPT.
	,V.Sta6a
	,'N/A' AS CPTCode
	,V.ICD10Code
	,V.VisitDateTime
	,V.VisitSID
	,CONVERT(DATETIME2(0),NULL) AS COMPACTActEligibilityRXCopayExemptionEndDate -- This is for the RX Copays w/in 90 days of a T2034 CPT.
	,C.ARBillNumber
	,C.IBActionSID
	,C.TotalCharge
	,C.BillFromDateTime
	,'R45.851 Emergent Outpatient Copay' AS COMPACTCategory
	,'COMPACT NEEDS REVIEW' AS COMPACTAction
INTO #R45851Copays
FROM #SuicidalIdeationVisits AS V
INNER JOIN [IB].[IBAction] AS C WITH (NOLOCK) ON V.PatientSID=C.PatientSID AND V.VisitSID=C.VisitSID
LEFT JOIN Common.vwMVIPersonSIDPatientPersonSID AS P WITH (NOLOCK) ON V.PatientSID=P.PatientPersonSID
--WHERE C.ARBillNumber IS NOT NULL -- Commented out the ARBillNumber IS NOT NULL line on 1/29/2024 so bills in an On-Hold status will be included going forward.
WHERE C.IBChargeRemoveReasonSID < 0 -- Exclude Cancelled bills, which may be cancelled due to SC/SA, billing errors, or already cancelled due to COMPACT Act. Changed the word AND to WHERE on this line effective 1/29/2024.
AND C.EnteredDateTime >= '2023-01-01'-- Copay entered/created on/after 1/1/2023 to speed up report.
;

-- Now pull the comments on the Copay bill number to see if they have been previously reviewed and validated
DROP TABLE IF EXISTS #R45851Comments
SELECT DISTINCT r.MVIPersonSID
	,r.EventDateTime
	,r.LocalDrugNameWithDose
	,r.RxNumber
	,r.PrescribingProvider 
	,r.RxCopayStationName
	,r.PrescriptionSta6aDivision 
	,r.Sta6a
	,r.CPTCode
	,r.ICD10Code
	,r.VisitDateTime
	,r.COMPACTActEligibilityRXCopayExemptionEndDate 
	,r.ARBillNumber
	,r.IBActionSID
	,r.TotalCharge
	,r.BillFromDateTime
	,r.COMPACTCategory
	,r.COMPACTAction
	,AR.AccountsReceivableSID
	,T.Comment
	,T.TransactionDateTime
INTO #R45851Comments
FROM #R45851Copays R
LEFT JOIN IB.AccountsReceivable AS AR WITH (NOLOCK)
	ON R.ARBillNumber=AR.BillNumber AND AR.BillPreparedDateTime >= CONVERT(DATETIME2(0),'1/1/2022') AND R.ARBillNumber IS NOT NULL -- Added BillPreparedDateTime to speed up the query. Added R.ARBillNumber IS NOT NULL on 1/29/2024 to exclude bills in an On-Hold status from being joined to the AR table since these wont have an AR entry yet.
LEFT JOIN IB.ARTransaction AS T WITH (NOLOCK)
	ON AR.AccountsReceivableSID=T.AccountsReceivableSID AND T.Comment IS NOT NULL -- Pull all Brief Comments on the Copay bill.
WHERE T.Comment LIKE '%PATS-R CREATED%' OR T.Comment LIKE '%VALIDATED NON COMPACT%' -- This line was added on 3/28/2023 to add a column on the NEEDS REVIEW report when a PATS-R has been created for a provider to review the copay, but it has not yet been either cancelled or valided as not related to COMPACT Act.
;


-- This will pull all R45.851 Copays from the #R45851Copays temp table above, but exclude ones that have already been reviewed and have a comment that says "VALIDATED NON COMPACT".
INSERT INTO #NeedsReview
SELECT DISTINCT
	r.MVIPersonSID
	,r.EventDateTime
	,r.LocalDrugNameWithDose
	,r.RxNumber
	,r.PrescribingProvider
	,r.Sta6a
	,r.CPTCode
	,r.ICD10Code
	,r.VisitSID
	,r.COMPACTActEligibilityRXCopayExemptionEndDate
	,r.ARBillNumber
	,r.IBActionSID
	,r.TotalCharge
	,r.COMPACTCategory
	,r.COMPACTAction
	,CASE WHEN C.Comment LIKE '%PATS-R CREATED%' THEN 'PATS-R CREATED' ELSE '' END AS PATS_R_Status -- This line was added on 3/28/2023 to add a column on the NEEDS REVIEW report when a PATS-R has been created for a provider to review the copay, but it has not yet been either cancelled or valided as not related to COMPACT Act.
FROM #R45851Copays R
LEFT JOIN #R45851Comments AS C 
	ON R.IBActionSID=C.IBActionSID -- This line was added on 3/28/2023 to add a column on the NEEDS REVIEW report when a PATS-R has been created for a provider to review the copay, but it has not yet been either cancelled or valided as not related to COMPACT Act. Updated 1/29/2024 from ARBillNumber to IBActionSID to prevent excluding NULL ARBillNumbers in an On-Hold Status.
WHERE R.IBActionSID NOT IN (SELECT IBActionSID FROM #R45851Comments WHERE Comment LIKE '%VALIDATED NON COMPACT%') -- Exclude Copay bill #'s that have the Comment Validated Non-Compact. Updated 1/29/2024 from ARBillNumber to IBActionSID to prevent excluding NULL ARBillNumbers in an On-Hold Status.

;
-- Copays linked to T2034 (CRISIS INTERVENTION WAIVER/DIEM) CPT Code
DROP TABLE IF EXISTS #NeedsCancel
SELECT DISTINCT 
	v.MVIPersonSID
	,V.Sta6a 
	,C.ARBillNumber
	,v.VisitSID
	,CONVERT(bigint,InpatientSID,NULL) AS InpatientSID
	,C.TotalCharge
	,CONVERT(VARCHAR(255),'T2034 Outpatient Copay') AS COMPACTCategory
	,'COMPACT NEEDS CANCELLATION' AS COMPACTAction
INTO #NeedsCancel
FROM #T2034CPTVisits AS V
INNER JOIN [IB].[IBAction] AS C WITH (NOLOCK) 
	ON V.PatientSID=C.PatientSID AND V.VisitSID=C.VisitSID
--WHERE C.ARBillNumber IS NOT NULL -- Commented out the ARBillNumber IS NOT NULL line on 1/29/2024 so bills in an On-Hold status will be included going forward.
WHERE C.IBChargeRemoveReasonSID < 0 -- Exclude Cancelled bills, which may be cancelled due to SC/SA, billing errors, or already cancelled due to COMPACT Act. Changed the word AND to WHERE on this line effective 1/29/2024.
AND C.EnteredDateTime >= '2023-01-01' -- Copay entered/created on/after 1/1/2020.

;

-- Copays linked to one of the 3 T14.91X_ Diagnosis Codes
DROP TABLE IF EXISTS #TcodeDiagnosis
SELECT DISTINCT mvi.MVIPersonSID
	,D.Sta6a
	,VD.VisitSID
	,VD.VisitDateTime
	,VD.PatientSID
	,I.ICD10Code
INTO #TcodeDiagnosis
FROM Outpat.Visit AS V WITH (NOLOCK)
INNER JOIN Outpat.VDiagnosis AS VD WITH (NOLOCK)
	ON V.VisitSID=VD.VisitSID
INNER JOIN #ICD AS I WITH (NOLOCK)
	ON VD.ICD10SID=I.ICD10SID
INNER JOIN Common.vwMVIPersonSIDPatientPersonSID mvi WITH (NOLOCK)
	ON v.PatientSID=mvi.PatientPersonSID
LEFT JOIN Dim.Division AS D WITH (NOLOCK)
	ON V.DivisionSID=D.DivisionSID
WHERE VD.VisitDateTime >= '2023-01-17'
AND I.ICD10Code LIKE 'T14.91X%'
;

INSERT INTO #NeedsCancel
SELECT DISTINCT v.MVIPersonSID
	,V.STA6A  
	,C.ARBillNumber
	,v.VisitSID
	,InpatientSID=NULL
	,C.TotalCharge
	,'T14.91X_ Outpatient Copay' AS COMPACTCategory
	,'COMPACT NEEDS CANCELLATION' AS COMPACTAction
FROM #TcodeDiagnosis AS V
INNER JOIN [IB].[IBAction] AS C WITH (NOLOCK)
	ON V.PatientSID=C.PatientSID AND V.VisitSID=C.VisitSID
--WHERE C.ARBillNumber IS NOT NULL -- Commented out the ARBillNumber IS NOT NULL line on 1/29/2024 so bills in an On-Hold status will be included going forward.
WHERE C.IBChargeRemoveReasonSID < 0 -- Exclude Cancelled bills, which may be cancelled due to SC/SA, billing errors, or already cancelled due to COMPACT Act. Changed the word AND to WHERE on this line effective 1/29/2024.
AND C.EnteredDateTime >= '2023-01-01' -- Copay entered/created on/after 1/1/2023 to speed up report.
AND C.VisitSID > 1 -- Outpatient copays only

;

INSERT INTO #NeedsCancel
SELECT DISTINCT v.MVIPersonSID
	,V.STA6A 
	,C.ARBillNumber
	,v.VisitSID
	,InpatientSID=NULL
	,C.TotalCharge
	,'R45.851 & 90839 Outpatient Copay' AS COMPACTCategory,'COMPACT NEEDS CANCELLATION' AS COMPACTAction
FROM #SuicidalPsychotherapyVisits AS V WITH (NOLOCK)
INNER JOIN [IB].[IBAction] AS C WITH (NOLOCK)
	ON V.PatientSID=C.PatientSID AND V.VisitSID=C.VisitSID
--WHERE C.ARBillNumber IS NOT NULL -- Commented out the ARBillNumber IS NOT NULL line on 1/29/2024 so bills in an On-Hold status will be included going forward.
WHERE C.IBChargeRemoveReasonSID < 0 -- Exclude Cancelled bills, which may be cancelled due to SC/SA, billing errors, or already cancelled due to COMPACT Act. Changed the word AND to WHERE on this line effective 1/29/2024
AND C.EnteredDateTime >= '2023-01-01' -- Copay entered/created on/after 1/1/2023 to speed up report.
;

-- iii.	For Inpatient Copays (including the main inpatient copay charge, the inpatient per diem copays, and observation stays):
	--6.	Where an outpatient visit occurred with a T2034 CPT code during the inpatient stay.
	--7.	Where an outpatient visit occurred with both an ICD-10 code of R45.851 AND a CPT of 90839 during the inpatient stay.
	--8.	Where one of the three T14.91X_ Diagnosis Codes is on the inpatient stay.
	--9.	Where the ICD-10 code of R45.851 is coded on the inpatient stay (PTF).

-- First pull all inpatient stays:  This took 30 seconds to run and had 33,238 rows. 
DROP TABLE IF EXISTS #Inpatients
SELECT DISTINCT mvi.MVIPersonSID
	,D.Sta6a
	,I.PatientSID
	,I.InpatientSID
	,I.AdmitDateTime
	,CONVERT(Date,I.AdmitDateTime) AS AdmitDay
	,I.DischargeDateTime
INTO #Inpatients
FROM Inpat.Inpatient AS I WITH (NOLOCK)
INNER JOIN Common.vwMVIPersonSIDPatientPersonSID mvi WITH (NOLOCK)
	ON i.PatientSID=mvi.PatientPersonSID
LEFT JOIN Dim.WardLocation AS W WITH (NOLOCK)
	ON I.AdmitWardLocationSID=W.WardLocationSID
LEFT JOIN Dim.Division AS D WITH (NOLOCK)
	ON W.DivisionSID=D.DivisionSID 
WHERE I.AdmitDateTime >= '2023-01-17'-- Inpatients that were Admitted on/after 1/17/2023.
AND I.DischargeDateTime >= '2023-01-17' -- Per email from Tamara and Dr. Smith on 1/31/2023, only Inpatients that were admitted and discharged on/after 1/17/2023 are covered under COMPACT Act.
;
-- Then join the inpatient stays to an associated inpatient copay to identify the inpatient copay cohort
DROP TABLE IF EXISTS #InpatientCopays
SELECT DISTINCT i.MVIPersonSID
	,i.Sta6a
	,I.PatientSID
	,I.InpatientSID
	,I.AdmitDateTime
	,i.AdmitDay
	,I.DischargeDateTime
	,C.ARBillNumber
	,C.TotalCharge
	,C.BillFromDateTime
	,C.BillToDateTime
	,C.EventDateTime
	,C.EnteredDateTime
INTO #InpatientCopays
FROM IB.IBAction AS C WITH (NOLOCK) -- Copay table
INNER JOIN #Inpatients AS I ON C.InpatientSID=I.InpatientSID
WHERE C.EnteredDateTime >= '2023-01-01' -- To speed up the query
--AND C.ARBillNumber IS NOT NULL -- Excluded copays without a Bill # -- Commented out the ARBillNumber IS NOT NULL line on 1/29/2024 so bills in an On-Hold status will be included going forward.
AND C.IBChargeRemoveReasonSID < 0 -- Exclude Cancelled Copays with a ChargeRemoveReasonSID
AND C.BriefDescription NOT IN ('HOSPITAL ADMISSION','LTC ADMISSION') -- Effective 6/4/2024, we need to begin excluding the Hospital Admission and LTC Admission Copay types, since these are placeholders for the main inpatient stay and LTC stay, but will not generate a copay, so these dont need to be cancelled.
;

--6.	Inpatient copays where an outpatient visit occurred with a T2034 CPT code during the inpatient stay
INSERT INTO #NeedsCancel
SELECT DISTINCT 	
	i.MVIPersonSID
	,i.STA6A 
	,i.ARBillNumber
	,VisitSID=NULL
	,i.InpatientSID
	,i.TotalCharge
	,'T2034 Inpatient Copay' AS COMPACTCategory
	,'COMPACT NEEDS CANCELLATION' AS COMPACTAction
FROM #InpatientCopays I
INNER JOIN #T2034CPTVisits AS T  
	ON I.PatientSID=T.PatientSID AND T.VisitDateTime BETWEEN I.AdmitDay AND I.DischargeDateTime -- Joining the Inpatient Copays table to the #T2034CPTVisits T2034 CPTs table from above, using the PatientSID and where the T2034 VisitDateTime was between the Admit and Discharge dates. Note: Updated code on 03/13/2023 to use AdmitDay (short date) as the starting time in case the visit started in an ER so we can capture those that had a covered COMPACT Act visit during OR immediately before the inpatient stay.

;
--7.	Inpatient copays where an outpatient visit occurred with both an ICD-10 code of R45.851 AND a CPT of 90839 during the inpatient stay
INSERT INTO #NeedsCancel
SELECT DISTINCT i.MVIPersonSID
	,i.STA6A 
	,i.ARBillNumber
	,VisitSID=NULL
	,i.InpatientSID
	,i.TotalCharge
	,'R45.851 & 90839 Inpatient Copay' AS COMPACTCategory
	,'COMPACT NEEDS CANCELLATION' AS COMPACTAction
FROM #InpatientCopays I
INNER JOIN #SuicidalPsychotherapyVisits AS S 
	ON I.PatientSID=S.PatientSID AND S.VisitDateTime BETWEEN I.AdmitDay AND I.DischargeDateTime -- Joining the Inpatient Copays table to the #SuicidalPsychotherapyVisits (R45.851 Suicidal Ideations) and 90839 Psychotherapy initial visit CPTs table from above, using the PatientSID and where the Dx/CPT Combo VisitDateTime was between the Admit and Discharge dates. Note: Updated code on 03/13/2023 to use AdmitDay (short date) as the starting time in case the visit started in an ER so we can capture those that had a covered COMPACT Act visit during OR immediately before the inpatient stay.

;
	--8.	Inpatient copays where one of the three T14.91X_ Diagnosis Codes is on the inpatient stay
INSERT INTO #NeedsCancel
SELECT DISTINCT i.MVIPersonSID
	,i.STA6A 
	,i.ARBillNumber
	,VisitSID=NULL
	,i.InpatientSID
	,i.TotalCharge
	,'T14.91X_ Inpatient Copay' AS COMPACTCategory
	,'COMPACT NEEDS CANCELLATION' AS COMPACTAction
FROM #InpatientCopays I
LEFT JOIN #TcodeDiagnosis AS T ON I.PatientSID=T.PatientSID AND T.VisitDateTime BETWEEN I.AdmitDay AND I.DischargeDateTime -- Joining the Inpatient Copays table to the #TcodeDiagnosis (T14.91XA/XD/XS diagnosis code visits) table from above, using the PatientSID and where the T code VisitDateTime was between the Admit and Discharge dates. Note: Updated code on 03/13/2023 to use AdmitDay (short date) as the starting time in case the visit started in an ER so we can capture those that had a covered COMPACT Act visit during OR immediately before the inpatient stay.
-- Left joining to the inpatient ICD-10 diagnosis codes that were coded on the inpatient PTF to determine if the inpatient copay should be cancelled due to a COMPACT Act-related diagnosis on an outpatient visit or a diagnosis that was coded on the inpatient PTF:
LEFT JOIN (SELECT DISTINCT D.InpatientSID,IC.ICD10Code
			FROM Inpat.InpatientDiagnosis AS D WITH (NOLOCK)
			INNER JOIN #ICD AS IC WITH (NOLOCK)
				ON D.ICD10SID=IC.ICD10SID -- Also joining to the Inpatient Diagnosis table to determine if the specific diagnosis is directly linked to the inpatient stay (vs. the temp table where an outpatient visit occurred with that diagnosis during the inpatient stay).
			WHERE D.InpatientSID IN (SELECT DISTINCT InpatientSID FROM #InpatientCopays)
			AND ICD10Code LIKE 'T14.91X%'
			) AS IC ON I.InpatientSID=IC.InpatientSID
WHERE (T.VisitDateTime IS NOT NULL OR IC.ICD10Code LIKE 'T14.91X%') -- Pulling copays where either a T14.91X_ code was on an outpatient visit on the Admit Date or during the inpatient stay, or it was directly linked to the inpatient stay PTF.

;

 --Note: The section below was commented out because R45.851 by itself will no longer be required to review.
--9.	Where an ICD-10 code of R45.851 is coded as the Primary/Principal diagnosis on the inpatient stay.  
INSERT INTO #NeedsCancel
SELECT DISTINCT i.MVIPersonSID
	,i.STA6A 
	,i.ARBillNumber
	,VisitSID=NULL
	,i.InpatientSID
	,i.TotalCharge
	,'R45.851 Inpatient Copay' AS COMPACTCategory
	,'COMPACT NEEDS CANCELLATION' AS COMPACTAction
FROM #InpatientCopays I
-- Inner joining to the inpatient ICD-10 diagnosis codes that were coded on the inpatient PTF to determine if the inpatient copay should be cancelled due to a COMPACT Act-related diagnosisthat was coded on the inpatient PTF as the Primary/Principal Diagnosis code (i.e. Ordinal Number 0):
INNER JOIN Inpat.InpatientDiagnosis AS D WITH (NOLOCK)
	ON I.InpatientSID=D.InpatientSID AND D.OrdinalNumber = 0 -- Ordinal Number 0 is the Primary diagnosis. The CDW Metadata definition of Ordinal Number is: CDW generated number to represent the corresponding diagnosis (i.e. first secondary diagnosis = 1).
INNER JOIN #ICD AS IC WITH (NOLOCK)
	ON D.ICD10SID=IC.ICD10SID
WHERE IC.ICD10Code = 'R45.851' -- Suicidal Ideations diagnosis code
AND D.DischargeDateTime >= '2023-01-17' -- Per email from Tamara and Dr. Smith on 1/31/2023, only Inpatients that were admitted and discharged on/after 1/17/2023 are covered under COMPACT Act. This speeds up the query using Partition Elimination.

;
EXEC [Maintenance].[PublishTable] 'COMPACT.ORB_Copay_Review','#NeedsReview'
EXEC [Maintenance].[PublishTable] 'COMPACT.ORB_Copay_Cancel','#NeedsCancel'


EXEC [Log].[ExecutionEnd] @Status = 'Completed' ;

END