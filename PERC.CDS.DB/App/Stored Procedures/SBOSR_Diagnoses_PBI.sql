
-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	5/18/2023
-- Description:	Dataset for patient diagnoses in the Suicide Behavior and Overdose Summary Report. Many
--				to Many relationship with [App].[SBOSR_SDVDetails] in the report. To be used in PowerBI 
--				visuals (Clinical/Case Factors).
--
--				Row duplication is expected in this dataset.
--				
-- Modifications:
-- 06-08-2023 CW  Excluding PrintName <> 'Sedate issue' from #Dx
--
-- =======================================================================================================
CREATE PROCEDURE [App].[SBOSR_Diagnoses_PBI]

AS
BEGIN
	
	SET NOCOUNT ON;

	--SBOSR cohort
	DROP TABLE IF EXISTS #Cohort
	SELECT DISTINCT MVIPersonSID, PatientKey
	INTO #Cohort
	FROM SBOSR.SDVDetails_PBI
	
	DROP TABLE IF EXISTS #Dx
	SELECT p.MVIPersonSID
		,p.PatientKey
		,c.PrintName
		,CASE WHEN c.PrintName='Alcohol Use Disorder (comprehensive definition)' THEN 'Alcohol Use Disorder'
			  WHEN c.PrintName='Amphetamine' THEN 'Amphetamine Use Disorder'
			  WHEN c.PrintName like '%Anemia%' THEN 'Anemia'
			  WHEN c.PrintName='Any suicide attempt' THEN 'Suicide Attempt or Ideation'
			  WHEN c.PrintName like '%Bipolar%' THEN 'Bipolar'
			  WHEN c.PrintName like '%Cancer%' THEN 'Cancer'
			  WHEN c.PrintName='Cannabis' THEN 'Cannabis Use Disorder'
			  WHEN c.PrintName='Chronic Pulmonary Dis' THEN 'Chronic Pulmonary Disorder'
			  WHEN c.PrintName='Cocaine' THEN 'Cocaine Use Disorder'
			  WHEN c.PrintName like '%Depression%' THEN 'Depression'
			  WHEN c.PrintName='Menopausal disorder' or c.PrintName='Menstrual disorder' or c.PrintName='Non-viable pregnancy' or c.PrintName='Pregnancy' THEN 'Pregnancy-related disorder'
			  WHEN c.PrintName like '%Opioid%' THEN 'Opioid Use Disorder'
			  WHEN c.PrintName='Rheumatoid Arthritis/Collagen Vascular Disease' THEN 'Rheumatoid Arthritis'
			  WHEN c.PrintName='Sedative' THEN 'Sedative Use Disorder'
			  WHEN c.PrintName='Neurological disorders - Other' THEN 'Neurological disorders'
		 ELSE c.PrintName END AS DiagnosesForVisuals
		,d.DxCategory
		,c.Category
		,d.Outpat
		,d.Inpat
		,d.PL
		,d.CommCare
	INTO #Dx
	FROM [Present].[Diagnosis] d WITH(NOLOCK)
	INNER JOIN #Cohort p WITH(NOLOCK)
		ON d.MVIPersonSID=p.MVIPersonSID
	INNER JOIN [LookUp].[ColumnDescriptions] c WITH (NOLOCK)
		ON d.DxCategory = c.ColumnName
	INNER JOIN [LookUp].[ICD10_Display] dis WITH (NOLOCK)
		ON c.ColumnName=dis.DxCategory
	WHERE dis.ProjectType='CRISTAL' AND c.TableName = 'ICD10' AND c.PrintName <> 'Sedate issue';
	
	SELECT DISTINCT
		 a.MVIPersonSID
		,a.PatientKey
		,a.TableSourceName
		,a.DiagnosesForVisuals
		,a.DxCategory
		,a.Category
	FROM 
		(
			SELECT  
				MVIPersonSID
				,PatientKey
				,'Inpatient Diagnoses in the Past Year'  AS TableSourceName
				,DiagnosesForVisuals
				,DxCategory
				,Category
			FROM #Dx WITH (NOLOCK) 
			WHERE Inpat = 1
 
			UNION ALL
			
			SELECT  
				MVIPersonSID
				,PatientKey
				,'Outpatient Diagnoses in the Past Year'  AS TableSourceName
				,DiagnosesForVisuals
				,DxCategory
				,Category
			FROM #Dx WITH (NOLOCK) 
			WHERE Outpat = 1
 
		) a;

END