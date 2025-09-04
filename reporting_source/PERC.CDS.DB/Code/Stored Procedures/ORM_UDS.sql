

-- =============================================
-- Author:		<OpioidRiskMitigationTeam><Sara Tavakoli/Tigran Avoudjian>
-- Create date: 1/8/2015
-- Description: Code for OpioidRiskMitigation Patient Report 
-- Modification: Combines basetable and patient report code
--	12/18/2016	GS repointed lookup tables to OMHO_PERC
--	2018-06-07	Jason Bacani - Removed hard coded database references
--	2019-02-15	Jason Bacani - Refactored to use [Maintenance].[PublishTable]; Added [Log].[ExecutionBegin] and [Log].[ExecutionEnd]
--  2020-10-20  Pooja Sohoni - Replaced references to LookUp.Lab to LookUp.Lab
--  2020-10-28  Elena Cherkasova - Replaced reference to Spatient_v02 with SPatient. Added Cerner overlay code.
--	2021-07-20	Jason Bacani - Enclave Refactoring - Counts confirmed
--  2022-28-11	Christina Wade - Updating joins between Cerner.FactLabResult and LookUp.Lab to correct Cerner output
-- =============================================
CREATE PROCEDURE [Code].[ORM_UDS]
AS
BEGIN

EXEC [Log].[ExecutionBegin] @Name = 'Code.ORM_UDS', @Description = 'Execution of Code.ORM_UDS SP'

/******************************************************** Drug Screen -UDS Past Year ************************************************************/

	DROP TABLE IF EXISTS #UDS_1;
	SELECT 
		lc.LabChemSID
		, lc.Sta3n
		, lc.MVIPersonSID
		, lc.LabChemTestSID
		, lc.LabChemCompleteDateTime
		, lc.LabChemResultValue
		, 1 AS UDS_Any
		, lc.Morphine_UDS AS UDS_MorphineHeroin_Key
		, lc.NonMorphineOpioid_UDS AS UDS_NonMorphineOpioid_Key
		, lc.NonOpioidAbusable_UDS AS UDS_NonOpioidAbusable_Key
	INTO #UDS_1
	FROM [Present].[SPatient] c WITH (NOLOCK)
	INNER JOIN
		(
			SELECT
				ISNULL(mvi.MVIPersonSID,0) AS MVIPersonSID
				, ll.Morphine_UDS 
				, ll.NonMorphineOpioid_UDS 
				, ll.NonOpioidAbusable_UDS 
				, lc1.LabChemSID
				, lc1.Sta3n
				, lc1.LabChemTestSID
				, lc1.LabChemCompleteDateTime
				, lc1.LabChemResultValue
			FROM [Chem].[LabChem] lc1 WITH (NOLOCK)
			INNER JOIN [LookUp].[Lab] ll WITH (NOLOCK)
				ON ll.LabChemTestSID = lc1.LabChemTestSID
			LEFT OUTER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON lc1.PatientSID = mvi.PatientPersonSID 
			WHERE lc1.LabChemCompleteDateTime >= CAST(DATEADD(DAY,-366,CAST(GETDATE() AS DATE))AS DATETIME2(0)) 
				AND (
						ll.Morphine_UDS = 1
						OR ll.NonMorphineOpioid_UDS = 1
						OR ll.NonOpioidAbusable_UDS = 1
					)
		)
		lc
		ON c.MVIPersonSID = lc.MVIPersonSID
	WHERE c.STORM = 1

CREATE NONCLUSTERED INDEX I_UDS_1 ON #UDS_1 (MVIPersonSID);

	DROP TABLE IF EXISTS #UDS_1_Cerner;
	SELECT lc.EncounterSID as LabChemSID
		,200 as Sta3n
		,lc.MVIPersonSID
		,lc.SourceIdentifier as LabChemTestSID
		,lc.TZPerformedUTCDateTime as LabChemCompleteDateTime
		,lc.ResultValue as LabChemResultValue
		,1 AS UDS_Any
		,ll.Morphine_UDS AS UDS_MorphineHeroin_Key
		,ll.NonMorphineOpioid_UDS AS UDS_NonMorphineOpioid_Key
		,ll.NonOpioidAbusable_UDS AS UDS_NonOpioidAbusable_Key
	INTO #UDS_1_Cerner
	FROM  [Present].[SPatient] AS C WITH (NOLOCK)  
	INNER JOIN [Cerner].[FactLabResult] lc WITH (NOLOCK) on c.MVIPersonSID=lc.MVIPersonSID
	INNER JOIN [LookUp].[Lab] ll WITH (NOLOCK) ON ll.LOINCSID=lc.NomenclatureSID
	WHERE lc.TZPerformedUTCDateTime >= CAST(DATEADD(DAY,-366,CAST(GETDATE() AS DATE))AS DATETIME2(0)) 
		AND c.STORM=1
		AND (
			ll.Morphine_UDS = 1
			OR ll.NonMorphineOpioid_UDS = 1
			OR ll.NonOpioidAbusable_UDS = 1
			)

