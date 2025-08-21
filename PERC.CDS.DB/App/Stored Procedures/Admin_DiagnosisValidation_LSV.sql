/* =============================================
-- Author:		<Amy Robinson>
-- Create date: <9/19/2016>
-- Description:	used in the Diagnosis validation report to show all the encounters, 
     inpatients stay AND problem list entries for a patient for a given diagnosis category.
	 Looks back 380 days for OP AND IP, but any problem list modified date.  
	 Need ICD9 AND ICD10 for Problem List AND some IP that still have ICD9 for some reason
-- Updates
--	2019/01/17 - Jason Bacani - Perf tuning; NOLOCKS; Formatting; Sample queries included; 
--								Reordered the exception clause to be handled quicker when an exception clause occurs;
--								Improved CDS joins to either use appropriate business SID or use MVIPersonSID where possible;
--								CAST 380 Days clause to DATE format for consistent returned results
--	2020/07/28 - LM - Added two-year look-back for REACH diagnoses 
--	2020/10/14 - LM - Overlay of Cerner data
--  2021/09/13 - Jason Bacani - Enclave Refactoring - Counts confirmed; Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
--  2022/08/12 - CMH - Added stop code or specialty code for OP and IP encounters
--	2022/08/22 - LM - Added report parameter
--	2022/09/19 - LM - Removed ICD9 from ouptatient and inpatient queries.  Kept in problem list query since many PL dxs are still in ICD9
--	2024/11/15 - LM - Added ChecklistID
--	2025/02/05 - LM - Added lookup by MVIPersonSID
--  2025/05/21 - AER - Adding standard event data to the drill		
			
 
exec [dbo].[sp_SignAppObject] @ObjectName = 'Admin_DiagnosisValidation_LSV' --Edit the name here to equal you procedure name above EXACTLY

				   
--
-- TEST
--	EXEC [App].[Admin_DiagnosisValidation_LSV]  @User='VHAMASTER\VHAISBBACANJ', @Patient='1000715722'   , @Diagnosis='OUD'  , @PatientType='PatientICN', @NoPHI=1;
--	EXEC [App].[Admin_DiagnosisValidation_LSV]  @User='VHAMASTER\VHAISBBACANJ', @Patient='1000715722'   , @Diagnosis='DUMMY', @PatientType='PatientICN', @Report='CRISTAL', @NoPHI=0;
--	EXEC [App].[Admin_DiagnosisValidation_LSV]  @User='VHAMASTER\VHAISBBACANJ', @Patient='1000715722'   , @Diagnosis='OUD'  , @PatientType='PatientICN', @Report='CRISTAL', @NoPHI=0;
--	EXEC [App].[Admin_DiagnosisValidation_LSV]  @User='VHAMASTER\VHAISBBACANJ', @Patient='2478293'      , @Diagnosis='OUD'  , @PatientType='PatientSID', @Report='CRISTAL', @NoPHI=0;
--	EXEC [App].[Admin_DiagnosisValidation_LSV]  @User='VHAMASTER\VHAISBBACANJ', @Patient='4266028'      , @Diagnosis='OUD'  , @PatientType='PatientSID', @Report='CRISTAL', @NoPHI=0;
--	EXEC [App].[Admin_DiagnosisValidation_LSV]  @User='VHAMASTER\VHAISBBACANJ', @Patient='1202541379'   , @Diagnosis='OUD'  , @PatientType='PatientSID', @Report='CRISTAL'', @NoPHI=0;
--	EXEC [App].[Admin_DiagnosisValidation_LSV]  @User='VHAMASTER\VHAISBBACANJ', @Patient='802393733'    , @Diagnosis='OUD'  , @PatientType='PatientSID', @Report='SPPRITE', @NoPHI=0;
--	EXEC [App].[Admin_DiagnosisValidation_LSV]  @User='VHAPALMINAL', @Patient='47310771'    , @Diagnosis='IntentionalOverdosePoison'  , @PatientType='MVIPersonSID', @Report='REACH', @NoPHI=0;
--	
-- ============================================= */
CREATE PROCEDURE [App].[Admin_DiagnosisValidation_LSV]
(
	@User VARCHAR(MAX),
	@PatientType VARCHAR (100), -- Determines if PatientSID, PatientICN, or PatientSSN
	@Patient VARCHAR(1000),     -- number
	@Diagnosis VARCHAR(100),
	@Report VARCHAR(100),
	@NoPHI VARCHAR(5)
)
AS
BEGIN
	SET NOCOUNT ON; 
 	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
 
	--For inlne testing only
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @Report VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='VHAMASTER\VHAISBBACANJ', @Patient='1018023606'   , @Diagnosis='REACH_Chronic'  , @PatientType='PatientICN', @Report='REACH', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @Report VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='VHAMASTER\VHAISBBACANJ', @Patient='1000715722'   , @Diagnosis='DUMMY', @PatientType='PatientICN', @Report='CRISTAL', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @Report VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='VHAMASTER\VHAISBBACANJ', @Patient='1000715722'   , @Diagnosis='OUD'  , @PatientType='PatientICN', @Report='REACH', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @Report VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='VHAMASTER\VHAISBBACANJ', @Patient='2478293'      , @Diagnosis='OUD'  , @PatientType='PatientSID', @Report='SMI', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @Report VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='VHAMASTER\VHAISBBACANJ', @Patient='4266028'      , @Diagnosis='OUD'  , @PatientType='PatientSID', @Report='PDSI', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @Report VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='VHAMASTER\VHAISBBACANJ', @Patient='1202541379'   , @Diagnosis='OUD'  , @PatientType='PatientSID', @Report='CRISTAL', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @Report VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='VHAMASTER\VHAISBBACANJ', @Patient='802393733'    , @Diagnosis='OUD'  , @PatientType='PatientSID', @Report='REACH', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @Report VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='vha21\vhapalminal', @Patient='800682814'    , @Diagnosis='Bipolar'  , @PatientType='PatientSID', @Report='SMI', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @Report VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='vha21\vhapalminal'    , @Patient='287503829'    , @Diagnosis='EH_HYPERTENS'  , @PatientType='PatientSSN', @Report='CRISTAL', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @Report VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='vha21\vhapalminal'    , @Patient='1600556419'    , @Diagnosis='REACH_sud'  , @PatientType='PatientSID', @Report='REACH', @NoPHI=0;
	--DECLARE @User VARCHAR(MAX), @PatientType VARCHAR (100), @Patient VARCHAR(1000), @Diagnosis VARCHAR(100), @Report VARCHAR(100), @NoPHI VARCHAR(5); SELECT @User='vha21\vhapalminal'    , @Patient='12905520'    , @Diagnosis='PsychoticDisorderOther'  , @PatientType='MVIPersonSID', @Report='REACH', @NoPHI=0;
 
 	-- Verify parameter is a valid column of the target table (ICD9 AND ICD10 tables should have same columns)
	DECLARE @TestForValidInputCount INT;
	SELECT @TestForValidInputCount = COUNT(*)
	FROM  [LookUp].[ColumnDescriptions] c WITH (NOLOCK) 
	WHERE c.ColumnName = @Diagnosis 
		AND c.TableName = 'ICD10'	

	DECLARE @BeginDate date = CASE WHEN @Report IN ('REACH' ,'SMI') THEN CAST((GETDATE() - 761) AS DATE) ELSE CAST((GETDATE() - 380) AS DATE) END
	DECLARE @EndDate date = CAST(getdate() AS date)
 
	--IF THE USER HAS PERMISSION TO THIS PHI, THEN BUILD TABLE WITH ALL DIAGNOSIS DATES FROM OP,IP,Problem List
	--IF THE USER DOES NOT HAVE PHI PERMISSION, DISPLAY SAMPLE
	IF @NoPHI = 0 --AND @TestForValidInputCount > 0  --only run this code if they want to see PHI AND have entered a valid dx input
	BEGIN
 
		DROP TABLE IF EXISTS #Patient;
		SELECT DISTINCT
			spat.PatientICN, sp.PatientPersonSID AS PatientSID, sp.Sta3n, spat.PatientName, spat.PatientSSN, sp.MVIPersonSID, l.Facility
		INTO #Patient
		FROM [Common].[MasterPatient] spat WITH (NOLOCK)
		INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] sp WITH(NOLOCK)
			ON sp.MVIPersonSID = spat.MVIPersonSID
		LEFT JOIN [Present].[ActivePatient] ap WITH(NOLOCK)
			ON spat.MVIPersonSID = ap.MVIPersonSID
			LEFT JOIN [Dim].[VistASite] l WITH (NOLOCK)
			ON sp.Sta3n = l.Sta3n
      INNER JOIN [App].[Access](@User) Access 
			ON sp.Sta3n = Access.Sta3n OR ap.Sta3n_Loc = Access.Sta3n --for cases when Sta3n=200 in the Common table
	
		WHERE 
			(
				(@PatientType = 'PatientICN' AND spat.PatientICN = @Patient) OR
				(@PatientType = 'PatientSSN' AND spat.PatientSSN = CAST(REPLACE(@Patient,'-','')  AS VARCHAR(100))) OR
				(@PatientType = 'PatientSID' AND sp.PatientPersonSID = @Patient) OR
				(@PatientType = 'MVIPersonSID' AND sp.MVIPersonSID = @Patient)
			)
		OPTION (RECOMPILE)
		; 
	
		DROP TABLE IF EXISTS #ICD9SID;
		SELECT ICD9SID as ICDSID,ICD9Code as ICDCode,ICD9Description as ICDDescription
		INTO #ICD9SID
		FROM [LookUp].[ICD9_VerticalSID] WITH (NOLOCK)
		WHERE DxCategory = @Diagnosis
		EXEC [Tool].[CIX_CompressTemp]  '#ICD9SID','ICDSID'
 
		DROP TABLE IF EXISTS #ICD10SID; 
		SELECT ICD10SID as ICDSID,ICD10Code as ICDCode,ICD10Description as ICDDescription
		INTO #ICD10SID
		FROM [LookUp].[ICD10_VerticalSID] WITH (NOLOCK)
		WHERE DxCategory = @Diagnosis
		EXEC [Tool].[CIX_CompressTemp]  '#ICD10SID','ICDSID'

    
    insert into #ICD10SID
   select distinct ICD10SID,Value,Detail 
   from xla.[lib_SetValues_RiskMonthly] as a WITH (NOLOCK)
   inner join LookUp.ICD10 as b  WITH (NOLOCK) on a.[Value] = b.ICD10Code
   where Vocabulary = 'icd10cm' and 
   setterm in (
    'Amputation','AnxietyGeneralized','EatingDisorder','IntentionalSelfHarmIdeation','MoodDisorderOther'
    ,'PainAbdominal','PainOther','PainSystemicDisorder','Parkinsons','PsychosocialProblemsNOS'
    ,'PsychoticDisorderOther','DrugUseDisorderOther','ExternalSelfHarm','IntentionalOverdosePoison'
	) and setterm = @Diagnosis

	insert into #ICD10SID
	select distinct ICD10SID,Value,Detail 
	   from xla.Lib_SuperSets_ALEX s WITH (NOLOCK)
	   INNER JOIN [XLA].[Lib_SetValues_RiskMonthly] as a WITH (NOLOCK)
		ON s.ALEXGUID=a.ALEXGUID
	   inner join LookUp.ICD10 as b  WITH (NOLOCK) on a.[Value] = b.ICD10Code
	   where a.Vocabulary = 'icd10cm' and 
		 superset = @Diagnosis
  
 insert into #ICD10SID  
    select distinct ICD10SID,ICD10Code,ICD10Description
    from LookUp.ICD10 as a 
    inner join (
    select Value,Detail 
   from xla.[lib_SetValues_RiskMonthly] as a  WITH (NOLOCK)
   inner join LookUp.ICD10 as b  WITH (NOLOCK) on a.[Value] = b.ICD10Code
   where Vocabulary = 'icd10cm' and 
   setterm = 'Pregnancy'
   except 
   select Value,Detail 
   from xla.[lib_SetValues_RiskMonthly] as a WITH (NOLOCK) 
   inner join LookUp.ICD10 as b WITH (NOLOCK) on a.[Value] = b.ICD10Code
   where Vocabulary = 'icd10cm' and 
   setterm = 'NonviablePregnancy') as b on icd10code = b.value
   where @Diagnosis = 'ViablePregnancy'


		/*OUTPATIENT*/
		DROP TABLE IF EXISTS #outpats;
		SELECT --DISTINCT 
			c.PatientSID
			,'ICD10' AS DiagnosisSource
			,a.VisitDateTime
			,'' as AdmitDateTime
			,'' as DischargeDateTime
			,1 AS TableSource
			,ic.ICDCode  
			,ic.ICDDescription 
			,'Encounters' AS TableSourceName
			,a.Sta3n
			,ChecklistID=ISNULL(f.ChecklistID,a.Sta3n)
			,f.Facility
			,c.PatientName
			,c.PatientSSN
			,v.PrimaryStopCodeSID
			,v.SecondaryStopCodeSID
		INTO #outpats
		FROM [Outpat].[VDiagnosis] a WITH (NOLOCK)
		INNER JOIN #Patient c ON a.PatientSID = c.PatientSID
		INNER JOIN #ICD10SID ic ON ic.ICDSID = a.ICD10SID
		INNER JOIN [Outpat].[Visit] v WITH (NOLOCK) ON a.VisitSID=v.VisitSID
		LEFT JOIN [Lookup].[DivisionFacility] f ON v.DivisionSID=f.DivisionSID
		WHERE a.VisitDateTime >= @BeginDate AND a.VisitDateTime < @EndDate
		UNION ALL
		SELECT --DISTINCT 
			a.PersonSID AS PatientSID
			,'ICD10' AS DiagnosisSource
			,a.DerivedDiagnosisDateTime
			,'' as AdmitDateTime
			,'' as DischargeDateTime
			,1 AS TableSource
			,ic.ICDCode  
			,ic.ICDDescription 
			,'Encounters' AS TableSourceName
			,Sta3n=200
			,l.ChecklistID
			,l.Facility
			,c.PatientName
			,c.PatientSSN
			,v.CompanyUnitBillTransactionAliasSID AS PrimaryStopCodeSID
			,SecondaryStopCodeSID=''
		FROM [Cerner].[FactDiagnosis] a WITH (NOLOCK)
		INNER JOIN #Patient c ON a.MVIPersonSID = c.MVIPersonSID
		INNER JOIN #ICD10SID ic ON ic.ICDSID = a.NomenclatureSID
		LEFT JOIN [Lookup].[ChecklistID] l WITH (NOLOCK) ON a.STAPA = l.StaPa
		LEFT JOIN [Cerner].[FactUtilizationStopCode] v WITH (NOLOCK) ON a.EncounterSID=v.EncounterSID
		WHERE a.TZDerivedDiagnosisDateTime >= @BeginDate AND a.TZDerivedDiagnosisDateTime < @EndDate
		AND a.SourceVocabulary='ICD-10-CM'
		AND EncounterTypeClass <> 'Inpatient'
		AND ic.ICDSID > 1600000000
		; 

		/*INPATIENT*/
		DROP TABLE IF EXISTS #inpats; 
		SELECT --DISTINCT
			c.PatientSID
			,'ICD10' AS DiagnosisSource
			,'' as VisitDateTime
			,d.AdmitDateTime
			,d.DischargeDateTime
			,2 AS TableSource
			,ic.ICDCode
			,ic.ICDDescription 
			,'Inpatient' AS TableSourceName
			,c.Sta3n
			,b.ChecklistID
			,l.Facility
			,c.PatientName
			,c.PatientSSN
			,t.Specialty
		INTO #inpats
		FROM [Inpat].[InpatientDiagnosis] a WITH (NOLOCK)
		INNER JOIN [Inpat].[Inpatient] d WITH (NOLOCK) ON a.InpatientSID = d.InpatientSID --AND a.MVIPersonSID = d.MVIPersonSID 
		INNER JOIN #Patient c ON a.PatientSID = c.PatientSID
		INNER JOIN #ICD10SID ic ON ic.ICDSID = a.ICD10SID
		LEFT JOIN [Lookup].[TreatingSpecialty] t WITH (NOLOCK) ON d.DischargeSpecialtySID=t.TreatingSpecialtySID
		LEFT JOIN [Inpatient].[BedSection] b WITH (NOLOCK) ON d.InpatientSID = b.InpatientEncounterSID
		LEFT JOIN [Lookup].[ChecklistID] l WITH (NOLOCK) ON b.ChecklistID=l.ChecklistID
		WHERE d.AdmitDateTime >= @BeginDate AND (d.DischargeDateTime < @EndDate OR d.DischargeDateTime IS NULL)
		UNION ALL
		SELECT --DISTINCT 
			a.PersonSID AS PatientSID
			,'ICD10' AS DiagnosisSource
			,a.DerivedDiagnosisDateTime
			,i.DerivedAdmitDateTime
			,i.DischargeDateTime
			,2 AS TableSource
			,ic.ICDCode  
			,ic.ICDDescription 
			,'Inpatient' AS TableSourceName
			,Sta3n=200
			,l.ChecklistID
			,l.Facility
			,c.PatientName
			,c.PatientSSN
			,i.Specialty as Specialty
		FROM [Cerner].[FactDiagnosis] a WITH (NOLOCK)
		INNER JOIN #Patient c ON a.MVIPersonSID = c.MVIPersonSID
		INNER JOIN #ICD10SID ic ON ic.ICDSID = a.NomenclatureSID
		INNER JOIN [Lookup].[ChecklistID] l WITH (NOLOCK) ON a.STAPA = l.StaPa
		INNER JOIN [Cerner].[FactInpatient] i WITH (NOLOCK) ON a.EncounterSID = i.EncounterSID
		WHERE (a.TZDerivedDiagnosisDateTime >= @BeginDate AND (i.TZDischargeDateTime < @EndDate OR i.TZDischargeDateTime IS NULL))
		AND a.SourceVocabulary='ICD-10-CM'
		AND a.EncounterTypeClass = 'Inpatient'
		AND ic.ICDSID > 1600000000
	;
		/*PROBLEM LIST*/
		DROP TABLE IF EXISTS #ProblemList;
		SELECT --DISTINCT
			pt.PatientSID
			,'ICD9' AS DiagnosisSource
			,a.LastModifiedDateTime AS VisitDateTime
			,'' as AdmitDateTime
			,'' as DischargeDateTime
			,3 AS TableSource
			,ic.ICDCode  
			,ic.ICDDescription 
			,'Problem List' AS TableSourceName
			,pt.Sta3n
			,c.ChecklistID
			,c.Facility
			,pt.PatientName
			,pt.PatientSSN
		INTO #ProblemList
		FROM #Patient pt 
		INNER JOIN [Outpat].[ProblemList] a WITH (NOLOCK) ON pt.PatientSID = a.PatientSID
		INNER JOIN #ICD9SID ic ON ic.ICDSID = a.ICD9SID
		LEFT JOIN Dim.Institution i WITH (NOLOCK) ON a.InstitutionSID=i.InstitutionSID
		LEFT JOIN Lookup.ChecklistID c WITH (NOLOCK) ON i.StaPa=c.StaPa
		WHERE a.ActiveFlag = 'A' 
			AND a.ProblemListCondition NOT LIKE '%H%'
			AND @Report = 'CRISTAL'
		UNION ALL
		SELECT --DISTINCT
			pt.PatientSID
			,'ICD10' AS DiagnosisSource
			,a.LastModifiedDateTime AS VisitDateTime
			,'' as AdmitDateTime
			,'' as DischargeDateTime
			,3 AS TableSource 
			,ic.ICDCode  
			,ic.ICDDescription 
			,'Problem List' AS TableSourceName
			,pt.Sta3n
			,c.ChecklistID
			,c.Facility
			,pt.PatientName
			,pt.PatientSSN
		FROM #Patient pt 
		INNER JOIN [Outpat].[ProblemList] AS a WITH (NOLOCK) ON pt.PatientSID = a.PatientSID
		INNER JOIN #ICD10SID ic ON ic.ICDSID = a.ICD10SID
		LEFT JOIN Dim.Institution i WITH (NOLOCK) ON a.InstitutionSID=i.InstitutionSID
		LEFT JOIN Lookup.ChecklistID c WITH (NOLOCK) ON i.StaPa=c.StaPa
		WHERE a.ActiveFlag='A' 
			AND a.ProblemListCondition NOT LIKE '%H%'
			AND @Report = 'CRISTAL'
 
		SELECT DISTINCT a.PatientSID
			,a.DiagnosisSource
			,a.TableSource
			,a.TableSourceName
			,a.ICDcode
			,a.ICDDescription
			,s1.StopCodeName AS PrimaryStopCodeName
			,CASE WHEN s2.StopCodeName='*Unknown at this time*' THEN NULL ELSE s2.StopCodeName END AS SecondaryStopCodeName
			,Specialty=''
			,a.VisitDateTime
			,a.AdmitDateTime
			,a.DischargeDatetime
			,a.PatientName
			,a.PatientSSN
			,a.Sta3n
			,Facility=CONCAT('(',a.ChecklistID,') ',a.Facility)
		FROM #outpats a
		INNER JOIN [Lookup].[StopCode] s1 WITH (NOLOCK) 
			ON a.PrimaryStopCodeSID=s1.StopCodeSID
		LEFT JOIN [Lookup].[StopCode] s2 WITH (NOLOCK) 
			ON a.SecondaryStopCodeSID=s2.StopCodeSID
		UNION ALL
		SELECT DISTINCT PatientSID
			,DiagnosisSource
			,TableSource
			,TableSourceName
			,ICDcode
			,ICDDescription
			,PrimaryStopCodeName=''
			,SecondaryStopCodeName=''
			,Specialty
			,VisitDateTime
			,AdmitDateTime
			,DischargeDatetime
			,PatientName
			,PatientSSN
			,Sta3n
			,Facility=CONCAT('(',ChecklistID,') ',Facility)
		FROM #inpats
		UNION ALL
		SELECT DISTINCT PatientSID
			,DiagnosisSource
			,TableSource
			,TableSourceName
			,ICDcode
			,ICDDescription
			,PrimaryStopCodeName=''
			,SecondaryStopCodeName=''
			,Specialty=''
			,VisitDateTime
			,AdmitDateTime
			,DischargeDatetime
			,PatientName
			,PatientSSN
			,Sta3n
			,Facility=CONCAT('(',ChecklistID,') ',Facility)
		FROM #ProblemList
 UNION ALL
		SELECT DISTINCT PatientSID,
			 DataSource
			,9 as TableSource
			,'Standard Event' as TableSourceName
			,EventType as ICDcode
			,SDVClassification as ICDDescription
			,PrimaryStopCodeName=''
			,SecondaryStopCodeName=''
			,Specialty=''
			,EventDateFormatted VisitDateTime
			,AdmitDateTime=''
			,DischargeDatetime=''
		,PatientName
		,PatientSSN
			,a.Sta3n
			,Facility=CONCAT('(',ChecklistID,') ',Facility)
	 FROM OMHSP_Standard.SuicideOverdoseEvent as a 
   inner join #Patient as b on a.mvipersonsid = b.mvipersonsid and a.sta3n=b.sta3n
   where (@Diagnosis = 'SuicideAttempt' and a.EventType='Suicide Event') or (@Diagnosis = 'NonSuicideOverdose' and a.Overdose = 1)

	END
	ELSE --if they dont want to see PHI run this code instead
	BEGIN
		SELECT TOP 1
			-1 AS PatientSID
			,'ICD10' AS DiagnosisSource
			,1 AS TableSource
			,'Problem List' AS  TableSourceName
			,'F11.20' AS ICDcode
			,'OPIOID DEPENDENCE, UNCOMPLICATED' AS ICDDescription
			,'Primary Care' AS PrimaryStopCodeName
			,'' AS SecondaryStopCodeName
			,'' AS Specialty
			,'04/23/1992' AS VisitDateTime
			,'' AS AdmitDateTime
			,'' AS DischargeDateTime
			,'John Doe' PatientName 
			,'000-00-0000' AS PatientSSN
			,'999' AS Sta3n
			,'(999) Station Name' AS Facility
	END
 
END