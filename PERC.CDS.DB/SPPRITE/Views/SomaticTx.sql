

CREATE VIEW [SPPRITE].[SomaticTx]
AS
/************************************************************************************
Somatic Tx – past 60 days --------------------------------------------
1) rTMS treatment is defined AS CPT codes: 90867, 90868, and 90869
2) ECT treatment is defined AS CPT codes 90870 and 90871  (edit: CMH added codes '4066F' and '00104' on 9/6/23)
3) For Esketamine: search both inpatient and outpatient package
	ESKETAMINE 28MG SOLN,SPRAY,NASAL	
4) For Ketamine: search inpatient package, include any administration with total dose <= 100 mg
	KETAMINE HCL 10MG/ML INJ,SOLN	
	KETAMINE HCL 50MG/ML INJ,SOLN
	KETAMINE HCL 100MG/ML INJ,SOLN
	KETAMINE HCL 50MG/ML INJ,SYRINGE,2ML	

NOTE: AS of 4/21/2020, we are only including the top 3 cohorts - still working out the IV Ketamine and this will be released later

CPT codes for rTMS and ECT

UPDATES:
	2021-09-17	JEB	Enclave Refactoring
	2023-09-06  CMH Added ECT codes '4066F' and '00104' to match Eric Hermes's group

************************************************************************************/

	SELECT -- Retain most recent DATE of any treatment
		rn.MVIPersonSID
		,CAST(rn.SomaticTx_Date AS DATE) AS SomaticTx_Date
		,rn.ChecklistID
		,rn.SomaticTx_Type
		,ROW_NUMBER() OVER (PARTITION BY rn.MVIPersonSID ORDER BY rn.SomaticTx_Date DESC) AS TxOrderDesc 
	FROM 
		( 	
			SELECT	
				mvi.MVIPersonSID
				,a.VisitDateTime AS SomaticTx_Date
				,f.ChecklistID 
				,CASE WHEN c.CPTcode IN ('90867', '90868', '90869') THEN 'rTMS' ELSE 'ECT' END AS SomaticTx_Type
			FROM [Outpat].[VProcedure] a WITH (NOLOCK)
			INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON a.PatientSID = mvi.PatientPersonSID 
			INNER JOIN [Outpat].[Visit] b WITH (NOLOCK) ON a.VisitSID=b.VisitSID
			INNER JOIN [Dim].[CPT] c WITH (NOLOCK) ON a.CPTSID=c.CPTSID
			INNER JOIN [Dim].[Division] d WITH (NOLOCK) ON b.DivisionSID=d.DivisionSID
			LEFT JOIN [LookUp].[Sta6a] e WITH (NOLOCK) ON d.Sta6a=e.Sta6a
			LEFT JOIN [LookUp].[ChecklistID] f WITH (NOLOCK) ON e.ChecklistID=f.ChecklistID
			WHERE a.VisitDateTime >= DATEADD(D,-61,CAST(GetDate() AS DATE))
				AND c.CPTCode IN ('90867', '90868', '90869', '90870', '90871', '4066F', '00104')
				AND a.WorkloadLogicFlag='Y'

			UNION ALL
			--Outpat meds 
			SELECT 
				mvi.MVIPersonSID
				,a.IssueDate AS SomaticTx_Date
				,c.ChecklistID
				,'ESKETAMINE 28 MG' AS SomaticTx_Type
			FROM [RxOut].[RxOutpatFill] a WITH (NOLOCK)
			INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON a.PatientSID = mvi.PatientPersonSID 
			LEFT JOIN [LookUp].[Sta6a] b WITH (NOLOCK) ON a.PrescribingSta6a=b.STA6A
			LEFT JOIN [LookUp].[ChecklistID] c WITH (NOLOCK) ON b.ChecklistID=c.ChecklistID
			WHERE IssueDate >= DATEADD(D,-61,CAST(GetDate() AS DATE))
				AND (a.LocalDrugNameWithDose = 'ESKETAMINE 28MG SOLN,SPRAY,NASAL' 
					OR a.LocalDrugNameWithDose='ESKETAMINE 28MG NASAL SOLN SPRAY')

			UNION ALL
			--Inpat meds 
			SELECT 
				mvi.MVIPersonSID
				,ml.ActionDateTime AS SomaticTx_Date
				,c.ChecklistID 
				,'ESKETAMINE 28 MG' AS SomaticTx_Type
			FROM [BCMA].[BCMAMedicationLog] ml WITH (NOLOCK) 
			INNER JOIN [Common].[vwMVIPersonSIDPatientPersonSID] mvi WITH (NOLOCK) 
				ON ml.PatientSID = mvi.PatientPersonSID 
			INNER JOIN [BCMA].[BCMADispensedDrug] d WITH (NOLOCK) ON ml.BCMAMedicationLogSID=d.BCMAMedicationLogSID
			INNER JOIN [Dim].[LocalDrug] l WITH (NOLOCK) ON d.LocalDrugSID=l.LocalDrugSID 
			INNER JOIN [Dim].[NationalDrug] nd WITH (NOLOCK) ON l.NationalDrugSID=nd.NationalDrugSID
			LEFT JOIN (SELECT DISTINCT ChecklistID, Facility FROM [LookUp].[ChecklistID] WITH (NOLOCK) WHERE ChecklistID=CAST(STA3N AS VARCHAR)) c ON ml.sta3n=c.ChecklistID
			WHERE ml.ActionDateTime >= DATEADD(D,-61,CAST(GetDate() AS DATE))
				AND d.ActionDateTime >= DATEADD(D,-61,CAST(GetDate() AS DATE))
				AND (nd.DrugNameWithDose = 'ESKETAMINE 28MG SOLN,SPRAY,NASAL' or nd.DrugNameWithDose = 'ESKETAMINE 28MG NASAL SOLN SPRAY')
		) rn