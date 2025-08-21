

/********************************************************************************************************************
DESCRIPTION: OEND Fills
AUTHOR:		 Michael Harvey
CREATED:	 2015/02/05
UPDATE:
	[YYYY-MM-DD]	[INIT]	[CHANGE DESCRIPTION]
					ST/SM	updated naloxone criteria to be consistent with OEND
	2017-09-11		CB		removed the hard-coded variables and added reference to LookUp.NationalDrug instead	
	2018-06-07		JB		Removed hard coded database references
	2019-02-15		JB		Refactored to use [Maintenance].[PublishTable]; Added [Log].[ExecutionBegin] and [Log].[ExecutionEnd]
	2020-10-25		RAS		Formatting, replaced PatientICN with MVIPersonSID.
	2020-10-28		PS		Cerner overlay, renamed to a less stupid name
	2929-02-09		SM		replaced DispensedDateTime with CompletedDateTime
	2021-07-16		JEB		Enclave Refactoring - Counts confirmed
	2022-05-04		RAS		Switched Cerner pharmacy join to new table LookUp.Drug_VUID. 

********************************************************************************************************************/

CREATE PROCEDURE [Code].[ORM_NaloxoneKit]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.ORM_NaloxoneKit', @Description = 'Execution of Code.ORM_NaloxoneKit SP'

DROP TABLE IF EXISTS #ORM_NaloxoneKit
SELECT DISTINCT 
	 mvi.MVIPersonSID
	,fill.Sta3n
	,fill.PrescribingSta6a AS Sta6a
	,fill.LocalDrugNameWithDose AS DrugNameWithDose
	,fill.ReleaseDateTime
	,MAX(fill.ReleaseDateTime) OVER (PARTITION BY fill.RxOutpatFillSID) AS MostRecentFill
INTO #ORM_NaloxoneKit
FROM [RxOut].[RxOutpatFill] fill WITH (NOLOCK)
INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
	ON fill.PatientSID = mvi.PatientPersonSID 
INNER JOIN [LookUp].[NationalDrug] nd WITH (NOLOCK)
	ON fill.NationalDrugSID = nd.NationalDrugSID
WHERE nd.NaloxoneKit_Rx = 1
	AND fill.ReleaseDateTime > CAST('2013-07-01' AS DATETIME2(0))
	
UNION ALL 

SELECT DISTINCT 
	 fill.MVIPersonSID
	,Sta3n = 200
	,fill.Sta6a
	,lv.DrugNameWithDose
	,fill.TZDerivedCompletedUTCDateTime as ReleaseDateTime
	,MAX(fill.TZDerivedCompletedUTCDateTime) OVER(PARTITION BY fill.MedMgrPersonOrderSID) AS MostRecentFill
FROM [Cerner].[FactPharmacyOutpatientDispensed] AS fill
INNER JOIN [LookUp].[Drug_VUID] lv ON lv.VUID = fill.VUID
--INNER JOIN [LookUp].[NationalDrug] lv ON lv.NationalDrugSID = fill.ParentItemSID -- For validation before 4.16 release
WHERE lv.NaloxoneKit_Rx = 1
	AND fill.TZDerivedCompletedUTCDateTime > '2020-10-01'
;

EXEC [Maintenance].[PublishTable] 'ORM.NaloxoneKit', '#ORM_NaloxoneKit'

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END