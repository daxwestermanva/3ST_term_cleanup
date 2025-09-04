-- =======================================================================================================
---- Author:  Christina Wade
---- Create date: 2/10/2023
---- Description: Generating 5 most recent UDS lab results in the past 2 years.
----				- PrintNameLabResults based on logic from [Code].[PredictorPool_UrineDrugScreen]
----				- Using ADS as the data source.
----
---- Modification:
---- 3/1/2023  - CW  Changing data source to  [PDW].[PBM_AD_DOEx_Chem_LabChem_DrugScreens_2Y]
---- 7/17/2023 - CW  Updating logic that classifies PrintNameLabResults
---- 5/29/2024 - CW  Updating code so that Sta3n 612 maps to 612A4. Discussed with Michael Harvey and this
----				 seems to be the only station mismapping based on their rules.
---- 4/30/2025 - CW  Accounting for mis-mapped station: 589A6.
----				 Updating so ChecklistID correctly maps to 589A5 (Eastern Kansas)
-- =======================================================================================================
CREATE PROCEDURE [Code].[Present_UDSLabResults]

AS
BEGIN

-------------------------------------
-- Get drug screen lab results
-------------------------------------
DROP TABLE IF EXISTS #UDSLabResults
	SELECT
		 MVIPersonSID
		,PatientICN
		,sta3n
		,ChecklistID=CASE WHEN ChecklistID like '612' THEN '612A4' WHEN ChecklistID like '589A6' THEN '589A5' ELSE ChecklistID END --[PDW].[PBM_AD_DOEx_Chem_LabChem_DrugScreens_2Y] is mis-mapping 589A6 to Leavenworth, KS
		,LabDate
		,LabGroup
		,LabResults
		,PrintNameLabResults
		,LabRank
		,UDS
		,CASE	WHEN PrintNameLabResults = 'NEGATIVE'		THEN 0
				WHEN PrintNameLabResults = 'POSITIVE'		THEN 1
				WHEN PrintNameLabResults = 'UNSPECIFIED'	THEN 2
				WHEN PrintNameLabResults = 'NA'				THEN -1
				WHEN PrintNameLabResults = 'UNKNOWN'		THEN -99
		END AS LabScore
	INTO #UDSLabResults
	FROM (
		SELECT DISTINCT 
			 m.MVIPersonSID
			,l.PatientICN
			,l.sta3n
			,l.StationParentCode as ChecklistID
			,l.LabDate
			,l.LabChemResultValue as LabResults
			,l.UDTGroup as LabGroup
			,UDS=1
			,ROW_NUMBER() OVER (PARTITION BY m.MVIPersonSID, l.UDTGroup ORDER BY l.LabDate DESC) as LabRank
			,CASE WHEN
			/* 0=Negative, 1=Positive, 2=Numeric/Unspecific, -1=NA, -99=Unknown */
			--Negative
				   l.LabChemResultValue like'<%'				--less than means not detected
				OR l.LabChemResultValue like '%Negative%' 
				OR l.LabChemResultValue like '%Negative%' 
				OR l.LabChemResultValue like '%NEGATIVE CONFIRMED%'
				OR l.LabChemResultValue like '%Negative%' 
				OR l.LabChemResultValue like '%Negative%' 
				OR l.LabChemResultValue like '%NEG' 
				OR l.LabChemResultValue like '%Neagtive%' 
				OR l.LabChemResultValue like '%Nedative%' 
				OR l.LabChemResultValue like '%NEGAITVE%' 
				OR l.LabChemResultValue like '%NEGATIAVE%' 
				OR l.LabChemResultValue like '%NEGATVIE%' 
				OR l.LabChemResultValue like '%NEGTAIVE%' 
				OR l.LabChemResultValue like '%NEGTIAVE%'
				OR l.LabChemResultValue like '%NEGTIVE%'
				OR l.LabChemResultValue like '%NEHGATIVE%'
				OR l.LabChemResultValue like 'Netagive'
				OR l.LabChemResultValue like '%Ngeative%'
				OR l.LabChemResultValue like '%NON-DET%'
				OR l.LabChemResultValue like '%None Det%'
				OR l.LabChemResultValue like 'None Dectected'
				OR l.LabChemResultValue like '%NONE-DETECTED%'
				OR l.LabChemResultValue like '%NOT DET%'
				OR l.LabChemResultValue like '%NOT-DETECTED%'
				OR l.LabChemResultValue like '%NotDetected%'
				OR l.LabChemResultValue like 'N'
				OR l.LabChemResultValue like 'ND'
				OR l.LabChemResultValue like 'NEGTATIVE'
				OR l.LabChemResultValue like 'NGATIVE'
				OR l.LabChemResultValue like 'Undetec'
				OR l.LabChemResultValue like 'NEG.'
				OR l.LabChemResultValue like '%NEG%'
				OR l.LabChemResultValue like 'ABSENT'
				OR l.LabChemResultValue like 'N.D.'				--not detected?
				OR l.LabChemResultValue like 'None Seen'
				OR l.LabChemResultValue like 'None Det%'
				OR l.LabChemResultValue like 'NoneDet%'
				OR l.LabChemResultValue like 'Non Det%'
				OR l.LabChemResultValue like 'none'
				OR l.LabChemResultValue like 'Netaive'
				OR l.LabChemResultValue like 'NETATIVE'
				OR l.LabChemResultValue like 'N EGATIVE'
				OR l.LabChemResultValue like 'not dectected'
				OR l.LabChemResultValue like 'Nregative'					
				OR l.LabChemResultValue like 'NEWG'				
				OR l.LabChemResultValue like 'No Drug%'
				OR l.LabChemResultValue like 'NO%DETECTED%'
						THEN 'NEGATIVE'
			--Positive
				WHEN 
					l.LabChemResultValue like '%***POS%'  
				OR l.LabChemResultValue like '%SCREE POS%'
				OR l.LabChemResultValue like 'P'
				OR l.LabChemResultValue like '%SCREEN POS%'
				OR l.LabChemResultValue like '>%'				--generic pattern for detected
				OR l.LabChemResultValue like '%POSITIVE%'
				OR l.LabChemResultValue like 'pos'
				OR l.LabChemResultValue like 'Detected%'		--removed % wildcard at the beginning to prevent misclassification
				OR l.LabChemResultValue like 'POSITVE' 
				OR l.LabChemResultValue like 'POSTIVE' 
				OR l.LabChemResultValue like 'PRESUMPTIVE POS' 
				OR l.LabChemResultValue like 'SCRN POS' 
				OR l.LabChemResultValue like 'PRES POS' 
				OR l.LabChemResultValue like '*POS'
				OR l.LabChemResultValue like 'PRESUMP_POS'
				OR l.LabChemResultValue like 'PRESUMPPOS'
				OR l.LabChemResultValue like 'PRESUMP POS'
				OR l.LabChemResultValue like 'Presumptive Pos.'
				OR l.LabChemResultValue like 'SCRNPOS'
				OR l.LabChemResultValue like '*POS'
				OR l.LabChemResultValue like 'POS.'
				OR l.LabChemResultValue like '*POS100.0'
				OR l.LabChemResultValue like 'PresumptvePOS'
				OR l.LabChemResultValue like 'POS=>300'
				OR l.LabChemResultValue like 'POS%'
				OR l.LabChemResultValue like 'PRESPOS'
				OR l.LabChemResultValue like 'PRESENT'
				OR l.LabChemResultValue like 'PRES_SCR_POS'
				OR l.LabChemResultValue like '*POS%'
				OR l.LabChemResultValue like 'PRESUMP POSITIV'
				OR l.LabChemResultValue like 'Presumptive Pos%'
				OR l.LabChemResultValue like '%POS'
				OR l.LabChemResultValue like '%H'				--value + H - high?
				OR l.LabChemResultValue like '%H)'				--value + H - high? 
				OR l.LabChemResultValue like 'PHENOBARBITAL DETECTED'
				OR l.LabChemResultValue like 'DRUG(S) DETECTED:'
				OR l.LabChemResultValue like 'DET'
						THEN 'POSITIVE'
				--Numeric/Unspecified
				WHEN
					l.LabChemResultValue like '%[0-9]%'
						THEN 'UNSPECIFIED'
				--NA
				WHEN 
					l.LabChemResultValue like 'comment'  
				OR l.LabChemResultValue like 'TNP'				--test not performed
				OR l.LabChemResultValue like 'Sent For Confirmation'  
				OR l.LabChemResultValue like 'pending'  
				OR l.LabChemResultValue like 'See Final Results' 
				OR l.LabChemResultValue like 'See Note' 
				OR l.LabChemResultValue like 'Canc%' 
				OR l.LabChemResultValue like 'SEE COMMENT' 
				OR l.LabChemResultValue like 'NONREPORTABLE' 
				OR l.LabChemResultValue like 'Reflex testing not required' 
				OR l.LabChemResultValue like 'N/A' 
				OR l.LabChemResultValue like 'NULL' 
				OR l.LabChemResultValue like 'DNR' 
				OR l.LabChemResultValue like 'Final Results' 
				OR l.LabChemResultValue like '%INTERFERENCE%' 
				OR l.LabChemResultValue like 'NA' 
				OR l.LabChemResultValue like 'N.A.'
				OR l.LabChemResultValue like 'NOT%PERF%'
				OR l.LabChemResultValue like 'NOT PEFORMED'
				OR l.LabChemResultValue like 'NOT PREFORMED'
				OR l.LabChemResultValue like 'Comment:' 
				OR l.LabChemResultValue like 'Complete' 
				OR l.LabChemResultValue like 'Final Results' 
				OR l.LabChemResultValue like 'SEE FINAL REPORT' 
				OR l.LabChemResultValue like 'SEE SCANNED REPORT' 
				OR l.LabChemResultValue like 'The presumptive screen for' 
				OR l.LabChemResultValue like 'TNP202' 
				OR l.LabChemResultValue like 'DNR'			--Did not receive
				OR l.LabChemResultValue like 'NR'			--not received
				OR l.LabChemResultValue like 'NSER'			--No serum received??? (maybe)
				OR l.LabChemResultValue like 'QNS'			--quantity not sufficient
				OR l.LabChemResultValue like 'RTP'			--Reflex test performed (the confirmation was performed)
				OR l.LabChemResultValue like '"SEE VISTA IMAGING FOR RESULTS"'  
				OR l.LabChemResultValue like 'SENT OUT FOR CONFIRM.'  
				OR l.LabChemResultValue like 'Conf Sent'  
				OR l.LabChemResultValue like 'Not Applicable'  
				OR l.LabChemResultValue like 'SentForConfirmation'  
				OR l.LabChemResultValue like 'SEENOTE'  
				OR l.LabChemResultValue like 'PEND_CONF'  
				OR l.LabChemResultValue like 'Specimen Collected'  
				OR l.LabChemResultValue like 'FINAL'  
				OR l.LabChemResultValue like 'INCONSISTENT'  
				OR l.LabChemResultValue like 'SEE BELOW'  
				OR l.LabChemResultValue like 'Pending/conf'  
				OR l.LabChemResultValue like 'INCONSISTENT'  
				OR l.LabChemResultValue like 'INCONSISTENT'  
				OR l.LabChemResultValue like 'INCONSISTENT'  
				OR l.LabChemResultValue like 'SEE LABCORP REP'  
				OR l.LabChemResultValue like 'PP'			--John Forno - Can’t tell for sure (probably means Presumptive Positive)
				OR l.LabChemResultValue like 'CONSISTENT'   --John Forno - Can’t tell for sure (Could mean screen and reflex matched as positive)
				OR l.LabChemResultValue like 'PRELIM'		--John Forno - Sent for reflex/confirmation testing
				OR l.LabChemResultValue like 'Reflexed'     --John Forno - Sent for reflex/confirmation testing
				OR l.LabChemResultValue like 'See Interp'   --John Forno - Resulted as text in the comment field (I don’t think CDW picks up this field from Vista)
				OR l.LabChemResultValue like 'I'			--John Forno - Can’t tell for sure (icteric, incomplete, inside normal range…)
				OR l.LabChemResultValue like 'C'			--John Forno - Can’t tell for sure (collected, completed, cancelled…)
				OR l.LabChemResultValue like 'A'			--John Forno - Can’t tell for sure (abnormal, add reflex test…)
				OR l.LabChemResultValue like 'NOT'          --John Forno - Can’t tell for sure (not ordered, not completed, not received…) 
				THEN 'NA'
				--Unknown
				ELSE 'UNKNOWN' 
				END AS PrintNameLabResults
		FROM [PDW].[PBM_AD_DOEx_Chem_LabChem_DrugScreens_2Y] l WITH (NOLOCK)
		INNER JOIN Common.MasterPatient m WITH (NOLOCK)
			ON l.PatientICN=m.PatientICN
		) Src

	--Need to work in Amy's logic about whether we'd expect to see positive/neg results based on prescriptions

EXEC [Maintenance].[PublishTable] 'Present.UDSLabResults','#UDSLabResults';

END