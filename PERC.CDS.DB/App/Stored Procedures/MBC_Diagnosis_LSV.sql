 
 
-- =============================================
-- Author:		<Amy Robinson>
-- Create date: <1/24/2017>
-- Description:	Main data date for the Measurement based care report; Used by CRISTAL SSRS reports
-- Updates
--	2019-01-09 - Jason Bacani - Refactored to use MVIPersonSID; Performance tuning; formatting; NOLOCKs; Partition Elimination
--  2019-03-07 - RAS	Removed diagnosis temp table - tested and seems to actually run faster now
--  2019-04-05 - LM - Added MVIPersonSID to initial select statement
--  2019-11-29 - Cora Bernard - Added in Community Care inpatient/outpatient diagnoses
--	2021-05-18 - Jason Bacani - Enclave work - updated [Fee].[FeeInpatInvoiceICDDiagnosis] Synonym use. No logic changes made.	
--  2021-09-13 - Jason Bacani - Enclave Refactoring - Counts confirmed; Added more WITH (NOLOCK) clauses; Added SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
--	2021-09-23 - Jason Bacani - Enclave Refactoring - Removed use of Partition ID
--	2021-10-08 - LM - Pull from Present.Diagnosis instead of PDW tables
--
-- EXEC [App].[MBC_Diagnosis_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @Patient = 1001092794
-- EXEC [App].[MBC_Diagnosis_LSV] @User = 'VHAMASTER\VHAISBBACANJ', @Patient = 1012614757
-- =============================================
CREATE   PROCEDURE [App].[MBC_Diagnosis_LSV]
(
	@User VARCHAR(MAX),
	@Patient VARCHAR(1000)
)	
AS
BEGIN
	SET NOCOUNT ON;
 	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
 
	--For inline testing only
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @Patient = 1018290649
	--DECLARE @User varchar(max), @Patient varchar(1000); SET @User = 'VHAMASTER\VHAISBBACANJ'; SET @Patient = 1012614757
 
	--Get correct permissions using INNER JOIN [App].[Access].  The below use-case is an exception.
	----For documentation on implementing LSV permissions see $OMHSP_PERC\Trunk\Doc\Design\LSVPermissionsForReports.md
	DROP TABLE IF EXISTS #Patient;
	SELECT
		mvi.PatientICN
		,mvi.MVIPersonSID
	INTO #Patient
	FROM [Common].[MVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
	WHERE mvi.PatientICN =  @Patient
		AND EXISTS(SELECT Sta3n FROM [App].[Access] (@User) WHERE Sta3n > 0)
	;
 
	DROP TABLE IF EXISTS #Dx
	SELECT p.PatientICN
		,c.PrintName
		,d.DxCategory
		,c.Category
		,d.Outpat
		,d.Inpat
		,d.PL
		,d.CommCare
	INTO #Dx
	FROM [Present].[Diagnosis] d WITH(NOLOCK)
	INNER JOIN #Patient p WITH(NOLOCK)
		ON d.MVIPersonSID=p.MVIPersonSID
	INNER JOIN [LookUp].[ColumnDescriptions] c WITH (NOLOCK)
		ON d.DxCategory = c.ColumnName
	INNER JOIN [LookUp].[ICD10_Display] dis WITH (NOLOCK)
		ON c.ColumnName=dis.DxCategory
	WHERE dis.ProjectType='CRISTAL' AND c.TableName = 'ICD10'
	
	SELECT DISTINCT
		a.PatientICN, a.TableSourceName, a.PrintName, a.DxCategory, a.Category
	FROM 
		(
			SELECT  
				PatientICN
				,'Problem List (Active)' AS TableSourceName
				,PrintName
				,DxCategory
				,Category
			FROM #Dx WITH (NOLOCK) 
			WHERE PL = 1
 
			UNION ALL
 
			SELECT  
				PatientICN
				,'Inpatient Diagnoses in the Past Year'  AS TableSourceName
				,PrintName
				,DxCategory
				,Category
			FROM #Dx WITH (NOLOCK) 
			WHERE Inpat = 1
 
			UNION ALL
			
			SELECT  
				PatientICN
				,'Outpatient Diagnoses in the Past Year'  AS TableSourceName
				,PrintName
				,DxCategory
				,Category
			FROM #Dx WITH (NOLOCK) 
			WHERE Outpat = 1
 
			UNION ALL
 
			SELECT  
				PatientICN
				,'Community Care Outpatient and Inpatient Diagnoses in the Past Year'  AS TableSourceName
				,PrintName
				,DxCategory
				,Category
			FROM #Dx WITH (NOLOCK) 
			WHERE CommCare = 1
 
		) a 
 
	;
 
END