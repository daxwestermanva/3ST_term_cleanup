 
-- =============================================
-- Author:		Sohoni, Pooja
-- Create date: 2019-06-05
-- Description:	App stored procedure to pull in diagnoses relevant to STORM. This replaces App.Admin_DiagnosisValidation_LSV for STORM, 
-- and feeds a new report ORM_Diagnosis
 
-- Updates:
	--	2020-10-19	LM	Overlay of Cerner data
	--	2020-12-17	RAS	Changed StationAssignments reference to MasterPatient and ActivePatient. Added aliases to select list, other formatting.
						-- Removed unneeded DISTINCTs from query. Moved station table joins from individual queries to once outside subquery.
	--	2021-09-13	Jason Bacani - Enclave Refactoring - Counts confirmed; Some formatting; Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	--  2023-09-18  CW  Updating DxCategory SUICIDE Source and DiagnosisSource
 
-- TEST:
	-- EXEC App.ORM_DiagnosisList @User='VHAMASTER\VHAISBBACANJ', @Patient='1016985222', @Diagnosis='OUD', @PatientType='PatientICN', @NoPHI=0;
	-- EXEC App.ORM_DiagnosisList @User='VHAMASTER\VHAISBBACANJ', @Patient='1016980503', @Diagnosis='OUD', @PatientType='PatientICN', @NoPHI=0;
	-- EXEC App.ORM_DiagnosisList @User='VHAMASTER\VHAISBBACANJ', @Patient='1022399080', @Diagnosis='MDD', @PatientType='PatientICN', @NoPHI=0;
	-- EXEC App.ORM_DiagnosisList @User='VHAMASTER\VHAISBBACANJ', @Patient='1010681487', @Diagnosis='SUICIDE', @PatientType='PatientICN', @NoPHI=0;