CREATE NONCLUSTERED INDEX I_UDS_1_Cerner ON #UDS_1_Cerner (MVIPersonSID);

	DROP TABLE IF EXISTS #UDS_2
	SELECT coalesce(a.Sta3n, b.Sta3n, c.Sta3n, d.Sta3n) AS Sta3n
		,coalesce(a.MVIPersonSID, b.MVIPersonSID, c.MVIPersonSID, d.MVIPersonSID) AS MVIPersonSID
		,isnull(a.UDS_Any, 0) AS UDS_Any
		,a.UDS_Any_DateTime
		,isnull(b.UDS_MorphineHeroin_Key, 0) AS UDS_MorphineHeroin_Key
		,b.UDS_MorphineHeroin_DateTime
		,isnull(c.UDS_NonMorphineOpioid_Key, 0) AS UDS_NonMorphineOpioid_Key
		,c.UDS_NonMorphineOpioid_DateTime
		,isnull(d.UDS_NonOpioidAbusable_Key, 0) AS UDS_NonOpioidAbusable_Key
		,d.UDS_NonOpioidAbusable_DateTime
	INTO #UDS_2
	FROM (
		SELECT Sta3n
			,MVIPersonSID
			,max(LabChemCompleteDateTime) AS UDS_Any_DateTime
			,UDS_Any
		FROM #UDS_1
		GROUP BY Sta3n
			,MVIPersonSID
			,UDS_Any
		) AS a
	FULL JOIN (
		SELECT Sta3n
			,MVIPersonSID
			,max(LabChemCompleteDateTime) AS UDS_MorphineHeroin_DateTime
			,UDS_MorphineHeroin_Key
		FROM #UDS_1
		WHERE UDS_MorphineHeroin_Key = 1
		GROUP BY Sta3n
			,MVIPersonSID
			,UDS_MorphineHeroin_Key
		) AS b
		ON a.MVIPersonSID = b.MVIPersonSID
	FULL JOIN (
		SELECT Sta3n
			,MVIPersonSID
			,max(LabChemCompleteDateTime) AS UDS_NonMorphineOpioid_DateTime
			,UDS_NonMorphineOpioid_Key
		FROM #UDS_1
		WHERE UDS_NonMorphineOpioid_Key = 1
		GROUP BY Sta3n
			,MVIPersonSID
			,UDS_NonMorphineOpioid_Key
		) AS c
		ON  a.MVIPersonSID = c.MVIPersonSID
	FULL JOIN (
		SELECT Sta3n
			,MVIPersonSID
			,max(LabChemCompleteDateTime) AS UDS_NonOpioidAbusable_DateTime
			,UDS_NonOpioidAbusable_Key
		FROM #UDS_1
		WHERE UDS_NonOpioidAbusable_Key = 1
		GROUP BY Sta3n
			,MVIPersonSID
			,UDS_NonOpioidAbusable_Key
		) AS d
		ON a.MVIPersonSID = d.MVIPersonSID

