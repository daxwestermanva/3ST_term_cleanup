/*
Use this file to manage synonyms that refer to objects in Core that serve as 
the abstraction layer for the objects in PDW: OMHSP_PERC_PDW

NAMING CONVENTION: Same schema and name as object in Core (PDW schema).

NOTE: Add new synonyms in the correct alphabetical order.

MODIFICATIONS:
	YYYY-MM-DD	ABC Comments
	2024-10-25	JEB D&A PERC Support - Adding Synonym for A01 OMHSP_MIRECC DOEx SPEDCohort, per Catherine Barry, ticket CDW-11646/PSRM-108
	2024-10-25	JEB D&A PERC Support - Removing EDH/EDoH Synonyms. See synPDW_ORNL_SDoH.sql for the proper Synonyms 
	2024-12-23	JEB D&A PERC Support - Archiving older comments, refer to source control history; Removed OMHSP_FY* and *_NG Synonyms; Sorting Synonyms in Alphabetical Order
	2024-12-23	JEB D&A PERC Support - Adding newest quarterly A06 CDWWork Synonyms, requested by Shalini, per CDW-12483/PSRM-110
	2025-01-15	JEB D&A PERC Support - Adding Synonym for NEPEC_MHICM DOEx SP2_TH_Visits, requested by Catherine, per CDW-12918/PSRM-112
	2025-02-11	SGK	D&A PERC Support - Adding Synonym for BISL_GIS_SpatialData_DOEx_v_ZipCodeNearestFacility_NG, requested by Shalini, per email
	2025-03-04	JEB D&A PERC Support - Adding Synonyms for A01 PBM_AD DOEx Naloxone sources, requested by Christina, per CDW-14185/PSRM-115
									   Adding Synonym for A06 CDWWork ecams_replica ad_claim_header, Requested by Shalini, per CDW-14189/PSRM-117
	2025-03-13	JEB D&A PERC Support - Adding Synonyms for SQL20 NEPEC_PRRC DOEx ICMHRTemplateSegmentOfCare, requested by Susana, per CDW-14450/PSRM-119
	2025-03-14	JEB D&A PERC Support - Adding Synonym for A01 PCO_CRHQM DOEx CRH_SiteProviders, requested by Elena, per CDW-14568/PSRM-120
	2025-03-14	JEB D&A PERC Support - Adding Synonym for A01 LSV PBM_Analytics PPSN_NDC source, per Amy, from Wednesday Architect call
	2025-03-27	JEB D&A PERC Support - Adding Synonym for A06 CDWWork ivc_cds CDS_CC_DimFacility source, per Shalini, per CDW-14868/PSRM-121
	2025-04-14	JEB D&A PERC Support - Cleaning up PDW DACPAC and removing Synonyms pointing to invalid PDW Sources. CDW-15054
	2025-04-24	SGK D&A PERC Support - Adding Synonym for A01 OPP_MAHSO DOEx vw_ref_fips_to_sector_by23 source, requested by Elena, per CDW-15658/PSRM-126
	2025-04-25	JEB D&A PERC Support - Adding Synonyms (14 out of 16 requested) for A01 A01 VCL_Medoraforce Perc sources, requested by Liam, per CDW-15668/PSRM-127
	2025-05-01  JEB D&A PERC Support - Re adding BISL_GIS_SpatialData_DOEx_v_ZipCodeNearestFacility_NG synonyn, removed by mistake by Jason
	2025-05-20	SGK D&A PERC Support - Adding Synonym for A01 OMHSP_MIRECC DOEx MHDischarge source, requested by Catherine, per CDW-16073/PSRM-128
	2025-06-05	RAS - Adding Synonym for A01 PBM_AD_DOEx_Staging_Institutions, requested by Claire, per CDW-16175. Removing OMHSP_VCLDATAWG_PROD_DOEx_PERC_CL_HotlineCalls per Liam
	2025-07-09	RAS - Adding synonym MillCDS_FactNoteSafetyPlansRaw (source from SQL53 OMHSP_PERC)
	2025-08-05	RAS - Removing all OMHSP_VCLDATAWG objects
	2025-08-11	RAS - Adding synonym for VCL_Medoraforce_Perc_VCL_Form_Data__c. Removing OMHO_STORM_Outbox_Evaluation_Randomization because source object does not exist in PDW.
	2025-08-11	RAS - Adding synonym for GEC_GECDACA_Ext_DOEx_HBPC_Master_File_Annual
*/
CREATE SYNONYM [PDW].[BISL_GIS_SpatialData_DOEx_MILLSCDS_FactPatientContactInfoEnhanced] FOR [$(OMHSP_PERC_PDW)].[App].[BISL_GIS_SpatialData_DOEx_MILLSCDS_FactPatientContactInfoEnhanced]
GO
CREATE SYNONYM [PDW].[BISL_GIS_SpatialData_DOEx_v_ZipCodeNearestFacility_NG] FOR [$(OMHSP_PERC_PDW)].[App].[BISL_GIS_SpatialData_DOEx_v_ZipCodeNearestFacility_NG]
GO
CREATE SYNONYM [PDW].[BISL_NST_Mart_DOEx_CaseDetail] FOR [$(OMHSP_PERC_PDW)].[App].[BISL_NST_Mart_DOEx_CaseDetail]
GO
CREATE SYNONYM [PDW].[BISL_NST_Mart_DOEx_CaseLabChem] FOR [$(OMHSP_PERC_PDW)].[App].[BISL_NST_Mart_DOEx_CaseLabChem]
GO
CREATE SYNONYM [PDW].[BISL_NST_Mart_DOEx_CaseLabPanel] FOR [$(OMHSP_PERC_PDW)].[App].[BISL_NST_Mart_DOEx_CaseLabPanel]
GO
CREATE SYNONYM [PDW].[BISL_NST_Mart_DOEx_Dim_Metric] FOR [$(OMHSP_PERC_PDW)].[App].[BISL_NST_Mart_DOEx_Dim_Metric]
GO
CREATE SYNONYM [PDW].[BISL_NST_Mart_DOEx_MetricLog] FOR [$(OMHSP_PERC_PDW)].[App].[BISL_NST_Mart_DOEx_MetricLog]
GO
CREATE SYNONYM [PDW].[BISL_NST_Mart_DOEx_VaccineSummary] FOR [$(OMHSP_PERC_PDW)].[App].[BISL_NST_Mart_DOEx_VaccineSummary]
GO
CREATE SYNONYM [PDW].[BISL_SSRSLog_DOEx_ExecutionLog] FOR [$(OMHSP_PERC_PDW)].[App].[BISL_SSRSLog_DOEx_ExecutionLog]
GO
CREATE SYNONYM [PDW].[BISL_SSRSLog_DOEx_ExecutionLog_ReportHealthStats]  FOR [$(OMHSP_PERC_PDW)].[App].[BISL_SSRSLog_DOEx_ExecutionLog_ReportHealthStats] 
GO
CREATE SYNONYM [PDW].[BISL_SSRSLog_DOEx_Reports] FOR [$(OMHSP_PERC_PDW)].[App].[BISL_SSRSLog_DOEx_Reports]
GO
CREATE SYNONYM [PDW].[CAN_Reporting_Share_Share_can_weekly_report_v3_recent] FOR [$(OMHSP_PERC_PDW)].[App].[CAN_Reporting_Share_Share_can_weekly_report_v3_recent]
GO
CREATE SYNONYM [PDW].[CBOPC_PA_DOEx_ECREmergencyReferrals] FOR [$(OMHSP_PERC_PDW)].[App].[CBOPC_PA_DOEx_ECREmergencyReferrals]
GO
CREATE SYNONYM [PDW].[CDWWork_ccrs_CLAIM_LINE_ADJUDICATION_Quarterly] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_ccrs_CLAIM_LINE_ADJUDICATION_Quarterly] 
GO
CREATE SYNONYM [PDW].[CDWWork_CCRS_DIM_BILL_TYPE] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_CCRS_DIM_BILL_TYPE] 
GO
CREATE SYNONYM [PDW].[CDWWork_ccrs_DIM_DIAGNOSIS_CODE] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_ccrs_DIM_DIAGNOSIS_CODE] 
GO
CREATE SYNONYM [PDW].[CDWWork_ccrs_DIM_NDC_PRODUCT] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_ccrs_DIM_NDC_PRODUCT] 
GO
CREATE SYNONYM [PDW].[CDWWork_ccrs_DIM_PLACE_OF_SERVICE] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_ccrs_DIM_PLACE_OF_SERVICE] 
GO
CREATE SYNONYM [PDW].[CDWWork_ccrs_DIM_PROCEDURE_CODE] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_ccrs_DIM_PROCEDURE_CODE] 
GO
CREATE SYNONYM [PDW].[CDWWork_ccrs_DIM_REVENUE_CODE] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_ccrs_DIM_REVENUE_CODE] 
GO
CREATE SYNONYM [PDW].[CDWWork_ccrs_DIM_VA_CLAIM_Quarterly] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_ccrs_DIM_VA_CLAIM_Quarterly] 
GO
CREATE SYNONYM [PDW].[CDWWork_ccrs_SEOC] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_ccrs_SEOC] 
GO
CREATE SYNONYM [PDW].[CDWWork_Dim_VAST] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_Dim_VAST]
GO
CREATE SYNONYM [PDW].[CDWWork_Dss_OUT_stop651] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_Dss_OUT_stop651]
GO
CREATE SYNONYM [PDW].[CDWWork_DSS_WF_PaidAndVCNV] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_DSS_WF_PaidAndVCNV]
GO
CREATE SYNONYM [PDW].[CDWWork_ecams_replica_ad_claim_header_Quarterly] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_ecams_replica_ad_claim_header_Quarterly]
GO
CREATE SYNONYM [PDW].[CDWWork_ecams_replica_ad_claim_line_Quarterly] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_ecams_replica_ad_claim_line_Quarterly]
GO
CREATE SYNONYM [PDW].[CDWWork_ivc_cds_CDS_CC_DimFacility] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_ivc_cds_CDS_CC_DimFacility] 
GO
CREATE SYNONYM [PDW].[CDWWork_ivc_cds_CDS_CC_DimPatientDemographics] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_ivc_cds_CDS_CC_DimPatientDemographics] 
GO
CREATE SYNONYM [PDW].[CDWWork_IVC_CDS_CDS_Claim_Diagnosis] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_IVC_CDS_CDS_Claim_Diagnosis] 
GO
CREATE SYNONYM [PDW].[CDWWork_IVC_CDS_CDS_Claim_Diagnosis_Historic20240409] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_IVC_CDS_CDS_Claim_Diagnosis_Historic20240409]
GO
CREATE SYNONYM [PDW].[CDWWork_ivc_cds_CDS_Claim_Diagnosis_Quarterly] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_ivc_cds_CDS_Claim_Diagnosis_Quarterly]
GO
CREATE SYNONYM [PDW].[CDWWork_IVC_CDS_CDS_Claim_Header] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_IVC_CDS_CDS_Claim_Header] 
GO
CREATE SYNONYM [PDW].[CDWWork_IVC_CDS_CDS_Claim_Line] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_IVC_CDS_CDS_Claim_Line] 
GO
CREATE SYNONYM [PDW].[CDWWork_IVC_CDS_CDS_Claim_Line_Historic20240409] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_IVC_CDS_CDS_Claim_Line_Historic20240409]
GO
CREATE SYNONYM [PDW].[CDWWork_ivc_cds_CDS_Claim_Line_Quarterly] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_ivc_cds_CDS_Claim_Line_Quarterly]
GO
CREATE SYNONYM [PDW].[CDWWork_ivc_cds_CDS_Claim_Procedure_Quarterly] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_ivc_cds_CDS_Claim_Procedure] 
GO
CREATE SYNONYM [PDW].[CDWWork_IVC_CDS_CDS_Claim_Status] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_IVC_CDS_CDS_Claim_Status] 
GO
CREATE SYNONYM [PDW].[CDWWork_ivc_cds_CDS_Referrals_DimCatOfCareGroupMapping] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_ivc_cds_CDS_Referrals_DimCatOfCareGroupMapping] 
GO
CREATE SYNONYM [PDW].[CDWWork_ivc_cds_CDS_Referrals_Fact] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_ivc_cds_CDS_Referrals_Fact] 
GO
CREATE SYNONYM [PDW].[CDWWork_IVC_CDS_Data_Dictionaries] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_IVC_CDS_Data_Dictionaries]
GO
CREATE SYNONYM [PDW].[CDWWork_JVPN_Appointments] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_JVPN_Appointments]
GO
CREATE SYNONYM [PDW].[CDWWork_JVPN_CAPER] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_JVPN_CAPER]
GO
CREATE SYNONYM [PDW].[CDWWork_JVPN_DirectInpat] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_JVPN_DirectInpat]
GO
CREATE SYNONYM [PDW].[CDWWork_JVPN_JVPN] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_JVPN_JVPN]
GO
CREATE SYNONYM [PDW].[CDWWork_JVPN_NetworkInpat] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_JVPN_NetworkInpat]
GO
CREATE SYNONYM [PDW].[CDWWork_JVPN_NetworkOutpat] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_JVPN_NetworkOutpat]
GO
CREATE SYNONYM [PDW].[CDWWork_JVPN_RX] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_JVPN_RX]
GO
CREATE SYNONYM [PDW].[CDWWork_JVPN_TriSTORM] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_JVPN_TriSTORM]
GO
CREATE SYNONYM [PDW].[CDWWork_JVPN_TSWF] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_JVPN_TSWF]
GO
CREATE SYNONYM [PDW].[CDWWork_JVPN_VARegistry] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_JVPN_VARegistry]
GO
CREATE SYNONYM [PDW].[CDWWork_OMOPV5_CONCEPT] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_OMOPV5_CONCEPT] 
GO
CREATE SYNONYM [PDW].[CDWWork_OMOPV5_CONCEPT_ANCESTOR] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_OMOPV5_CONCEPT_ANCESTOR] 
GO
CREATE SYNONYM [PDW].[CDWWork_OMOPV5_CONCEPT_RELATIONSHIP] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_OMOPV5_CONCEPT_RELATIONSHIP] 
GO
CREATE SYNONYM [PDW].[CDWWork_OMOPV5_DRUG_STRENGTH] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_OMOPV5_DRUG_STRENGTH] 
GO
CREATE SYNONYM [PDW].[CDWWork_SDAF_DAFMaster] FOR [$(OMHSP_PERC_PDW)].[App].[CDWWork_SDAF_DAFMaster]
GO
CREATE SYNONYM [PDW].[CRISTAL_TIU_SafetyPlanNotes] FOR [$(OMHSP_PERC_PDW)].[App].[CRISTAL_TIU_SafetyPlanNotes_v03]
GO
CREATE SYNONYM [PDW].[DoEX_MHMS_AllDashboardMeasures] FOR [$(OMHSP_PERC_PDW)].[App].[DoEX_MHMS_AllDashboardMeasures]
GO
CREATE SYNONYM [PDW].[DoEX_MHMS_MeasureID] FOR [$(OMHSP_PERC_PDW)].[App].[DoEX_MHMS_MeasureID]
GO
CREATE SYNONYM [PDW].[DoEX_MHMS_MeasureStatistics] FOR [$(OMHSP_PERC_PDW)].[App].[DoEX_MHMS_MeasureStatistics]
GO
CREATE SYNONYM [PDW].[DWS_Log_ExecutionVariableLog] FOR [$(OMHSP_PERC_PDW)].[App].[DWS_Log_ExecutionVariableLog]
GO
CREATE SYNONYM [PDW].[DWS_Log_vwExecutionErrorLog] FOR [$(OMHSP_PERC_PDW)].[App].[DWS_Log_vwExecutionErrorLog]
GO
CREATE SYNONYM [PDW].[DWS_Log_vwExecutionLog] FOR [$(OMHSP_PERC_PDW)].[App].[DWS_Log_vwExecutionLog]
GO
CREATE SYNONYM [PDW].[DWS_Log_vwExecutionTaskLog] FOR [$(OMHSP_PERC_PDW)].[App].[DWS_Log_vwExecutionTaskLog]
GO
CREATE SYNONYM [PDW].[DWS_Log_vwExecutionVariableLog] FOR [$(OMHSP_PERC_PDW)].[App].[DWS_Log_vwExecutionVariableLog]
GO
CREATE SYNONYM [PDW].[DWS_Meta_DWSTable] FOR [$(OMHSP_PERC_PDW)].[App].[DWS_Meta_DWSTable]
GO
CREATE SYNONYM [PDW].[GEC_GECDACA_DOEx_HBPCExp_HNHR_list] FOR [$(OMHSP_PERC_PDW)].[App].[GEC_GECDACA_DOEx_HBPCExp_HNHR_list]
GO
CREATE SYNONYM [PDW].[GEC_GECDACA_Ext_DOEx_HBPC_Master_File_Annual] FOR [$(OMHSP_PERC_PDW)].[App].[GEC_GECDACA_Ext_DOEx_HBPC_Master_File_Annual]
GO
CREATE SYNONYM [PDW].[HDAP_NLP_OMHSP] FOR [$(OMHSP_PERC_PDW)].[App].[HDAP_NLP_OMHSP]
GO
CREATE SYNONYM [PDW].[HPO_HPOAnalytics_DoEX_PERC_CurrentHOMESCensus] FOR [$(OMHSP_PERC_PDW)].[App].[HPO_HPOAnalytics_DoEX_PERC_CurrentHOMESCensus]
GO
CREATE SYNONYM [PDW].[HPO_HPOAnalytics_DoEX_PERC_HOMESHistory] FOR [$(OMHSP_PERC_PDW)].[App].[HPO_HPOAnalytics_DoEX_PERC_HOMESHistory]
GO
CREATE SYNONYM [PDW].[IVC_CIPH_DOEx_vw_Overdose_ECR_Claims] FOR [$(OMHSP_PERC_PDW)].[App].[IVC_CIPH_DOEx_vw_Overdose_ECR_Claims]
GO
CREATE SYNONYM [PDW].[LSV_PBM_Analytics_PPSN_AllProducts] FOR [$(OMHSP_PERC_PDW)].[App].[LSV_PBM_Analytics_PPSN_AllProducts]
GO
CREATE SYNONYM [PDW].[LSV_PBM_Analytics_PPSN_NDC] FOR [$(OMHSP_PERC_PDW)].[App].[LSV_PBM_Analytics_PPSN_NDC]
GO
CREATE SYNONYM [PDW].[LSV_PBM_Analytics_PPSN_NDC_Active] FOR [$(OMHSP_PERC_PDW)].[App].[LSV_PBM_Analytics_PPSN_NDC_Active]
GO
CREATE SYNONYM [PDW].[LSV_PBM_Analytics_PPSN_Products_Active] FOR [$(OMHSP_PERC_PDW)].[App].[LSV_PBM_Analytics_PPSN_Products_Active]
GO
CREATE SYNONYM [PDW].[MillCDS_FactNoteSafetyPlansRaw] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_PERC_MillCDS_FactNoteSafetyPlansRaw]
GO
CREATE SYNONYM [PDW].[NEPEC_MHICM_DOEx_SP2_TH_Visits] FOR [$(OMHSP_PERC_PDW)].[App].[NEPEC_MHICM_DOEx_SP2_TH_Visits]
GO
CREATE SYNONYM [PDW].[NEPEC_MHICM_DOEx_TH_Consult_AllFacilities] FOR [$(OMHSP_PERC_PDW)].[App].[NEPEC_MHICM_DOEx_TH_Consult_AllFacilities]
GO
CREATE SYNONYM [PDW].[NEPEC_PRRC_DOEx_ICMHRTemplateSegmentOfCare] FOR [$(OMHSP_PERC_PDW)].[App].[NEPEC_PRRC_DOEx_ICMHRTemplateSegmentOfCare]
GO
CREATE SYNONYM [PDW].[NOP_PGx_DOEx_CYP2D6_Translation_table] FOR [$(OMHSP_PERC_PDW)].[App].[NOP_PGx_DOEx_CYP2D6_Translation_table]
GO
CREATE SYNONYM [PDW].[NOP_PGx_DOEx_PGx_CYP2D6_data] FOR [$(OMHSP_PERC_PDW)].[App].[NOP_PGx_DOEx_PGx_CYP2D6_data]
GO
CREATE SYNONYM [PDW].[NOP_PGx_DOEx_PHASER_sites] FOR [$(OMHSP_PERC_PDW)].[App].[NOP_PGx_DOEx_PHASER_sites]
GO
CREATE SYNONYM [PDW].[OABI_EQM_Mart_DOEx_TS_Concept] FOR [$(OMHSP_PERC_PDW)].[App].[OABI_EQM_Mart_DOEx_TS_Concept]
GO
CREATE SYNONYM [PDW].[OABI_EQM_Mart_DOEx_TS_ConceptMap] FOR [$(OMHSP_PERC_PDW)].[App].[OABI_EQM_Mart_DOEx_TS_ConceptMap]
GO
CREATE SYNONYM [PDW].[OABI_EQM_Mart_DOEx_TS_RelationshipType] FOR [$(OMHSP_PERC_PDW)].[App].[OABI_EQM_Mart_DOEx_TS_RelationshipType]
GO
CREATE SYNONYM [PDW].[OABI_EQM_Mart_DOEx_TS_Vocabulary] FOR [$(OMHSP_PERC_PDW)].[App].[OABI_EQM_Mart_DOEx_TS_Vocabulary]
GO
CREATE SYNONYM [PDW].[OABI_EQM_Share_DOEx_Fact_IPPAssignment] FOR [$(OMHSP_PERC_PDW)].[App].[OABI_EQM_Share_DOEx_Fact_IPPAssignment]
GO
CREATE SYNONYM [PDW].[OEHRM_DataSyn_DOEx_CernerQI] FOR [$(OMHSP_PERC_PDW)].[App].[OEHRM_DataSyn_DOEx_CernerQI]
GO
CREATE SYNONYM [PDW].[OHE_Consortium_RaceEthnicity] FOR [$(OMHSP_PERC_PDW)].[App].[OHE_consortium_DOEx_RaceEthnicity]
GO
CREATE SYNONYM [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Drug] FOR [$(OMHSP_PERC_PDW)].[App].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Drug]
GO
CREATE SYNONYM [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_NationalDrugLookup] FOR [$(OMHSP_PERC_PDW)].[App].[OIT_Rockies_DOEx_OIT_Rockies_MPR_NationalDrugLookup]
GO
CREATE SYNONYM [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Opioid] FOR [$(OMHSP_PERC_PDW)].[App].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Opioid]
GO
CREATE SYNONYM [PDW].[OMHO_EBPTraining_DOEx_EBP_ProviderTrainings] FOR [$(OMHSP_PERC_PDW)].[App].[OMHO_EBPTraining_DOEx_EBP_ProviderTrainings]
GO
CREATE SYNONYM [PDW].[OMHO_IRA_DOEx_homestation] FOR [$(OMHSP_PERC_PDW)].[App].[OMHO_IRA_DOEx_homestation]
GO
CREATE SYNONYM [PDW].[OMHO_PEC_DOEx_PERC_PDSI_Data_AllQuarters] FOR [$(OMHSP_PERC_PDW)].[App].[OMHO_PEC_DOEx_PERC_PDSI_Data_AllQuarters]
GO
CREATE SYNONYM [PDW].[OMHO_PEC_DOEx_smitrec_pdsi_data_allquarters] FOR [$(OMHSP_PERC_PDW)].[App].[OMHO_PEC_DOEx_smitrec_pdsi_data_allquarters]
GO
CREATE SYNONYM [PDW].[OMHO_QFR_DOEx_SPSUD_PositionActionReviewWorklist_StaffSID] FOR [$(OMHSP_PERC_PDW)].[App].[OMHO_QFR_DOEx_SPSUD_PositionActionReviewWorklist_StaffSID]
GO
CREATE SYNONYM [PDW].[OMHSP_MIRECC_DOEx_MHDischarge] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_MIRECC_DOEx_MHDischarge]
GO
CREATE SYNONYM [PDW].[OMHSP_MIRECC_DOEx_SPEDCohort] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_MIRECC_DOEx_SPEDCohort]
GO
CREATE SYNONYM [PDW].[OMHSP_PERC_COMPACT_TIU_IVC] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_PERC_COMPACT_TIU_IVC]
GO
CREATE SYNONYM [PDW].[OMHSP_SPP_DataHub_DoEX_DODSER] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_SPP_DataHub_DoEX_DODSER]
GO
CREATE SYNONYM [PDW].[OMHSP_SuicideOverdoseEvent_IDUqaOutput_ODCohortDec2023] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_SuicideOverdoseEvent_IDUqaOutput_ODCohortDec2023]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_ActionsForCall_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_ActionsForCall_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_AdHocReports_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_AdHocReports_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_CallHowHeard_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_CallHowHeard_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_CallOutcomes_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_CallOutcomes_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_CallPrompts_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_CallPrompts_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_CallResponseInputs_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_CallResponseInputs_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_CallResponses_Changes_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_CallResponses_Changes_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_CallResponses_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_CallResponses_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_CallSources_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_CallSources_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_CallTransferLocations_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_CallTransferLocations_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_CallTypes_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_CallTypes_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_CoASForCaller_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_CoASForCaller_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_ConsultTypesForCall_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_ConsultTypesForCall_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_CrisisInterventions_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_CrisisInterventions_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_CrisisTypes_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_CrisisTypes_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_CrisisTypesForCrisisInterventions_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_CrisisTypesForCrisisInterventions_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_CrisisWorkersResponses_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_CrisisWorkersResponses_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_Drugs_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_Drugs_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_EmergencyDispatches_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_EmergencyDispatches_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_EntryLogsForCrisisIntervention_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_EntryLogsForCrisisIntervention_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_EOCSATQTypes_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_EOCSATQTypes_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_FacilityArrivalMeans_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_FacilityArrivalMeans_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_FacilityTransportPlans_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_FacilityTransportPlans_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_FlaggedPhoneNumbers_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_FlaggedPhoneNumbers_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_FlagsForPhoneNumbers_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_FlagsForPhoneNumbers_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_HeardAboutSources_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_HeardAboutSources_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_HotlineCallChanges_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_HotlineCallChanges_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_HotlineCallPrompts_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_HotlineCallPrompts_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_HotlineCalls] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_HotlineCalls]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_HotlineCalls_H_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_HotlineCalls_H_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_HotlineCalls_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_HotlineCalls_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_HotlineCallsDetails] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_HotlineCallsDetails]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_HotlineCallsDetails_H_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_HotlineCallsDetails_H_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_HotlineCallsDetails_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_HotlineCallsDetails_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_HT_FollowUps_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_HT_FollowUps_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_MeansOutcomes_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_MeansOutcomes_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_POMS_Levels_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_POMS_Levels_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_POMS_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_POMS_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_PrankOrHangupCalls_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_PrankOrHangupCalls_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_QuickCallSaves_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_QuickCallSaves_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_RecordFlags_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_RecordFlags_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_RecordFlagTypes_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_RecordFlagTypes_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_RiskAssessmentLevels_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_RiskAssessmentLevels_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_SDVItem_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_SDVItem_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_ServiceConflictsOrAreas_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_ServiceConflictsOrAreas_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_SPCResponseInputs_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_SPCResponseInputs_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_SpecialEvents_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_SpecialEvents_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_SupervisorConsultTypes_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_SupervisorConsultTypes_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_TimelineEntryLogs_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_TimelineEntryLogs_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_Users_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_Users_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_UserTypes_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_UserTypes_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_VASites_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_VASites_View]
GO
CREATE SYNONYM [PDW].[OMHSP_VCLReport_DOEx_Medora_VeteranStatuses_View] FOR [$(OMHSP_PERC_PDW)].[App].[OMHSP_VCLReport_DOEx_Medora_VeteranStatuses_View]
GO
CREATE SYNONYM [PDW].[OPCCCT_Analytics_DOEx_WholeHealth_1_VISITS] FOR [$(OMHSP_PERC_PDW)].[App].[OPCCCT_Analytics_DOEx_WholeHealth_1_VISITS]
GO
CREATE SYNONYM [PDW].[OPCCCT_Analytics_DOEx_WholeHealth_2_Patient] FOR [$(OMHSP_PERC_PDW)].[App].[OPCCCT_Analytics_DOEx_WholeHealth_2_Patient]
GO
CREATE SYNONYM [PDW].[OPCCCT_Analytics_DOEx_WholeHealth_3_HealthFactor] FOR [$(OMHSP_PERC_PDW)].[App].[OPCCCT_Analytics_DOEx_WholeHealth_3_HealthFactor]
GO
CREATE SYNONYM [PDW].[OPCCCT_Analytics_DOEx_WholeHealth_4_CPT] FOR [$(OMHSP_PERC_PDW)].[App].[OPCCCT_Analytics_DOEx_WholeHealth_4_CPT]
GO
CREATE SYNONYM [PDW].[OPCCCT_Analytics_DOEx_WholeHealth_5_SDOH] FOR [$(OMHSP_PERC_PDW)].[App].[OPCCCT_Analytics_DOEx_WholeHealth_5_SDOH]
GO
CREATE SYNONYM [PDW].[OPES_Productivty_Archive_DoEX_CPTRVUMaster] FOR [$(OMHSP_PERC_PDW)].[App].[OPES_Productivty_Archive_DoEX_CPTRVUMaster]
GO
CREATE SYNONYM [PDW].[OPP_MAHSO_DOEx_vw_ref_fips_to_sector_by23] FOR [$(OMHSP_PERC_PDW)].[App].[OPP_MAHSO_DOEx_vw_ref_fips_to_sector_by23]
GO
CREATE SYNONYM [PDW].[PBM_AD_DOEx_Chem_LabChem_DrugScreens_2Y] FOR [$(OMHSP_PERC_PDW)].[App].[PBM_AD_DOEx_Chem_LabChem_DrugScreens_2Y]
GO
CREATE SYNONYM [PDW].[PBM_AD_DOEx_Dim_LabChemTest_DrugScreens] FOR [$(OMHSP_PERC_PDW)].[App].[PBM_AD_DOEx_Dim_LabChemTest_DrugScreens]
GO
CREATE SYNONYM [PDW].[PBM_AD_DOEx_Dim_NationalDrug] FOR [$(OMHSP_PERC_PDW)].[App].[PBM_AD_DOEx_Dim_NationalDrug]
GO
CREATE SYNONYM [PDW].[PBM_AD_DOEx_Naloxone_Rxs] FOR [$(OMHSP_PERC_PDW)].[App].[PBM_AD_DOEx_Naloxone_Rxs]
GO
CREATE SYNONYM [PDW].[PBM_AD_DOEx_Naloxone_NonVA] FOR [$(OMHSP_PERC_PDW)].[App].[PBM_AD_DOEx_Naloxone_NonVA]
GO
CREATE SYNONYM [PDW].[PBM_AD_DOEx_Naloxone_HealthFactors] FOR [$(OMHSP_PERC_PDW)].[App].[PBM_AD_DOEx_Naloxone_HealthFactors]
GO
CREATE SYNONYM [PDW].[PBM_AD_DOEx_Naloxone_ProcedureCodes] FOR [$(OMHSP_PERC_PDW)].[App].[PBM_AD_DOEx_Naloxone_ProcedureCodes]
GO
CREATE SYNONYM [PDW].[PBM_AD_DOEx_OEND_RIOSORD] FOR [$(OMHSP_PERC_PDW)].[App].[PBM_AD_DOEx_OEND_RIOSORD]
GO
CREATE SYNONYM [PDW].[PBM_AD_DOEx_OSI_PatientMEDDTrend] FOR [$(OMHSP_PERC_PDW)].[App].[PBM_AD_DOEx_OSI_PatientMEDDTrend]
GO
CREATE SYNONYM [PDW].[PBM_AD_DOEx_OSI_PatientMEDDTrend_Historic] FOR [$(OMHSP_PERC_PDW)].[App].[PBM_AD_DOEx_OSI_PatientMEDDTrend_Historic]
GO
CREATE SYNONYM [PDW].[PBM_AD_DOEx_Staging_Institutions] FOR [$(OMHSP_PERC_PDW)].[App].[PBM_AD_DOEx_Staging_Institutions]
GO
CREATE SYNONYM [PDW].[PBM_AD_DOEx_Staging_MEDD] FOR [$(OMHSP_PERC_PDW)].[App].[PBM_AD_DOEx_Staging_MEDD]
GO
CREATE SYNONYM [PDW].[PBM_AD_DOEx_Staging_MorphineEquivalence] FOR [$(OMHSP_PERC_PDW)].[App].[PBM_AD_DOEx_Staging_MorphineEquivalence]
GO
CREATE SYNONYM [PDW].[PBM_AD_DOEx_Staging_RIOSORD] FOR [$(OMHSP_PERC_PDW)].[App].[PBM_AD_DOEx_Staging_RIOSORD]
GO
CREATE SYNONYM [PDW].[PBM_MedSafeRpts_DOEx_OSI_DashboardMetrics] FOR [$(OMHSP_PERC_PDW)].[App].[PBM_MedSafeRpts_DOEx_OSI_DashboardMetrics]
GO
CREATE SYNONYM [PDW].[PBM_MedSafeRpts_DOEx_OSI_DashboardMetrics_wCerner] FOR [$(OMHSP_PERC_PDW)].[App].[PBM_MedSafeRpts_DOEx_OSI_DashboardMetrics_wCerner]
GO
CREATE SYNONYM [PDW].[PCMHI_PCMHI_DOEx_CSSRS_SPVNextShare] FOR [$(OMHSP_PERC_PDW)].[App].[PCMHI_PCMHI_DOEx_CSSRS_SPVNextShare]
GO
CREATE SYNONYM [PDW].[PCO_CRHQM_DOEx_CRH_SiteProviders] FOR [$(OMHSP_PERC_PDW)].[App].[PCO_CRHQM_DOEx_CRH_SiteProviders]
GO
CREATE SYNONYM [PDW].[PCS_LABMed_DOEx_HIV] FOR [$(OMHSP_PERC_PDW)].[App].[PCS_LABMed_DOEx_HIV]
GO
CREATE SYNONYM [PDW].[RecurringReports_PEER_CrosswalkDOEx] FOR [$(OMHSP_PERC_PDW)].[App].[RecurringReports_PEER_CrosswalkDOEx] 
GO
CREATE SYNONYM [PDW].[RecurringReports_PEER_CrosswalkWithPositionDOEx] FOR [$(OMHSP_PERC_PDW)].[App].[RecurringReports_PEER_CrosswalkWithPositionDOEx] 
GO
CREATE SYNONYM [PDW].[RecurringReports_PEER_PeerSpecialistData] FOR [$(OMHSP_PERC_PDW)].[App].[RecurringReports_PEER_PeerSpecialistData] 
GO
CREATE SYNONYM [PDW].[SCS_HLIRC_DOEx_HepCLabAllPtAllTime] FOR [$(OMHSP_PERC_PDW)].[App].[SCS_HLIRC_DOEx_HepCLabAllPtAllTime]
GO
CREATE SYNONYM [PDW].[SCS_PMOP_DOEx_PMOP_PHD_DOEx] FOR [$(OMHSP_PERC_PDW)].[App].[SCS_PMOP_DOEx_PMOP_PHD_DOEx]
GO
CREATE SYNONYM [PDW].[SHRED_dbo_DimFacility6A] FOR [$(OMHSP_PERC_PDW)].[App].[SHRED_dbo_DimFacility6A]
GO
CREATE SYNONYM [PDW].[SHRED_dbo_DimMeasure] FOR [$(OMHSP_PERC_PDW)].[App].[SHRED_dbo_DimMeasure]
GO
CREATE SYNONYM [PDW].[SHRED_dbo_DimPoc] FOR [$(OMHSP_PERC_PDW)].[App].[SHRED_dbo_DimPoc]
GO
CREATE SYNONYM [PDW].[SHRED_dbo_DimSHREDFacility] FOR [$(OMHSP_PERC_PDW)].[App].[SHRED_dbo_DimSHREDFacility]
GO
CREATE SYNONYM [PDW].[SHRED_dbo_DimSponsor] FOR [$(OMHSP_PERC_PDW)].[App].[SHRED_dbo_DimSponsor]
GO
CREATE SYNONYM [PDW].[SHRED_MHS_MeasurePerformance_MIRECC] FOR [$(OMHSP_PERC_PDW)].[App].[SHRED_MHS_MeasurePerformance_MIRECC];
GO
CREATE SYNONYM [PDW].[SHRED_OMHSP_NEPEC_MeasurePerformance_MHIS] FOR [$(OMHSP_PERC_PDW)].[App].[SHRED_OMHSP_NEPEC_MeasurePerformance_MHIS]
GO
CREATE SYNONYM [PDW].[SHRED_OMHSP_NEPEC_MeasurePerformance_SAIL] FOR [$(OMHSP_PERC_PDW)].[App].[SHRED_OMHSP_NEPEC_MeasurePerformance_SAIL]
GO
CREATE SYNONYM [PDW].[SHRED_OMHSP_PMOP_MeasurePerformance_MHIS] FOR [$(OMHSP_PERC_PDW)].[App].[SHRED_OMHSP_PMOP_MeasurePerformance_MHIS]
GO
CREATE SYNONYM [PDW].[SHRED_OMHSP_SMITREC_MeasurePerformance_MHIS] FOR [$(OMHSP_PERC_PDW)].[App].[SHRED_OMHSP_SMITREC_MeasurePerformance_MHIS]
GO
CREATE SYNONYM [PDW].[SHRED_OMHSP_SMITREC_MeasurePerformance_SAIL] FOR [$(OMHSP_PERC_PDW)].[App].[SHRED_OMHSP_SMITREC_MeasurePerformance_SAIL]
GO
CREATE SYNONYM [PDW].[SHRED_PMRF_MeasurePerformance] FOR [$(OMHSP_PERC_PDW)].[App].[SHRED_PMRF_MeasurePerformance]
GO
CREATE SYNONYM [PDW].[SHRED_VSSC_MeasurePerformance_MH_Transitions] FOR [$(OMHSP_PERC_PDW)].[App].[SHRED_VSSC_MeasurePerformance_MH_Transitions]
GO
CREATE SYNONYM [PDW].[SMITR_SMITREC_DOEx_ReEngage_SPPRITE] FOR [$(OMHSP_PERC_PDW)].[App].[SMITR_SMITREC_DOEx_ReEngage_SPPRITE]
GO
CREATE SYNONYM [PDW].[SMITR_SMITREC_DOEx_SPNowPlank3_PBNRVets] FOR [$(OMHSP_PERC_PDW)].[App].[SMITR_SMITREC_DOEx_SPNowPlank3_PBNRVets]
GO
CREATE SYNONYM [PDW].[SpanExport_tbl_Patient] FOR [$(OMHSP_PERC_PDW)].[App].[SpanExport_tbl_Patient]
GO
CREATE SYNONYM [PDW].[SpanExport_tbl_SPANClientMethodUsed] FOR [$(OMHSP_PERC_PDW)].[App].[SpanExport_tbl_SPANClientMethodUsed]
GO
CREATE SYNONYM [PDW].[SpanExport_tbl_SPANEventLog] FOR [$(OMHSP_PERC_PDW)].[App].[SpanExport_tbl_SPANEventLog]
GO
CREATE SYNONYM [PDW].[SpanExport_tbl_SPANEventLogHistory] FOR [$(OMHSP_PERC_PDW)].[App].[SpanExport_tbl_SPANEventLogHistory]
GO
CREATE SYNONYM [PDW].[SpanExport_tbl_SPANMethodUsedHistory] FOR [$(OMHSP_PERC_PDW)].[App].[SpanExport_tbl_SPANMethodUsedHistory]
GO
CREATE SYNONYM [PDW].[SpanExport_VA_VHASites] FOR [$(OMHSP_PERC_PDW)].[App].[SpanExport_VA_VHASites]
GO
CREATE SYNONYM [PDW].[VAAUSSQLCAO21_DMC_HRV_dbo_HRV_DEBT] FOR [$(OMHSP_PERC_PDW)].[App].[VAAUSSQLCAO21_DMC_HRV_dbo_HRV_DEBT]
GO
CREATE SYNONYM [PDW].[VAAUSSQLCAO21_DMC_HRV_dbo_HRV_LETTER] FOR [$(OMHSP_PERC_PDW)].[App].[VAAUSSQLCAO21_DMC_HRV_dbo_HRV_LETTER]
GO
CREATE SYNONYM [PDW].[VCL_Medoraforce_Perc_VCL_Call__c] FOR [$(OMHSP_PERC_PDW)].[App].[VCL_Medoraforce_Perc_VCL_Call__c]
GO
CREATE SYNONYM [PDW].[VCL_Medoraforce_Perc_VCL_Changelog_Entry__c] FOR [$(OMHSP_PERC_PDW)].[App].[VCL_Medoraforce_Perc_VCL_Changelog_Entry__c]
GO
CREATE SYNONYM [PDW].[VCL_Medoraforce_Perc_VCL_Crisis_Intervention__c] FOR [$(OMHSP_PERC_PDW)].[App].[VCL_Medoraforce_Perc_VCL_Crisis_Intervention__c]
GO
CREATE SYNONYM [PDW].[VCL_Medoraforce_Perc_VCL_Emergency_Dispatch__c] FOR [$(OMHSP_PERC_PDW)].[App].[VCL_Medoraforce_Perc_VCL_Emergency_Dispatch__c]
GO
CREATE SYNONYM [PDW].[VCL_Medoraforce_Perc_VCL_Facility_Transport_Plan__c] FOR [$(OMHSP_PERC_PDW)].[App].[VCL_Medoraforce_Perc_VCL_Facility_Transport_Plan__c]
GO
CREATE SYNONYM [PDW].[VCL_Medoraforce_Perc_VCL_Follow_Up__c] FOR [$(OMHSP_PERC_PDW)].[App].[VCL_Medoraforce_Perc_VCL_Follow_Up__c]
GO
CREATE SYNONYM [PDW].[VCL_Medoraforce_Perc_VCL_Form_Data__c] FOR [$(OMHSP_PERC_PDW)].[App].[VCL_Medoraforce_Perc_VCL_Form_Data__c]
GO
CREATE SYNONYM [PDW].[VCL_Medoraforce_Perc_VCL_Health_Tech_Note__c] FOR [$(OMHSP_PERC_PDW)].[App].[VCL_Medoraforce_Perc_VCL_Health_Tech_Note__c]
GO
CREATE SYNONYM [PDW].[VCL_Medoraforce_Perc_VCL_Primary_Language__c] FOR [$(OMHSP_PERC_PDW)].[App].[VCL_Medoraforce_Perc_VCL_Primary_Language__c]
GO
CREATE SYNONYM [PDW].[VCL_Medoraforce_Perc_VCL_Record_Flag__c] FOR [$(OMHSP_PERC_PDW)].[App].[VCL_Medoraforce_Perc_VCL_Record_Flag__c]
GO
CREATE SYNONYM [PDW].[VCL_Medoraforce_Perc_VCL_Request__c] FOR [$(OMHSP_PERC_PDW)].[App].[VCL_Medoraforce_Perc_VCL_Request__c]
GO
CREATE SYNONYM [PDW].[VCL_Medoraforce_Perc_VCL_Site__c] FOR [$(OMHSP_PERC_PDW)].[App].[VCL_Medoraforce_Perc_VCL_Site__c]
GO
CREATE SYNONYM [PDW].[VCL_Medoraforce_Perc_VCL_Special_Event__c] FOR [$(OMHSP_PERC_PDW)].[App].[VCL_Medoraforce_Perc_VCL_Special_Event__c]
GO
CREATE SYNONYM [PDW].[VCL_Medoraforce_Perc_VCL_Team_Member__c] FOR [$(OMHSP_PERC_PDW)].[App].[VCL_Medoraforce_Perc_VCL_Team_Member__c]
GO
CREATE SYNONYM [PDW].[VCL_Medoraforce_Perc_VCL_Time_Log_Entry__c] FOR [$(OMHSP_PERC_PDW)].[App].[VCL_Medoraforce_Perc_VCL_Time_Log_Entry__c]
GO
CREATE SYNONYM [PDW].[VHAHOC_Tier2_DOEx_vwReferralsFactdoex] FOR [$(OMHSP_PERC_PDW)].[App].[VHAHOC_Tier2_DOEx_vwReferralsFactdoex]
GO
CREATE SYNONYM [PDW].[VINCI_VetsNet_VetsNetRaw_VETSNET] FOR [$(OMHSP_PERC_PDW)].[App].[VINCI_VetsNet_VetsNetRaw_VETSNET];
GO
CREATE SYNONYM [PDW].[VINCI_VetsNet_VetsNetRaw_vetsnet_xwalk] FOR [$(OMHSP_PERC_PDW)].[App].[VINCI_VetsNet_VetsNetRaw_vetsnet_xwalk];
GO
CREATE SYNONYM [PDW].[VSSC_MeasurePerformance_CompletedAppts] FOR [$(OMHSP_PERC_PDW)].[App].[VSSC_MeasurePerformance_CompletedAppts]
GO
CREATE SYNONYM [PDW].[VSSC_MeasurePerformance_NoShow] FOR [$(OMHSP_PERC_PDW)].[App].[VSSC_MeasurePerformance_NoShow]
GO
CREATE SYNONYM [PDW].[VSSC_MeasurePerformance_PACT] FOR [$(OMHSP_PERC_PDW)].[App].[VSSC_MeasurePerformance_PACT]
GO
CREATE SYNONYM [PDW].[VSSC_MeasurePerformance_Telehealth] FOR [$(OMHSP_PERC_PDW)].[App].[VSSC_MeasurePerformance_Telehealth]
GO
CREATE SYNONYM [PDW].[VSSC_Out_DoEX_DimFacility6a] FOR [$(OMHSP_PERC_PDW)].[App].[VSSC_Out_DoEX_DimFacility6a]
GO
CREATE SYNONYM [PDW].[VSSC_Out_DOEx_SPEDCohort] FOR [$(OMHSP_PERC_PDW)].[App].[VSSC_Out_DOEx_SPEDCohort]
GO
CREATE SYNONYM [PDW].[VSSC_Out_DoEX_VSSCPCMMAssignments] FOR [$(OMHSP_PERC_PDW)].[App].[VSSC_Out_DoEX_VSSCPCMMAssignments]
GO
EXECUTE sp_addextendedproperty @name = N'SynonymDescription', @value = N'SAIL/MHIS measures from SHRED includes measure like dms40_ec via PDW', @level0type = N'SCHEMA', @level0name = N'PDW', @level1type = N'SYNONYM', @level1name = N'SHRED_PMRF_MeasurePerformance';
GO
EXECUTE sp_addextendedproperty @name = N'SynonymDescription', @value = N'MIRECC data for SAIL measures from SHRED ', @level0type = N'SCHEMA', @level0name = N'PDW', @level1type = N'SYNONYM', @level1name = N'SHRED_MHS_MeasurePerformance_MIRECC';
GO
EXECUTE sp_addextendedproperty @name = N'SynonymDescription', @value = N'PITA measures Sponsors Information ', @level0type = N'SCHEMA', @level0name = N'PDW', @level1type = N'SYNONYM', @level1name = N'SHRED_dbo_DimSponsor';
GO
EXECUTE sp_addextendedproperty @name = N'SynonymDescription', @value = N'PITA measures POCs ', @level0type = N'SCHEMA', @level0name = N'PDW', @level1type = N'SYNONYM', @level1name = N'SHRED_dbo_DimPoc';
GO
EXECUTE sp_addextendedproperty @name = N'SynonymDescription', @value = N'From DeanD. - Defines the measure, attributes that typically dont change drastically over the measure lifecycle. These attributes are considered relevant for the lifecycle of the measure', @level0type = N'SCHEMA', @level0name = N'PDW', @level1type = N'SYNONYM', @level1name = N'SHRED_dbo_DimMeasure';
GO