-- =============================================
CREATE PROCEDURE [App].[ORM_DiagnosisList]
(
	@User VARCHAR(MAX),
	@PatientType VARCHAR (100), -- Determines if PatientSID, PatientICN, or PatientSSN
	@Patient VARCHAR(1000),     -- number
	@Diagnosis VARCHAR(100),
	@NoPHI VARCHAR(5)
)
AS
BEGIN
	SET NOCOUNT ON;
 	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
 
	--For inlne testing only
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='VHAMASTER\VHAISBBACANJ', @Patient='1016980503'   , @Diagnosis='OUD'  , @PatientType='PatientICN', @NoPHI=1;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='VHAMASTER\VHAISBBACANJ', @Patient='1000715722'   , @Diagnosis='DUMMY', @PatientType='PatientICN', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='VHAMASTER\VHAISBBACANJ', @Patient='1016980503'   , @Diagnosis='Other_MH_STORM'  , @PatientType='PatientICN', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='VHAMASTER\VHAISBBACANJ', @Patient='2478293'      , @Diagnosis='OUD'  , @PatientType='PatientSID', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='VHAMASTER\VHAISBBACANJ', @Patient='4266028'      , @Diagnosis='OUD'  , @PatientType='PatientSID', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='VHAMASTER\VHAISBBACANJ', @Patient='1202541379'   , @Diagnosis='OUD'  , @PatientType='PatientSID', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='VHAMASTER\VHAISBBACANJ', @Patient='802393733'    , @Diagnosis='OUD'  , @PatientType='PatientSID', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='VHAMASTER\VHAISBBACANJ', @Patient='117463697'    , @Diagnosis='OUD'  , @PatientType='PatientSSN', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='vha21\vhapalrobina', @Patient='1016985222'    , @Diagnosis='OUD'  , @PatientType='PatientICN', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='vha21\vhapalrobina', @Patient='1010681487'    , @Diagnosis='SUICIDE'  , @PatientType='PatientICN', @NoPHI=0;
 
 
	--Get patient of interest
	DROP TABLE IF EXISTS #Patient;
	SELECT DISTINCT 
		pat.MVIPersonSID
	INTO #Patient
	FROM [Common].[MasterPatient] pat WITH (NOLOCK)
	INNER JOIN [Present].[ActivePatient] sa WITH (NOLOCK) ON pat.MVIPersonSID = sa.MVIPersonSID
	INNER JOIN (SELECT Sta3n FROM [App].[Access](@User)) Access ON sa.Sta3n_Loc = Access.Sta3n
	WHERE pat.PatientICN = @Patient
 
	SELECT 
		u.MVIPersonSID
		,u.DiagnosisSource
		,u.TableSource
		,u.TableSourceName
		,u.ICDCode
		,u.ICDDescription
		,u.VisitDateTime
		,u.AdmitDateTime
		,u.DischargeDatetime
		,u.Sta3n
		,c.Facility
	FROM 
		(
			--Outpatient diagnoses
			SELECT c.MVIPersonSID
				  ,'ICD10' AS DiagnosisSource
				  ,a.VisitDateTime
				  ,'' as AdmitDateTime
				  ,'' as DischargeDateTime
				  ,1 AS TableSource
				  ,ic.ICD10Code AS ICDCode  
				  ,ic.ICD10Description AS ICDDescription 
				  ,ic.DxCategory
				  ,'Encounters' AS TableSourceName
				  ,CAST(a.Sta3n as varchar) as Sta3n
			FROM #Patient c
			INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON c.MVIPersonSID = mvi.MVIPersonSID
			INNER JOIN [Outpat].[VDiagnosis] a WITH (NOLOCK)
				ON mvi.PatientPersonSID = a.PatientSID
			INNER JOIN [LookUp].[ICD10_VerticalSID] ic WITH (NOLOCK) ON ic.ICD10SID = a.ICD10SID
			WHERE a.VisitDateTime >= CAST((GETDATE() - 380) AS DATE)
 
			UNION ALL
			SELECT c.MVIPersonSID
				  ,'ICD10' AS DiagnosisSource
				  ,a.DerivedDiagnosisDateTime
				  ,'' as AdmitDateTime
				  ,'' as DischargeDateTime
				  ,1 AS TableSource
				  ,ic.ICD10Code AS ICDCode  
				  ,ic.ICD10Description AS ICDDescription 
				  ,ic.DxCategory
				  ,'Encounters' AS TableSourceName
				  ,Sta3n=LEFT(a.STAPA,3) 
			FROM [Cerner].[FactDiagnosis] a WITH (NOLOCK)
			INNER JOIN #Patient c ON a.MVIPersonSID = c.MVIPersonSID
			INNER JOIN [LookUp].[ICD10_VerticalSID] ic WITH (NOLOCK) ON ic.ICD10SID = a.NomenclatureSID
			WHERE a.DerivedDiagnosisDateTime >= CAST((GETDATE() - 380) AS DATE)
				AND a.EncounterTypeClass <> 'Inpatient'
 
			UNION ALL
			--Inpatient diagnoses
			SELECT c.MVIPersonSID
				  ,'ICD10' AS DiagnosisSource
				  ,'' as VisitDateTime
				  ,d.AdmitDateTime
				  ,d.DischargeDateTime
				  ,2 AS TableSource
				  ,ic.ICD10Code AS ICDCode  
				  ,ic.ICD10Description AS ICDDescription 
				  ,ic.DxCategory
				  ,'Inpatient' AS TableSourceName
				  ,CAST(a.Sta3n as varchar) as Sta3n
			FROM #Patient c
			INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON c.MVIPersonSID = mvi.MVIPersonSID
			INNER JOIN [Inpat].[InpatientDiagnosis] a WITH (NOLOCK)
				ON mvi.PatientPersonSID = a.PatientSID
			INNER JOIN [Inpat].[Inpatient] d WITH (NOLOCK) ON a.InpatientSID = d.InpatientSID 
			INNER JOIN [LookUp].[ICD10_VerticalSID] ic WITH (NOLOCK) ON ic.ICD10SID = a.ICD10SID
			WHERE d.AdmitDateTime >= CAST((GETDATE() - 380) AS DATE)
 
			UNION ALL
			SELECT c.MVIPersonSID
				  ,'ICD10' AS DiagnosisSource
				  ,a.DerivedDiagnosisDateTime
				  ,inpat.DerivedAdmitDateTime
				  ,inpat.DischargeDateTime
				  ,2 AS TableSource
				  ,ic.ICD10Code AS ICDCode  
				  ,ic.ICD10Description AS ICDDescription 
				  ,ic.DxCategory
				  ,'Inpatient' AS TableSourceName
				  ,Sta3n=LEFT(a.STAPA,3)
			FROM [Cerner].[FactDiagnosis] a WITH (NOLOCK)
			INNER JOIN [Cerner].[FactInpatient] inpat WITH (NOLOCK) ON a.EncounterSID=inpat.EncounterSID
			INNER JOIN #Patient c ON a.MVIPersonSID = c.MVIPersonSID
			INNER JOIN [LookUp].[ICD10_VerticalSID] ic WITH (NOLOCK) ON ic.ICD10SID = a.NomenclatureSID
			WHERE inpat.DerivedAdmitDateTime >= CAST((GETDATE() - 380) AS DATE)
				AND a.EncounterTypeClass = 'Inpatient'
 
			UNION ALL
			SELECT DISTINCT 
				   c.MVIPersonSID
				  ,DiagnosisSource=
					CASE WHEN DataSource LIKE '%COMP%' THEN 'CSRE'
						 WHEN DataSource LIKE '%OVERDOSE%' THEN 'SBOR'
						 WHEN DataSource = 'SPAN' THEN 'SPAN'
						 END
				  ,a.EventDateFormatted as VisitDateTime
				  ,'' as AdmitDateTime
				  ,'' as DischargeDateTime
				  ,3 AS TableSource
				  ,'' AS ICDCode  
				  ,a.EventType AS ICDDescription 
				  ,DxCategory = 'SUICIDE'
				  ,TableSourceName='SBOR/CSRE/SPAN'
				  ,a.Sta3n
			FROM [OMHSP_Standard].[SuicideOverdoseEvent] a WITH (NOLOCK)
			INNER JOIN #Patient c ON a.MVIPersonSID = c.MVIPersonSID
			WHERE a.EventDateFormatted >= CAST((GETDATE() - 380) AS DATE) 
			
			UNION ALL 
			SELECT DISTINCT
				c.MVIPersonSID
				,'DoD (recent separatee)' as DiagnosisSource
				,'' as VisitDateTime
				,'' as AdmitDateTime
				,'' as DischargeDateTime
				,4 as TableSource
				,'' as ICDCode
				,d.PrintName as ICDDescription
				,a.DxCategory
				,'DoD' as TableSourceName
				,NULL as Sta3n
			FROM [ORM].[vwDOD_DxVertical] a WITH (NOLOCK)
			INNER JOIN #Patient AS c ON a.MVIPersonSID = c.MVIPersonSID
			INNER JOIN 
				(
					SELECT DISTINCT ColumnName,PrintName 
					FROM [LookUp].[ColumnDescriptions] WITH (NOLOCK)
					WHERE TableName = 'ICD10'
				) d
				ON a.DxCategory = d.ColumnName
		) u 
	LEFT JOIN [Dim].[VistaSite] c WITH (NOLOCK)
		ON c.Sta3n = u.Sta3n
	WHERE u.DxCategory = @Diagnosis
 
END