CREATE NONCLUSTERED INDEX I_UDS_2 ON #UDS_2 (MVIPersonSID);
		

	DROP TABLE IF EXISTS #UDS_2_Cerner;
	SELECT coalesce(a.Sta3n, b.Sta3n, c.Sta3n, d.Sta3n) AS Sta3n
		,coalesce(a.MVIPersonSID, b.MVIPersonSID, c.MVIPersonSID, d.MVIPersonSID) AS MVIPersonSID
		,isnull(a.UDS_Any, 0) AS UDS_Any
		,a.UDS_Any_DateTime
		,isnull(b.UDS_MorphineHeroin_Key, 0) AS UDS_MorphineHeroin_Key
		,b.UDS_MorphineHeroin_DateTime
		,isnull(c.UDS_NonMorphineOpioid_Key, 0) AS UDS_NonMorphineOpioid_Key
		,c.UDS_NonMorphineOpioid_DateTime
		,isnull(d.UDS_NonOpioidAbusable_Key, 0) AS UDS_NonOpioidAbusable_Key
		,d.UDS_NonOpioidAbusable_DateTime
	INTO #UDS_2_Cerner
	FROM (
		SELECT Sta3n
			,MVIPersonSID
			,max(LabChemCompleteDateTime) AS UDS_Any_DateTime
			,UDS_Any
		FROM #UDS_1_Cerner
		GROUP BY Sta3n
			,MVIPersonSID
			,UDS_Any
		) AS a
	FULL JOIN (
		SELECT Sta3n
			,MVIPersonSID
			,max(LabChemCompleteDateTime) AS UDS_MorphineHeroin_DateTime
			,UDS_MorphineHeroin_Key
		FROM #UDS_1_Cerner
		WHERE UDS_MorphineHeroin_Key = 1
		GROUP BY Sta3n
			,MVIPersonSID
			,UDS_MorphineHeroin_Key
		) AS b
		ON a.MVIPersonSID = b.MVIPersonSID
	FULL JOIN (
		SELECT Sta3n
			,MVIPersonSID
			,max(LabChemCompleteDateTime) AS UDS_NonMorphineOpioid_DateTime
			,UDS_NonMorphineOpioid_Key
		FROM #UDS_1_Cerner
		WHERE UDS_NonMorphineOpioid_Key = 1
		GROUP BY Sta3n
			,MVIPersonSID
			,UDS_NonMorphineOpioid_Key
		) AS c
		ON  a.MVIPersonSID = c.MVIPersonSID
	FULL JOIN (
		SELECT Sta3n
			,MVIPersonSID
			,max(LabChemCompleteDateTime) AS UDS_NonOpioidAbusable_DateTime
			,UDS_NonOpioidAbusable_Key
		FROM #UDS_1_Cerner
		WHERE UDS_NonOpioidAbusable_Key = 1
		GROUP BY Sta3n
			,MVIPersonSID
			,UDS_NonOpioidAbusable_Key
		) AS d
		ON a.MVIPersonSID = d.MVIPersonSID

CREATE NONCLUSTERED INDEX I_UDS_2_Cerner ON #UDS_2_Cerner (MVIPersonSID);

	DROP TABLE IF EXISTS #UDS_3;
	SELECT   MVIPersonSID
			,Sta3n
			,UDS_Any
			,UDS_Any_DateTime
			,UDS_MorphineHeroin_Key
			,UDS_MorphineHeroin_DateTime
			,UDS_NonMorphineOpioid_Key
			,UDS_NonMorphineOpioid_DateTime
			,UDS_NonOpioidAbusable_Key
			,UDS_NonOpioidAbusable_DateTime
	INTO #UDS_3
	FROM #UDS_2
	UNION ALL
	SELECT   MVIPersonSID
			,Sta3n
			,UDS_Any
			,UDS_Any_DateTime
			,UDS_MorphineHeroin_Key
			,UDS_MorphineHeroin_DateTime
			,UDS_NonMorphineOpioid_Key
			,UDS_NonMorphineOpioid_DateTime
			,UDS_NonOpioidAbusable_Key
			,UDS_NonOpioidAbusable_DateTime
	FROM #UDS_2_Cerner
			;

	DROP TABLE IF EXISTS #ORM_UDS;
		SELECT DISTINCT MVIPersonSID
			,Sta3n
			,MAX (CAST(UDS_Any AS INT)) AS UDS_Any
			,MAX (UDS_Any_DateTime) AS UDS_Any_DateTime
			,MAX (CAST(UDS_MorphineHeroin_Key AS INT)) AS UDS_MorphineHeroin_Key
			,MAX (UDS_MorphineHeroin_DateTime) AS UDS_MorphineHeroin_DateTime
			,MAX (CAST(UDS_NonMorphineOpioid_Key AS INT)) AS UDS_NonMorphineOpioid_Key
			,MAX (UDS_NonMorphineOpioid_DateTime) AS UDS_NonMorphineOpioid_DateTime
			,MAX (CAST(UDS_NonOpioidAbusable_Key AS INT)) AS UDS_NonOpioidAbusable_Key
			,MAX (UDS_NonOpioidAbusable_DateTime) AS UDS_NonOpioidAbusable_DateTime 
		INTO #ORM_UDS
		FROM #UDS_3
		GROUP BY MVIPersonSID, Sta3n
			;

EXEC [Maintenance].[PublishTable] 'ORM.UDS', '#ORM_UDS'

EXEC [Log].[ExecutionEnd] @Status = 'Completed'

END

GO
