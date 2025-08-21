
CREATE PROCEDURE [Code].[ORM_RiskScore]

-- ============================================================================
-- CREATE DATE: 2017-08-07
-- DESCRIPTION:	Code to calculate RiskScore AND RiskScoreHypothetical. 
--              Combines the calculations AND tables updates that were 
--              previously done in "Code.ORM_RiskComputation" AND 
--				"Code.ORM_RiskHypothethicalComputation:

--
-- UPDATE DATE: 2018-06-12
-- DESCRIPTION:	Model was created FROM FY10 data AND Station 740 did NOT
--				exist at this time. Patients with a home station of 740
--				(includes a visn of 17) are calculated without a variable 
--				for station 740 (thus NULL).  A NULL value in any calculation
--				results in a NULL value.  Updates made to code to include 
--				a variable for station 740 of 0 (zero) AND the visn variable 
--				of 0 (zero).  All other stations in Visn 17 will use the 
--				value calculated FROM the model.
--
-- UPDATE DATE: 2018-10-17 - Jason Bacani
-- DESCRIPTION:	Refactored to use mix of TempDB Temp tables 
--				AND Global Temp Tables that are cleaned up after their use.
--				Also applied formatting, removed non needed code

-- 2020-04-01	RAS	Changed corresponding patient variable for @Psych_poss to Other_MH_STORM field from ORM.RiskScore (correction to previous Psych_poss category)
-- 2020-10-28	RAS VM VERSION - Rolled back changes in v02 and used original version instead, with references to VM tables.  
				--	Will continue work on architecture update after initial release of Cerner data in CDS (post 4.0).
-- 2021-08-10	RAS	Updated references to ORM.Cohort with SUD.Cohort
-- 2021-12-12   TG  Added ODPastYear variable to risk score computation
-- 2023-12-15   TG  Changing SUD Cohort restriction to include the recently discontinued in risk computation
-- 2024-02-08   TG  Including the DoD OUD cohort for hypothetical risk score computation.
-- 2024-06-05   CW  Adding CC_Overdose into risk score computation
-- 2025-08-14   TG  Fixing Risk Category label for Elevated Risk due to OUD Dx.
-- ============================================================================
AS
BEGIN

	--------------------------------- PRT 07/15/2017
	-- DECLARE Pivot Table Variables
	---------------------------------
	DECLARE @DynamicPivotQuery AS NVARCHAR(MAX)
	DECLARE @ColumnName1 AS NVARCHAR(MAX)
	DECLARE @ColumnName2 AS NVARCHAR(MAX)
	DECLARE @ColumnName3 AS NVARCHAR(MAX)
	DECLARE @ColumnName4 AS NVARCHAR(MAX)

	---------------------------------------- PRT 07/15/2017
	--- DECLARE Overdose Parameter Variables
	----------------------------------------
	DECLARE 
		 @Intercept	DECIMAL(38,15),
		 @TotalMEDD	DECIMAL(38,15),
		 @LongActing	DECIMAL(38,15),
		 @ChronicShortActing	DECIMAL(38,15),
		 @NonChronicShortActing	DECIMAL(38,15),
		 @TramadolOnly	DECIMAL(38,15),
		 @Age30	DECIMAL(38,15),
		 @Age3150	DECIMAL(38,15),
		 @Age5165	DECIMAL(38,15),
		 @Age66	DECIMAL(38,15),
		 @GenderMale	DECIMAL(38,15),
		 @SumOverdose_Suicide	DECIMAL(38,15),
		 @AnySAE	DECIMAL(38,15),
		 @Sum_Painadj3	DECIMAL(38,15),
		 @Sum_Painadj2	DECIMAL(38,15),
		 @Sum_Painadj1	DECIMAL(38,15),
		 @Sum_Painadj0	DECIMAL(38,15),
		 @AUD_ORM	DECIMAL(38,15),
		 @OUD	DECIMAL(38,15),
		 @Psych_poss	DECIMAL(38,15),
		 @MHInpat	DECIMAL(38,15),
		 @BIPOLAR	DECIMAL(38,15),
		 @PTSD	DECIMAL(38,15),
		 @MDD	DECIMAL(38,15),
		 @NicDx_Poss	DECIMAL(38,15),
		 @SedativeOpioid_Rx	DECIMAL(38,15),
		 @Detox_CPT	DECIMAL(38,15),
		 @OtherSUD_RiskModel	DECIMAL(38,15),
		 @ERvisit	DECIMAL(38,15),
		 @SedativeUseDisorder	DECIMAL(38,15),
		 @SleepApnea	DECIMAL(38,15),
		 @Osteoporosis	DECIMAL(38,15),
		 @CannabisUD_HallucUD	DECIMAL(38,15),
		 @CocaineUD_AmphUD	DECIMAL(38,15),
		 @EH_HEART	DECIMAL(38,15),
		 @EH_ARRHYTH	DECIMAL(38,15),
		 @EH_VALVDIS	DECIMAL(38,15),
		 @EH_PULMCIRC	DECIMAL(38,15),
		 @EH_PERIVALV	DECIMAL(38,15),
		 @EH_HYPERTENS	DECIMAL(38,15),
		 @EH_PARALYSIS	DECIMAL(38,15),
		 @EH_OTHNEURO	DECIMAL(38,15),
		 @EH_CHRNPULM	DECIMAL(38,15),
		 @EH_UNCDIAB	DECIMAL(38,15),
		 @EH_COMDIAB	DECIMAL(38,15),
		 @EH_HYPOTHY	DECIMAL(38,15),
		 @EH_RENAL	DECIMAL(38,15),
		 @EH_LIVER	DECIMAL(38,15),
		 @EH_PEPTICULC	DECIMAL(38,15),
		 @EH_AIDS	DECIMAL(38,15),
		 @EH_LYMPHOMA	DECIMAL(38,15),
		 @EH_METCANCR	DECIMAL(38,15),
		 @EH_NMETTUMR	DECIMAL(38,15),
		 @EH_RHEUMART	DECIMAL(38,15),
		 @EH_COAG	DECIMAL(38,15),
		 @EH_OBESITY	DECIMAL(38,15),
		 @EH_WEIGHTLS	DECIMAL(38,15),
		 @EH_ELECTRLYTE	DECIMAL(38,15),
		 @EH_BLANEMIA	DECIMAL(38,15),
		 @EH_DefANEMIA	DECIMAL(38,15),
		 @TotalMEDD_Age30	DECIMAL(38,15),
		 @TotalMEDD_Age3150	DECIMAL(38,15),
		 @TotalMEDD_Age5165	DECIMAL(38,15),
		 @TotalMEDD_Age66	DECIMAL(38,15),
		 @TotalMEDD_OUD	DECIMAL(38,15),
		 @TotalMEDD_MDD	DECIMAL(38,15),
		 @GenderMale_LongActing	DECIMAL(38,15),
		 @GenderMale_ChronicShortActing	DECIMAL(38,15),
		 @GenderMale_NonChronicShortActing	DECIMAL(38,15),
		 @GenderMale_TramadolOnly	DECIMAL(38,15),
		 @SumOverdose_Suicide_Age30	DECIMAL(38,15),
		 @SumOverdose_Suicide_Age3150	DECIMAL(38,15),
		 @SumOverdose_Suicide_Age5165	DECIMAL(38,15),
		 @SumOverdose_Suicide_Age66	DECIMAL(38,15),
		 @AnySAE_Age30	DECIMAL(38,15),
		 @AnySAE_Age3150	DECIMAL(38,15),
		 @AnySAE_Age5165	DECIMAL(38,15),
		 @AnySAE_Age66	DECIMAL(38,15),
		 @ERvisit_Age30	DECIMAL(38,15),
		 @ERvisit_Age3150	DECIMAL(38,15),
		 @ERvisit_Age5165	DECIMAL(38,15),
		 @ERvisit_Age66	DECIMAL(38,15),
		 @GenderMale_PTSD	DECIMAL(38,15),
		 @SumOverdose_Suicide_MHInpat	DECIMAL(38,15),
		 @SumOverdose_Suicide_OtherSUD_RiskModel	DECIMAL(38,15),
		 @SumOverdose_Suicide_ERvisit	DECIMAL(38,15),
		 @MDD_Sum_Painadj3					DECIMAL(38,15),
		 @MDD_Sum_Painadj2					DECIMAL(38,15),
		 @MDD_Sum_Painadj1					DECIMAL(38,15),
		 @MDD_Sum_Painadj0					DECIMAL(38,15),
		 @OtherSUD_RiskModel_Sum_Painadj3		DECIMAL(38,15),
		 @OtherSUD_RiskModel_Sum_Painadj2		DECIMAL(38,15),
		 @OtherSUD_RiskModel_Sum_Painadj1		DECIMAL(38,15),
		 @OtherSUD_RiskModel_Sum_Painadj0		DECIMAL(38,15),
		 @CannabisUD_HallucUD_Sum_Painadj3	DECIMAL(38,15),
		 @CannabisUD_HallucUD_Sum_Painadj2	DECIMAL(38,15),
		 @CannabisUD_HallucUD_Sum_Painadj1	DECIMAL(38,15),
		 @CannabisUD_HallucUD_Sum_Painadj0	DECIMAL(38,15),
		 @AUD_ORM_MDD					DECIMAL(38,15),
		 @AUD_ORM_CannabisUD_HallucUD	DECIMAL(38,15),
		 @AUD_ORM_CocaineUD_AmphUD	DECIMAL(38,15),
		 @MHInpat_NicDx_Poss	DECIMAL(38,15),
		 @MHInpat_ERvisit	DECIMAL(38,15),
		 @Bipolar_PTSD	DECIMAL(38,15),
		 @Bipolar_MDD	DECIMAL(38,15),
		 @Bipolar_CannabisUD_HallucUD	DECIMAL(38,15),
		 @PTSD_MDD	DECIMAL(38,15),
		 @NicDx_Poss_OtherSUD_RiskModel	DECIMAL(38,15),
		 @MHInpat_SedativeOpioid_Rx	DECIMAL(38,15),
		 @OtherSUD_RiskModel_CannabisUD_HallucUD	DECIMAL(38,15);

	----------------------------------------------- PRT 07/15/2017
	--- DECLARE Random (Station AND VISN) Variables
	-----------------------------------------------
	DECLARE
		@Station358 DECIMAL(38,15),
		@Station402 DECIMAL(38,15),
		@Station405 DECIMAL(38,15),
		@Station436 DECIMAL(38,15),
		@Station437 DECIMAL(38,15),
		@Station438 DECIMAL(38,15),
		@Station442 DECIMAL(38,15),
		@Station459 DECIMAL(38,15),
		@Station460 DECIMAL(38,15),	
		@Station463 DECIMAL(38,15),
		@Station501 DECIMAL(38,15),
		@Station502 DECIMAL(38,15),
		@Station503 DECIMAL(38,15),
		@Station504 DECIMAL(38,15),
		@Station506 DECIMAL(38,15),
		@Station508 DECIMAL(38,15),
		@Station509 DECIMAL(38,15),
		@Station512 DECIMAL(38,15),
		@Station515 DECIMAL(38,15),
		@Station516 DECIMAL(38,15),
		@Station517 DECIMAL(38,15),
		@Station518 DECIMAL(38,15),
		@Station519 DECIMAL(38,15),
		@Station520 DECIMAL(38,15),
		@Station521 DECIMAL(38,15),
		@Station523 DECIMAL(38,15),
		@Station526 DECIMAL(38,15),
		@Station528 DECIMAL(38,15),
		@Station529 DECIMAL(38,15),
		@Station531 DECIMAL(38,15),
		@Station534 DECIMAL(38,15),
		@Station537 DECIMAL(38,15),
		@Station538 DECIMAL(38,15),
		@Station539 DECIMAL(38,15),
		@Station540 DECIMAL(38,15),
		@Station541 DECIMAL(38,15),
		@Station542 DECIMAL(38,15),
		@Station544 DECIMAL(38,15),
		@Station546 DECIMAL(38,15),
		@Station548 DECIMAL(38,15),
		@Station549 DECIMAL(38,15),
		@Station550 DECIMAL(38,15),
		@Station552 DECIMAL(38,15),
		@Station553 DECIMAL(38,15),
		@Station554 DECIMAL(38,15),
		@Station556 DECIMAL(38,15),
		@Station557 DECIMAL(38,15),
		@Station558 DECIMAL(38,15),
		@Station561 DECIMAL(38,15),
		@Station562 DECIMAL(38,15),
		@Station564 DECIMAL(38,15),
		@Station565 DECIMAL(38,15),
		@Station568 DECIMAL(38,15),
		@Station570 DECIMAL(38,15),
		@Station573 DECIMAL(38,15),
		@Station575 DECIMAL(38,15),
		@Station578 DECIMAL(38,15),
		@Station580 DECIMAL(38,15),
		@Station581 DECIMAL(38,15),
		@Station583 DECIMAL(38,15),
		@Station585 DECIMAL(38,15),
		@Station586 DECIMAL(38,15),
		@Station589 DECIMAL(38,15),
		@Station590 DECIMAL(38,15),
		@Station593 DECIMAL(38,15),
		@Station595 DECIMAL(38,15),
		@Station596 DECIMAL(38,15),
		@Station598 DECIMAL(38,15),
		@Station600 DECIMAL(38,15),
		@Station603 DECIMAL(38,15),
		@Station605 DECIMAL(38,15),
		@Station607 DECIMAL(38,15),
		@Station608 DECIMAL(38,15),	
		@Station610 DECIMAL(38,15),
		@Station612 DECIMAL(38,15),
		@Station613 DECIMAL(38,15),
		@Station614 DECIMAL(38,15),
		@Station618 DECIMAL(38,15),
		@Station619 DECIMAL(38,15),
		@Station620 DECIMAL(38,15),
		@Station621 DECIMAL(38,15),
		@Station623 DECIMAL(38,15),
		@Station626 DECIMAL(38,15),
		@Station629 DECIMAL(38,15),
		@Station630 DECIMAL(38,15),
		@Station631 DECIMAL(38,15),
		@Station632 DECIMAL(38,15),
		@Station635 DECIMAL(38,15),
		@Station636 DECIMAL(38,15),
		@Station637 DECIMAL(38,15),
		@Station640 DECIMAL(38,15),
		@Station642 DECIMAL(38,15),
		@Station644 DECIMAL(38,15),
		@Station646 DECIMAL(38,15),
		@Station648 DECIMAL(38,15),
		@Station649 DECIMAL(38,15),
		@Station650 DECIMAL(38,15),
		@Station652 DECIMAL(38,15),
		@Station653 DECIMAL(38,15),
		@Station654 DECIMAL(38,15),
		@Station655 DECIMAL(38,15),
		@Station656 DECIMAL(38,15),
		@Station657 DECIMAL(38,15),
		@Station658 DECIMAL(38,15),
		@Station659 DECIMAL(38,15),
		@Station660 DECIMAL(38,15),
		@Station662 DECIMAL(38,15),
		@Station663 DECIMAL(38,15),
		@Station664 DECIMAL(38,15),
		@Station666 DECIMAL(38,15),
		@Station667 DECIMAL(38,15),
		@Station668 DECIMAL(38,15),
		@Station671 DECIMAL(38,15),
		@Station672 DECIMAL(38,15),
		@Station673 DECIMAL(38,15),
		@Station674 DECIMAL(38,15),
		@Station675 DECIMAL(38,15),
		@Station676 DECIMAL(38,15),
		@Station678 DECIMAL(38,15),
		@Station679 DECIMAL(38,15),
		@Station687 DECIMAL(38,15),
		@Station688 DECIMAL(38,15),
		@Station689 DECIMAL(38,15),
		@Station691 DECIMAL(38,15),
		@Station692 DECIMAL(38,15),
		@Station693 DECIMAL(38,15),
		@Station695 DECIMAL(38,15),
		@Station740 DECIMAL(38,15),							--06/12/2018 remove comment "--" to activate line of code
		@Station756 DECIMAL(38,15),
		@Station757 DECIMAL(38,15),
		@VISN1		DECIMAL(38,15),
		@VISN10		DECIMAL(38,15),
		@VISN11		DECIMAL(38,15),
		@VISN12		DECIMAL(38,15),
		@VISN15		DECIMAL(38,15),
		@VISN16		DECIMAL(38,15),
		@VISN17		DECIMAL(38,15),
		@VISN18		DECIMAL(38,15),
		@VISN19		DECIMAL(38,15),
		@VISN2		DECIMAL(38,15),
		@VISN20		DECIMAL(38,15),
		@VISN21		DECIMAL(38,15),
		@VISN22		DECIMAL(38,15),
		@VISN23		DECIMAL(38,15),
		@VISN3		DECIMAL(38,15),
		@VISN4		DECIMAL(38,15),
		@VISN5		DECIMAL(38,15),
		@VISN6		DECIMAL(38,15),
		@VISN7		DECIMAL(38,15),
		@VISN8		DECIMAL(38,15),
		@VISN9		DECIMAL(38,15);


	------------------------------------------------ PRT 07/15/2017
	-- get parameters for SAS extract file (Overdose)
	------------------------------------------------ 

	DROP TABLE IF EXISTS #RiskScore_tmp_OVERDOSE_EXTRACT 
	SELECT CONCAT(effect,COALESCE (CONVERT(VARCHAR(1),Value1), CONVERT(VARCHAR(1),Value2), Value3)) AS "EFFECT"
		,estimate 
	INTO #RiskScore_tmp_OVERDOSE_EXTRACT FROM ORM.Model_Overdose_SAS                  

	------------------------------------------------------------------- PRT 07/15/2017
	-- REPLACE '*' in variable name (doesn't work well with SQL Server)
	--------------------------------------------------------------------
	UPDATE #RiskScore_tmp_OVERDOSE_EXTRACT
	SET Effect = REPLACE(Effect,'*','_X_')				 

	------------------------------------------------ PRT 07/15/2017
	-- Get DISTINCT values of the PIVOT Column 
	------------------------------------------------
	SELECT @ColumnName1= ISNULL(@ColumnName1 + ',','') 
		   + QUOTENAME(EFFECT)
	FROM (SELECT DISTINCT Effect FROM #RiskScore_tmp_OVERDOSE_EXTRACT) AS COL1;

	------------------------------------------------ PRT 07/15/2017
	--Prepare the PIVOT query using the dynamic 
	------------------------------------------------
	DROP TABLE IF EXISTS ##RiskScore_tmp_OVERDOSE_PIVOT 
	SET @DynamicPivotQuery = 
	  N'SELECT  ' + @ColumnName1 + '
		INTO ##RiskScore_tmp_OVERDOSE_PIVOT
		FROM #RiskScore_tmp_OVERDOSE_EXTRACT
		PIVOT(MIN(Estimate) 
			  FOR EFFECT IN (' + @ColumnName1 + ')) AS PVT1'
	EXEC sp_executesql @DynamicPivotQuery;    

	------------------------------------------------ PRT 07/15/2017
	--- Read Overdose Parameter Table INTO Variables
	------------------------------------------------
	SELECT 
		 @Intercept  =  intercept,
		 @TotalMEDD  =  dosepct90,
		 @LongActing  =  FY10_Tier1,
		 @ChronicShortActing  =  FY10_Tier2,
		 @NonChronicShortActing  =  FY10_Tier3,
		 @TramadolOnly  =  FY10_Tier4,
		 @Age30  =  agegrp1,
		 @Age3150  =  agegrp2,
		 @Age5165  =  agegrp3,
		 @Age66  =  agegrp4,
		 @GenderMale  =  FY10_gender,
		 @SumOverdose_Suicide  =  Over_suicide,
		 @AnySAE  =  sedate_issue,
		 @Sum_Painadj3  =  sedate_mednewx3,
		 @Sum_Painadj2  =  sedate_mednewx2,
		 @Sum_Painadj1  =  sedate_mednewx1,
		 @Sum_Painadj0  =  sedate_mednewx0,
		 @AUD_ORM  =  FY10_ALCdx_poss,
		 @OUD  =  FY10_OPIDdx_poss,
		 @Psych_poss  =  OtherMH_poss10,
		 @MHInpat  =  FY10_Intrt,
		 @BIPOLAR  =  FY10_AFFdx_poss,
		 @PTSD  =  FY10_PTSDdx_poss,
		 @MDD  =  FY10_MDDdx_poss,
		 @NicDx_Poss  =  FY10_NICdx_poss,
		 @SedativeOpioid_Rx  =  FY10_SEDRX,
		 @Detox_CPT  =  FY10_A1bii_detox,
		 @OtherSUD_RiskModel  =  OtherSUD_poss10,
		 @ERvisit  =  ERvisit,
		 @SedativeUseDisorder  =  Barbdx_poss10,
		 @SleepApnea  =  SleepApnea,
		 @Osteoporosis  =  Osteoporosis,
		 @CannabisUD_HallucUD  =  Cann_Hul_dx10,
		 @CocaineUD_AmphUD  =  Stimulant_dx10,
		 @EH_HEART  =  FY10_EH_HEART,
		 @EH_ARRHYTH  =  FY10_EH_ARRHYTH,
		 @EH_VALVDIS  =  FY10_EH_VALVDIS,
		 @EH_PULMCIRC  =  FY10_EH_PULMCIRC,
		 @EH_PERIVALV  =  FY10_EH_PERIVALV,
		 @EH_HYPERTENS  =  FY10_EH_HYPERTENS,
		 @EH_PARALYSIS  =  FY10_EH_PARALYSIS,
		 @EH_OTHNEURO  =  FY10_EH_OTHNEURO,
		 @EH_CHRNPULM  =  FY10_EH_CHRNPULM,
		 @EH_UNCDIAB  =  FY10_EH_UNCDIAB,
		 @EH_COMDIAB  =  FY10_EH_COMDIAB,
		 @EH_HYPOTHY  =  FY10_EH_HYPOTHY,
		 @EH_RENAL  =  FY10_EH_RENAL,
		 @EH_LIVER  =  FY10_EH_LIVER,
		 @EH_PEPTICULC  =  FY10_EH_PEPTICULC,
		 @EH_AIDS  =  FY10_EH_AIDS,
		 @EH_LYMPHOMA  =  FY10_EH_LYMPHOMA,
		 @EH_METCANCR  =  FY10_EH_METCANCR,
		 @EH_NMETTUMR  =  FY10_EH_NMETTUMR,
		 @EH_RHEUMART  =  FY10_EH_RHEUMART,
		 @EH_COAG  =  FY10_EH_COAG,
		 @EH_OBESITY  =  FY10_EH_OBESITY,
		 @EH_WEIGHTLS  =  FY10_EH_WEIGHTLS,
		 @EH_ELECTRLYTE  =  FY10_EH_ELECTRLYTE,
		 @EH_BLANEMIA  =  FY10_EH_BLANEMIA,
		 @EH_DefANEMIA  =  FY10_EH_DefANEMIA,
		 @TotalMEDD_Age30  =  dosepct90_X_agegrp1,
		 @TotalMEDD_Age3150  =  dosepct90_X_agegrp2,
		 @TotalMEDD_Age5165  =  dosepct90_X_agegrp3,
		 @TotalMEDD_Age66  =  dosepct90_X_agegrp4,
		 @TotalMEDD_OUD  =  dosepct90_X_FY10_OPIDd,
		 @TotalMEDD_MDD  =  dosepct90_X_FY10_MDDdx,
		 @GenderMale_LongActing  =  FY10_gende_X_FY10_Tier1,
		 @GenderMale_ChronicShortActing  =  FY10_gende_X_FY10_Tier2,
		 @GenderMale_NonChronicShortActing  =  FY10_gende_X_FY10_Tier3,
		 @GenderMale_TramadolOnly  =  FY10_gende_X_FY10_Tier4,
		 @SumOverdose_Suicide_Age30  =  Over_suicide_X_agegrp1,
		 @SumOverdose_Suicide_Age3150  =  Over_suicide_X_agegrp2,
		 @SumOverdose_Suicide_Age5165  =  Over_suicide_X_agegrp3,
		 @SumOverdose_Suicide_Age66  =  Over_suicide_X_agegrp4,
		 @AnySAE_Age30  =  sedate_issue_X_agegrp1,
		 @AnySAE_Age3150  =  sedate_issue_X_agegrp2,
		 @AnySAE_Age5165  =  sedate_issue_X_agegrp3,
		 @AnySAE_Age66  =  sedate_issue_X_agegrp4,
		 @ERvisit_Age30  =  ERvisit_X_agegrp1,
		 @ERvisit_Age3150  =  ERvisit_X_agegrp2,
		 @ERvisit_Age5165  =  ERvisit_X_agegrp3,
		 @ERvisit_Age66  =  ERvisit_X_agegrp4,
		 @GenderMale_PTSD  =  FY10_gend_X_FY10_PTSDd,
		 @SumOverdose_Suicide_MHInpat  =  Over_suic_X_FY10_Intrt,
		 @SumOverdose_Suicide_OtherSUD_RiskModel  =  Over_suic_X_suddx_othe,
		 @SumOverdose_Suicide_ERvisit  =  Over_suicide_X_ERvisit,
		 @MDD_Sum_Painadj3  =  FY10_MDDd_X_sedate_med3,
		 @MDD_Sum_Painadj2  =  FY10_MDDd_X_sedate_med2,
		 @MDD_Sum_Painadj1  =  FY10_MDDd_X_sedate_med1,
		 @MDD_Sum_Painadj0  =  FY10_MDDd_X_sedate_med0,
		 @OtherSUD_RiskModel_Sum_Painadj3  =  OtherSUD_X_sedate_med3,
		 @OtherSUD_RiskModel_Sum_Painadj2  =  OtherSUD_X_sedate_med2,
		 @OtherSUD_RiskModel_Sum_Painadj1  =  OtherSUD_X_sedate_med1,
		 @OtherSUD_RiskModel_Sum_Painadj0  =  OtherSUD_X_sedate_med0,
		 @CannabisUD_HallucUD_Sum_Painadj3  =  Cann_Hul__X_sedate_med3,
		 @CannabisUD_HallucUD_Sum_Painadj2  =  Cann_Hul__X_sedate_med2,
		 @CannabisUD_HallucUD_Sum_Painadj1  =  Cann_Hul__X_sedate_med1,
		 @CannabisUD_HallucUD_Sum_Painadj0  =  Cann_Hul__X_sedate_med0,
		 @AUD_ORM_MDD  =  FY10_ALCd_X_FY10_MDDdx,
		 @AUD_ORM_CannabisUD_HallucUD  =  FY10_ALCd_X_Cann_Hul_d,
		 @AUD_ORM_CocaineUD_AmphUD  =  FY10_ALCd_X_Stimulant_,
		 @MHInpat_NicDx_Poss  =  FY10_Intr_X_FY10_NICdx,
		 @MHInpat_ERvisit  =  FY10_Intrt_X_ERvisit,
		 @Bipolar_PTSD  =  FY10_AFFd_X_FY10_PTSDd,
		 @Bipolar_MDD  =  FY10_AFFd_X_FY10_MDDdx,
		 @Bipolar_CannabisUD_HallucUD  =  FY10_AFFd_X_Stimulant_,
		 @PTSD_MDD  =  FY10_PTSD_X_FY10_MDDdx,
		 @NicDx_Poss_OtherSUD_RiskModel  =  FY10_NICd_X_suddx_othe,
		 @MHInpat_SedativeOpioid_Rx  =  FY10_Intr_X_FY10_SEDRX,
		 @OtherSUD_RiskModel_CannabisUD_HallucUD  =  OtherSUD__X_Stimulant_

	FROM 
		##RiskScore_tmp_OVERDOSE_PIVOT  

	DROP TABLE IF EXISTS ##RiskScore_tmp_OVERDOSE_PIVOT 

	----------------------------------------------------------------------------------------------


	-------------------------------------------------------- PRT 07/15/2017
	-- get parameters for SAS extract file (Overdose Random)
	--------------------------------------------------------
	DROP TABLE IF EXISTS #RiskScore_tmp_OVERDOSE_RANDOM_EXTRACT
	SELECT CASE WHEN Effect like 'Visn%' THEN 'VISN' + SUBSTRING(Effect,6,2) 
				WHEN Effect like 'Sta3n%' THEN 'Station' + SUBSTRING(Effect,15,3)
		   ELSE EFFECT
		   END AS "EFFECT", 
		   Estimate
	INTO #RiskScore_tmp_OVERDOSE_RANDOM_EXTRACT
	FROM [ORM].[Model_Overdose_Random_SAS] 

	----------------------------------------- PRT 07/15/2017
	--Get DISTINCT values of the PIVOT Column 
	-----------------------------------------
	SELECT @ColumnName2= ISNULL(@ColumnName2 + ',','') 
		   + QUOTENAME(EFFECT)
	FROM (SELECT DISTINCT Effect FROM #RiskScore_tmp_OVERDOSE_RANDOM_EXTRACT) AS COL2

	------------------------------------------- PRT 07/15/2017
	--Prepare the PIVOT query using the dynamic 
	-------------------------------------------
	DROP TABLE IF EXISTS ##RiskScore_tmp_OVERDOSE_RANDOM_PIVOT
	SET @DynamicPivotQuery = 
	  N'SELECT  ' + @ColumnName2 + '
		INTO ##RiskScore_tmp_OVERDOSE_RANDOM_PIVOT
		FROM #RiskScore_tmp_OVERDOSE_RANDOM_EXTRACT
		PIVOT(MIN(Estimate) 
			  FOR EFFECT IN (' + @ColumnName2 + ')) AS PVT2'
	EXEC sp_executesql @DynamicPivotQuery;

	---------------------------------------------------------------- PRT 07/15/2017
	--- Read Overdose Random (Station AND VISN) Table INTO Variables
	----------------------------------------------------------------
	SELECT
		@Station358 = Station358,
		@Station402 = Station402,
		@Station405 = Station405,
		@Station436 = Station436,
		@Station437 = Station437,
		@Station438 = Station438,
		@Station442 = Station442,
		@Station459 = Station459,
		@Station460 = Station460,
		@Station463 = Station463,
		@Station501 = Station501,
		@Station502 = Station502,
		@Station503 = Station503,
		@Station504 = Station504,
		@Station506 = Station506,
		@Station508 = Station508,
		@Station509 = Station509,
		@Station512 = Station512,
		@Station515 = Station515,
		@Station516 = Station516,
		@Station517 = Station517,
		@Station518 = Station518,
		@Station519 = Station519,
		@Station520 = Station520,
		@Station521 = Station521,
		@Station523 = Station523,
		@Station526 = Station526,
		@Station528 = Station528,
		@Station529 = Station529,
		@Station531 = Station531,
		@Station534 = Station534,
		@Station537 = Station537,
		@Station538 = Station538,
		@Station539 = Station539,
		@Station540 = Station540,
		@Station541 = Station541,
		@Station542 = Station542,
		@Station544 = Station544,
		@Station546 = Station546,
		@Station548 = Station548,
		@Station549 = Station549,
		@Station550 = Station550,
		@Station552 = Station552,
		@Station553 = Station553,
		@Station554 = Station554,
		@Station556 = Station556,
		@Station557 = Station557,
		@Station558 = Station558,
		@Station561 = Station561,
		@Station562 = Station562,
		@Station564 = Station564,
		@Station565 = Station565,
		@Station568 = Station568,
		@Station570 = Station570,
		@Station573 = Station573,
		@Station575 = Station575,
		@Station578 = Station578,
		@Station580 = Station580,
		@Station581 = Station581,
		@Station583 = Station583,
		@Station585 = Station585,
		@Station586 = Station586,
		@Station589 = Station589,
		@Station590 = Station590,
		@Station593 = Station593,
		@Station595 = Station595,
		@Station596 = Station596,
		@Station598 = Station598,
		@Station600 = Station600,
		@Station603 = Station603,
		@Station605 = Station605,
		@Station607 = Station607,
		@Station608 = Station608,
		@Station610 = Station610,
		@Station612 = Station612,
		@Station613 = Station613,
		@Station614 = Station614,
		@Station618 = Station618,
		@Station619 = Station619,
		@Station620 = Station620,
		@Station621 = Station621,
		@Station623 = Station623,
		@Station626 = Station626,
		@Station629 = Station629,
		@Station630 = Station630,
		@Station631 = Station631,
		@Station632 = Station632,
		@Station635 = Station635,
		@Station636 = Station636,
		@Station637 = Station637,
		@Station640 = Station640,
		@Station642 = Station642,
		@Station644 = Station644,
		@Station646 = Station646,
		@Station648 = Station648,
		@Station649 = Station649,
		@Station650 = Station650,
		@Station652 = Station652,
		@Station653 = Station653,
		@Station654 = Station654,
		@Station655 = Station655,
		@Station656 = Station656,
		@Station657 = Station657,
		@Station658 = Station658,
		@Station659 = Station659,
		@Station660 = Station660,
		@Station662 = Station662,
		@Station663 = Station663,
		@Station664 = Station664,
		@Station666 = Station666,
		@Station667 = Station667,
		@Station668 = Station668,
		@Station671 = Station671,
		@Station672 = Station672,
		@Station673 = Station673,
		@Station674 = Station674,
		@Station675 = Station675,
		@Station676 = Station676,
		@Station678 = Station678,
		@Station679 = Station679,
		@Station687 = Station687,
		@Station688 = Station688,
		@Station689 = Station689,
		@Station691 = Station691,
		@Station692 = Station692,
		@Station693 = Station693,
		@Station695 = Station695,
		@Station740 = 0,							--06/12/2018 add this line of code
		@Station756 = Station756,
		@Station757 = Station757,
		@VISN1 = VISN1,
		@VISN10 = VISN10,
		@VISN11 = VISN11,
		@VISN12 = VISN12,
		@VISN15 = VISN15,
		@VISN16 = VISN16,
		@VISN17 = VISN17,
		@VISN18 = VISN18,
		@VISN19 = VISN19,
		@VISN2 =  VISN2,
		@VISN20 = VISN20,
		@VISN21 = VISN21,
		@VISN22 = VISN22,
		@VISN23 = VISN23,
		@VISN3 =  VISN3,
		@VISN4 =  VISN4,
		@VISN5 =  VISN5,
		@VISN6 =  VISN6,
		@VISN7 =  VISN7,
		@VISN8 =  VISN8,
		@VISN9 =  VISN9
	FROM
		##RiskScore_tmp_OVERDOSE_RANDOM_PIVOT   

	DROP TABLE IF EXISTS ##RiskScore_tmp_OVERDOSE_RANDOM_PIVOT   

	----------------------------------------------------------------------
	----------------------------------------------------------------------
	--  BUILD TEMP TABLE OF OVERDOSE MODEL CALCULATIONS IN 3 PARTS
	--		1. ALL THE VARIABLES EXCEPT "TOTAL MEDS" AND "SEDATIVES"
	--		2. TOTAL MEDICATIONS
	--		3. SEDATIVES (RX OPIOIDS)
	--  THESE 3 TOTALS WILL BE USING IN CALUCATING THE VARIOUS RISK SCORES 
	----------------------------------------------------------------------
	----------------------------------------------------------------------
 
	DROP TABLE IF EXISTS #Temp_Ovr;
	SELECT a.MVIPersonSID,
     
			/*Intercept*/
			@Intercept
				
			/*Demographics*/ 
			+ (Age30 * @Age30)  --- needs to be updated in RM code (verify with Tom that these are the categories for "Any Adverse Model"
			+ (Age3150 * @Age3150) --- needs to be updated in RM code
			+ (Age5165 * @Age5165) --- needs to be updated in RM code
			+ (Age66 * @Age66) --- needs to be updated in RM code
			+ (GenderMale * @GenderMale) -- switch name in RM code Male = 1

			/*Medications*/ 
	--	    + (TotalMEDD * @TotalMEDD) 
			+ ([LongActing] * @LongActing) 
			+ ([ChronicShortActing] * @ChronicShortActing) 
			+ ([NonChronicShortActing] * @NonChronicShortActing) 
			+ ([TramadolOnly] * @TramadolOnly) 
	--		+ ([SedativeRx_Opioid] * @SedativeRx_Opioid)		
			+ ( --NEW     
				CASE 
					WHEN [Sum_Painadj] = 3 --NEW
						THEN @Sum_Painadj3
					WHEN [Sum_Painadj] = 2 --NEW
						THEN @Sum_Painadj2
					WHEN [Sum_Painadj] = 1 --NEW
						THEN @Sum_Painadj1
					WHEN [Sum_Painadj] = 0 --NEW
						THEN @Sum_Painadj0
					END 
				) 

			/*Adverse Events*/    
			+ (SumOverdose_Suicide * @SumOverdose_Suicide) 
			+ (AnySAE * @AnySAE)  

			/*MH Comorbidity*/	
			+ ([Other_MH_STORM] * @Psych_poss) 
			+ ([BIPOLAR] * @BIPOLAR) 
			+ (PTSD * @PTSD ) 
			+ ([MDD] * @MDD)  

			/*SUD Comorbidity*/	
			+ ([NicDx_Poss] * @NicDx_Poss)
			+ ([AUD_ORM] * @AUD_ORM) 
			+ (OUD * @OUD) 
			+ ([OtherSUD_RiskModel] * @OtherSUD_RiskModel) --Fix ICD10 dx
			+ (SedativeUseDisorder * @SedativeUseDisorder) --NEW
			+ (CannabisUD_HallucUD * @CannabisUD_HallucUD) --NEW
			+ (CocaineUD_AmphUD * @CocaineUD_AmphUD)  --NEW
					
			/*Medical Comorbidity*/		
			+ ([EH_HEART] * @EH_HEART) 
			+ ([EH_ARRHYTH] * @EH_ARRHYTH) 
			+ ([EH_VALVDIS] * @EH_VALVDIS) 
			+ ([EH_PULMCIRC] * @EH_PULMCIRC) 
			+ ([EH_PERIVALV] * @EH_PERIVALV) 
			+ (EH_HYPERTENS * @EH_HYPERTENS)
			+ ([EH_PARALYSIS] * @EH_PARALYSIS)
			+ ([EH_OTHNEURO] * @EH_OTHNEURO) 
			+ ([EH_CHRNPULM] * @EH_CHRNPULM) 
			+ ([EH_COMDIAB] * @EH_COMDIAB) 
			+ (EH_UNCDIAB * @EH_UNCDIAB) 
			+ ([EH_HYPOTHY] * @EH_HYPOTHY) 
			+ (EH_RENAL * @EH_RENAL)
			+ ([EH_LIVER] * @EH_LIVER) 
			+ ([EH_PEPTICULC] * @EH_PEPTICULC) 
			+ ([EH_AIDS] * @EH_AIDS) 
			+ (EH_NMETTUMR * @EH_NMETTUMR) 
			+ ([EH_ELECTRLYTE] * @EH_ELECTRLYTE) 
			+ ([EH_RHEUMART] * @EH_RHEUMART) 
			+ ([EH_COAG] * @EH_COAG) 
			+ (EH_WEIGHTLS * @EH_WEIGHTLS)
			+ ([EH_DefANEMIA] * @EH_DefANEMIA) 
			+ (EH_LYMPHOMA * @EH_LYMPHOMA) --new?
			+ (EH_METCANCR * @EH_METCANCR) 
			+ (EH_OBESITY * @EH_OBESITY) 
			+ (EH_BLANEMIA * @EH_BLANEMIA) 
			+ ([SleepApnea] * @SleepApnea)
			+ ([Osteoporosis] * @Osteoporosis)
				
				/*Setting*/		
			+ (Detox_CPT * @Detox_CPT) 
			+ (MHInpat * @MHInpat) 
			+ (ERvisit * @ERvisit) --NEW

				/*Interactions*/	
			+ (TotalMEDD * Age30 *  @TotalMEDD_Age30) --NEW  interactiondosepct90Agegrp
			+ (TotalMEDD * Age3150 * @TotalMEDD_Age3150) --NEW  interactiondosepct90Agegrp
			+ (TotalMEDD * Age5165 * @TotalMEDD_Age5165) --NEW  interactiondosepct90Agegrp
			+ (TotalMEDD * Age66 * @TotalMEDD_Age66) --NEW  interactiondosepct90Agegrp
			+ (TotalMEDD * a.OUD * @TotalMEDD_OUD) --NEW  InteractionDosepct90OpidDx
			+ (TotalMEDD * MDD * @TotalMEDD_MDD) --NEW  InteractionDosepct90MDDdx	
		
			+ (GenderMale * [LongActing] * @GenderMale_LongActing ) --NEW  [InteractionGenderLongActing]
			+ (GenderMale * [ChronicShortActing] * @GenderMale_ChronicShortActing ) --NEW  [InteractionGenderChronicShortActing]
			+ (GenderMale * [NonChronicShortActing]  * @GenderMale_NonChronicShortActing ) --NEW  [InteractionGenderNonChronicShortActing]
			+ (GenderMale * [TramadolOnly] * @GenderMale_TramadolOnly ) --NEW  InteractionGenderTramadolOnly
				
			+ (SumOverdose_Suicide * Age30 * @SumOverdose_Suicide_Age30) --NEW  InteractionSumOverdose_SuicideAgegrp
			+ (SumOverdose_Suicide * Age3150 * @SumOverdose_Suicide_Age3150) --NEW  InteractionSumOverdose_SuicideAgegrp
			+ (SumOverdose_Suicide * Age5165 * @SumOverdose_Suicide_Age5165 )	--NEW  InteractionSumOverdose_SuicideAgegrp
			+ (SumOverdose_Suicide * Age66 * @SumOverdose_Suicide_Age66) --NEW  InteractionSumOverdose_SuicideAgegrp			

			+ (AnySAE  * Age30 * @AnySAE_Age30) --NEW [InteractionSedateIssueAgegrp]
			+ (AnySAE * Age3150 * @AnySAE_Age3150 )--NEW [InteractioSedateIssueAgegrp]
			+ (AnySAE * Age5165 *  @AnySAE_Age5165) --NEW [InteractionSedateIssueAgegrp]
			+ (AnySAE * Age66 * @AnySAE_Age66) --NEW [InteractionSedateIssueAgegrp]

			+ (ERvisit  * Age30 * @ERvisit_Age30) --NEW [InteractionERvisitAgegrp]
			+ (ERvisit * Age3150 * @ERvisit_Age3150)--NEW [InteractionERvisitAgegrp]
			+ (ERvisit  * Age5165 *  @ERvisit_Age5165) --NEW [InteractionERvisitAgegrp]
			+ (ERvisit * Age66 * @ERvisit_Age66) --NEW [InteractionERvisitAgegrp]
								
			+ (GenderMale * PTSD * @GenderMale_PTSD) --NEW InteractionGenderPTSD

			+ (SumOverdose_Suicide * MHInpat * @SumOverdose_Suicide_MHInpat) 
			+ (SumOverdose_Suicide * [OtherSUD_RiskModel] * @SumOverdose_Suicide_OtherSUD_RiskModel)  --NEW  InteractionSumOverdose_SuicideOtherSUD_RiskModel 
			+ (SumOverdose_Suicide * ERvisit * @SumOverdose_Suicide_ERvisit)  --NEW InteractionSumOverdose_SuicideERvisit
				
			+ ( MDD * --NEW InteractionMDDSum_Painadj 
				CASE 
					WHEN [Sum_Painadj] = 3 --NEW Painadj IS inverted (use 3 classes = 0 (category))
						THEN @MDD_Sum_Painadj3
					WHEN [Sum_Painadj] = 2 --NEW Painadj IS inverted (use 2 classes = 1 (category))
						THEN @MDD_Sum_PainadJ2
					WHEN [Sum_Painadj] = 1 --NEW Painadj IS inverted (use 1 classes = 2 (category))
						THEN @MDD_Sum_PainadJ1
					WHEN [Sum_Painadj] = 0 --NEW Painadj IS inverted (use 0 classes = 3 (category))
						THEN @MDD_Sum_PainadJ0
					END
				)

			+ ( OtherSUD_RiskModel *--NEW InteractionOtherSUD_RiskModelSum_Painadj 
				CASE 
					WHEN [Sum_Painadj] = 3 --NEW Painadj IS inverted (use 3 classes = 0 (category))
						THEN @OtherSUD_RiskModel_Sum_Painadj3
					WHEN [Sum_Painadj] = 2 --NEW Painadj IS inverted (use 2 classes = 1 (category))
						THEN @OtherSUD_RiskModel_Sum_Painadj2
					WHEN [Sum_Painadj] = 1 --NEW Painadj IS inverted (use 1 classes = 2 (category))
						THEN @OtherSUD_RiskModel_Sum_Painadj1
					WHEN [Sum_Painadj] = 0 --NEW Painadj IS inverted (use 0 classes = 3 (category))
						THEN @OtherSUD_RiskModel_Sum_Painadj0
					END
				)

			+ ( CannabisUD_HallucUD *--NEW  InteractionCannHulSum_Painadj 
				CASE 
					WHEN [Sum_Painadj] = 3 --NEW Painadj IS inverted (use 3 classes = 0 (category))
						THEN @CannabisUD_HallucUD_Sum_Painadj3
					WHEN [Sum_Painadj] = 2 --NEW Painadj IS inverted (use 2 classes = 1 (category))
						THEN @CannabisUD_HallucUD_Sum_Painadj2
					WHEN [Sum_Painadj] = 1 --NEW Painadj IS inverted (use 1 classes = 2 (category))
						THEN @CannabisUD_HallucUD_Sum_Painadj1
					WHEN [Sum_Painadj] = 0 --NEW Painadj IS inverted (use 0 classes = 3 (category))
						THEN @CannabisUD_HallucUD_Sum_Painadj0
					END	
				)
				+ (AUD_ORM * MDD * @AUD_ORM_MDD) --NEW Interaction
				+ (AUD_ORM * CannabisUD_HallucUD * @AUD_ORM_CannabisUD_HallucUD) --NEW  Interaction
				+ (AUD_ORM * CocaineUD_AmphUD * @AUD_ORM_CocaineUD_AmphUD) --NEW  Interaction

				+ (MHInpat * NicDx_Poss * @MHInpat_NicDx_Poss) --NEW  Interaction 
				+ (MHInpat  * ERvisit * @MHInpat_ERvisit)  --NEW  Interaction	

				+ (Bipolar * PTSD *  @Bipolar_PTSD)  --NEW  Interaction
				+ (Bipolar * MDD *  @Bipolar_mdd) --NEW  Interaction
				+ (Bipolar * CannabisUD_HallucUD * @Bipolar_CannabisUD_HallucUD) --NEW  Interaction	

				+ (PTSD  * MDD * @PTSD_MDD)  --NEW  Interaction
				+ (NicDx_Poss  * OtherSUD_RiskModel * @NicDx_Poss_OtherSUD_RiskModel)  --NEW  Interaction
				+ (MHInpat * SedativeOpioid_Rx * @MHInpat_SedativeOpioid_Rx)  --NEW  Interaction
				+ (OtherSUD_RiskModel  * CannabisUD_HallucUD * @OtherSUD_RiskModel_CannabisUD_HallucUD)  --NEW  Interaction

				/*VISN*/
				+ (
				CASE -- VISN
					WHEN [VISN] = 1	THEN @VISN1
					WHEN [VISN] = 2 THEN @VISN2
					WHEN [VISN] = 3 THEN @VISN3
					WHEN [VISN] = 4 THEN @VISN4
					WHEN [VISN] = 5 THEN @VISN5
					WHEN [VISN] = 6 THEN @VISN6
					WHEN [VISN] = 7 THEN @VISN7
					WHEN [VISN] = 8 THEN @VISN8
					WHEN [VISN] = 9 THEN @VISN9
					WHEN [VISN] = 10 THEN @VISN10
					WHEN [VISN] = 11 THEN @VISN11
					WHEN [VISN] = 12 THEN @VISN12
					WHEN [VISN] = 15 THEN @VISN15
					WHEN [VISN] = 16 THEN @VISN16
				--	WHEN [VISN] = 17 THEN @VISN17							--06/12/2018 add comment "--" to deactivate line of code
					WHEN [VISN] = 17 AND [STA3N] = 740 THEN 0				--06/12/2018 add line of code
					WHEN [VISN] = 17 AND [STA3N] <> 740 THEN @VISN17		--06/12/2018 add line of code	
					WHEN [VISN] = 18 THEN @VISN18
					WHEN [VISN] = 19 THEN @VISN19
					WHEN [VISN] = 20 THEN @VISN20
					WHEN [VISN] = 21 THEN @VISN21
					WHEN [VISN] = 22 THEN @VISN22
					WHEN [VISN] = 23 THEN @VISN23
					WHEN [VISN] = 0 THEN 0
					END
				)  
					+ (
				CASE -- STA3N
					WHEN [STA3N] = 358 THEN @Station358
					WHEN [STA3N] = 402 THEN @Station402
					WHEN [STA3N] = 405 THEN @Station405
					WHEN [STA3N] = 436 THEN @Station436
					WHEN [STA3N] = 437 THEN @Station437
					WHEN [STA3N] = 438 THEN @Station438
					WHEN [STA3N] = 442 THEN @Station442
					WHEN [STA3N] = 459 THEN @Station459
					WHEN [STA3N] = 460 THEN @Station460
					WHEN [STA3N] = 463 THEN @Station463
					WHEN [STA3N] = 501 THEN @Station501
					WHEN [STA3N] = 502 THEN @Station502
					WHEN [STA3N] = 503 THEN @Station503
					WHEN [STA3N] = 504 THEN @Station504
					WHEN [STA3N] = 506 THEN @Station506
					WHEN [STA3N] = 508 THEN @Station508
					WHEN [STA3N] = 509 THEN @Station509
					WHEN [STA3N] = 512 THEN @Station512
					WHEN [STA3N] = 515 THEN @Station515
					WHEN [STA3N] = 516 THEN @Station516
					WHEN [STA3N] = 517 THEN @Station517
					WHEN [STA3N] = 518 THEN @Station518
					WHEN [STA3N] = 519 THEN @Station519
					WHEN [STA3N] = 520 THEN @Station520
					WHEN [STA3N] = 521 THEN @Station521
					WHEN [STA3N] = 523 THEN @Station523
					WHEN [STA3N] = 526 THEN @Station526
					WHEN [STA3N] = 528 THEN @Station528
					WHEN [STA3N] = 529 THEN @Station529
					WHEN [STA3N] = 531 THEN @Station531
					WHEN [STA3N] = 534 THEN @Station534
					WHEN [STA3N] = 537 THEN @Station537
					WHEN [STA3N] = 538 THEN @Station538
					WHEN [STA3N] = 539 THEN @Station539
					WHEN [STA3N] = 540 THEN @Station540
					WHEN [STA3N] = 541 THEN @Station541
					WHEN [STA3N] = 542 THEN @Station542
					WHEN [STA3N] = 544 THEN @Station544
					WHEN [STA3N] = 546 THEN @Station546
					WHEN [STA3N] = 548 THEN @Station548
					WHEN [STA3N] = 549 THEN @Station549
					WHEN [STA3N] = 550 THEN @Station550
					WHEN [STA3N] = 552 THEN @Station552
					WHEN [STA3N] = 553 THEN @Station553
					WHEN [STA3N] = 554 THEN @Station554
					WHEN [STA3N] = 556 THEN @Station556
					WHEN [STA3N] = 557 THEN @Station557
					WHEN [STA3N] = 558 THEN @Station558
					WHEN [STA3N] = 561 THEN @Station561
					WHEN [STA3N] = 562 THEN @Station562
					WHEN [STA3N] = 564 THEN @Station564
					WHEN [STA3N] = 565 THEN @Station565
					WHEN [STA3N] = 568 THEN @Station568
					WHEN [STA3N] = 570 THEN @Station570
					WHEN [STA3N] = 573 THEN @Station573
					WHEN [STA3N] = 575 THEN @Station575
					WHEN [STA3N] = 578 THEN @Station578
					WHEN [STA3N] = 580 THEN @Station580
					WHEN [STA3N] = 581 THEN @Station581
					WHEN [STA3N] = 583 THEN @Station583
					WHEN [STA3N] = 585 THEN @Station585
					WHEN [STA3N] = 586 THEN @Station586
					WHEN [STA3N] = 589 THEN @Station589
					WHEN [STA3N] = 590 THEN @Station590
					WHEN [STA3N] = 593 THEN @Station593 
					WHEN [STA3N] = 595 THEN @Station595
					WHEN [STA3N] = 596 THEN @Station596
					WHEN [STA3N] = 598 THEN @Station598
					WHEN [STA3N] = 600 THEN @Station600
					WHEN [STA3N] = 603 THEN @Station603
					WHEN [STA3N] = 605 THEN @Station605
					WHEN [STA3N] = 607 THEN @Station607
					WHEN [STA3N] = 608 THEN @Station608
					WHEN [STA3N] = 610 THEN @Station610
					WHEN [STA3N] = 612 THEN @Station612
					WHEN [STA3N] = 613 THEN @Station613
					WHEN [STA3N] = 614 THEN @Station614
					WHEN [STA3N] = 618 THEN @Station618
					WHEN [STA3N] = 619 THEN @Station619
					WHEN [STA3N] = 620 THEN @Station620
					WHEN [STA3N] = 621 THEN @Station621
					WHEN [STA3N] = 623 THEN @Station623
					WHEN [STA3N] = 626 THEN @Station626
					WHEN [STA3N] = 629 THEN @Station629
					WHEN [STA3N] = 630 THEN @Station630
					WHEN [STA3N] = 631 THEN @Station631
					WHEN [STA3N] = 632 THEN @Station632   --ST edit
					WHEN [STA3N] = 635 THEN @Station635
					WHEN [STA3N] = 636 THEN @Station636
					WHEN [STA3N] = 637 THEN @Station637
					WHEN [STA3N] = 640 THEN @Station640
					WHEN [STA3N] = 642 THEN @Station642
					WHEN [STA3N] = 644 THEN @Station644
					WHEN [STA3N] = 646 THEN @Station646
					WHEN [STA3N] = 648 THEN @Station648
					WHEN [STA3N] = 649 THEN @Station649
					WHEN [STA3N] = 650 THEN @Station650
					WHEN [STA3N] = 652 THEN @Station652
					WHEN [STA3N] = 653 THEN @Station653
					WHEN [STA3N] = 654 THEN @Station654
					WHEN [STA3N] = 655 THEN @Station655
					WHEN [STA3N] = 656 THEN @Station656
					WHEN [STA3N] = 657 THEN @Station657
					WHEN [STA3N] = 658 THEN @Station658
					WHEN [STA3N] = 659 THEN @Station659
					WHEN [STA3N] = 660 THEN @Station660
					WHEN [STA3N] = 662 THEN @Station662
					WHEN [STA3N] = 663 THEN @Station663
					WHEN [STA3N] = 664 THEN @Station664
					WHEN [STA3N] = 666 THEN @Station666
					WHEN [STA3N] = 667 THEN @Station667
					WHEN [STA3N] = 668 THEN @Station668
					WHEN [STA3N] = 671 THEN @Station671
					WHEN [STA3N] = 672 THEN @Station672
					WHEN [STA3N] = 673 THEN @Station673
					WHEN [STA3N] = 674 THEN @Station674
					WHEN [STA3N] = 675 THEN @Station675
					WHEN [STA3N] = 676 THEN @Station676
					WHEN [STA3N] = 678 THEN @Station678
					WHEN [STA3N] = 679 THEN @Station679
					WHEN [STA3N] = 687 THEN @Station687
					WHEN [STA3N] = 688 THEN @Station688
					WHEN [STA3N] = 689 THEN @Station689
					WHEN [STA3N] = 691 THEN @Station691
					WHEN [STA3N] = 692 THEN @Station692
					WHEN [STA3N] = 693 THEN @Station693
					WHEN [STA3N] = 695 THEN @Station695
					WHEN [STA3N] = 740 THEN @Station740						--06/12/2018 add line of code
					WHEN [STA3N] = 756 THEN @Station756
					WHEN [STA3N] = 757 THEN @Station757
					WHEN [STA3N] = 0 THEN 0								
					END) "OVR_ALMOST_ALL"
			,CASE 
				WHEN ISNULL(p.OpioidForPain_Rx,0)=1 THEN (a.TotalMEDD * @TotalMEDD) 
				WHEN ISNULL(OUD,0)=1 THEN (90 * @TotalMEDD) 
				ELSE NULL 
				END as OVR_TOTMEDD
			,(SedativeOpioid_Rx * @SedativeOpioid_Rx) AS "OVR_SED_RX"
	INTO #TEMP_OVR
	FROM [ORM].[RiskScore] AS a										
	LEFT OUTER JOIN (
		SELECT MVIPersonSID
			  ,OpioidForPain_Rx 
		FROM [SUD].[Cohort]
		WHERE STORM = 1 OR OUD_DoD = 1 OR CommunityCare_ODPastYear = 1
		) AS p ON a.MVIPersonSID = p.MVIPersonSID

	-- Real time Risk Score Overdose/Suicide [RiskScore]
	-- Hypothetical 10% of MEDD --risk suicide/overdose [RiskScore10]
	-- Hypothetical 50% of MEDD --risk suicide/overdose [RiskScore50]
	-- Hypothetical 10% MEDD AND No sedative --risk suicide/overdose [RiskScoreNoSed]

	UPDATE [ORM].[RiskScore]											
	SET 
		[RiskScore] = ISNULL(OVR_ALMOST_ALL,0) + OVR_TOTMEDD + OVR_SED_RX ,
		[RiskScore10] = ISNULL(OVR_ALMOST_ALL,0) + (0.100000000000000 * OVR_TOTMEDD) + OVR_SED_RX,
		[RiskScore50] = ISNULL(OVR_ALMOST_ALL,0) + (0.500000000000000 * OVR_TOTMEDD) + OVR_SED_RX,
		[RiskScoreNoSed] = ISNULL(OVR_ALMOST_ALL,0) + (0.100000000000000 * OVR_TOTMEDD) + (0 * OVR_SED_RX)
	FROM [ORM].[RiskScore] a
	INNER JOIN  #TEMP_OVR b ON a.MVIPersonSID = b.MVIPersonSID
	WHERE b.OVR_TOTMEDD IS NOT NULL
	;


	/********************************************any event ****************************************/
	DECLARE 
		 @GenderFemale	DECIMAL(38,15),
		 @MHOutpatient	DECIMAL(38,15),
		 @COCNdx	DECIMAL(38,15),
		 @SUD_NoOUD_NoAUD DECIMAL(38,15),
		 @InteractionOverdoseOtherAE	DECIMAL(38,15),
		 @InteractionOverdoseInpatMHTx	DECIMAL(38,15),
		 @InteractionOUDInpatMHTx	DECIMAL(38,15),
		 @InteractionOUDAnySAE	DECIMAL(38,15),
		 @InteractionAnySAEMHInpat	DECIMAL(38,15);

	------------------------------------------------- PRT 07/15/2017
	-- get parameters for SAS extract file (AnyEvent)
	-------------------------------------------------
	DROP TABLE IF EXISTS #RiskScore_tmp_ANYEVENT_EXTRACT
	SELECT concat(REPLACE(effect,'*','_X_'), 
		   Coalesce (convert(varchar(1),Value1), convert(varchar(1),Value2), Value3)) AS "Effect", estimate
	INTO #RiskScore_tmp_ANYEVENT_EXTRACT 
	FROM [ORM].[Model_AnyEvent_SAS];   

	----------------------------------------- PRT 07/15/2017
	--Get DISTINCT values of the PIVOT Column 
	-----------------------------------------
	SELECT @ColumnName3= ISNULL(@ColumnName3 + ',','') 
		   + QUOTENAME(EFFECT)
	FROM (SELECT DISTINCT Effect FROM #RiskScore_tmp_ANYEVENT_EXTRACT) AS COL3;

	------------------------------------------- PRT 07/15/2017
	--Prepare the PIVOT query using the dynamic	
	-------------------------------------------
	DROP TABLE IF EXISTS ##RiskScore_tmp_ANYEVENT_PIVOT
	SET @DynamicPivotQuery =
	  N'SELECT  ' + @ColumnName3 + '
		INTO ##RiskScore_tmp_ANYEVENT_PIVOT
		FROM #RiskScore_tmp_ANYEVENT_EXTRACT
		PIVOT(MIN(Estimate) 
		FOR EFFECT IN (' + @ColumnName3 + ')) AS PVT3'
	EXEC sp_executesql @DynamicPivotQuery;                 

	------------------------------------------------ PRT 07/15/2017
	--- Read AnyEvent Parameter Table INTO Variables
	------------------------------------------------
	SELECT
		 @Intercept = intercept,
		 @TotalMEDD = dosepct90,
		 @LongActing = FY10_Tier1,
		 @ChronicShortActing = FY10_Tier2,
		 @NonChronicShortActing = FY10_Tier3,
		 @TramadolOnly = FY10_Tier4,
		 @Age30 = agegrp1,
		 @Age3150 = agegrp2,
		 @Age5165 = agegrp3,
		 @Age66 = agegrp4,
	 --  @GenderFemale = FY10_gender,
		 @GenderMale = FY10_gender,
		 @SumOverdose_Suicide = Over_suicide,
		 @AnySAE = sedate_issue,
		 @Sum_Painadj3 = sedate_mednewx3,
		 @Sum_Painadj2 = sedate_mednewx2,
		 @Sum_Painadj1 = sedate_mednewx1,
		 @Sum_Painadj0 = sedate_mednewx0,
		 @AUD_ORM = FY10_ALCdx_poss,
		 @OUD = FY10_OPIDdx_poss,
		 @Psych_poss = FY10_MH_other,
		 @MHInpat = FY10_Intrtx,
		 @MHOutpatient = FY10_Optrtx,
		 @BIPOLAR = FY10_AFFdx_poss,
		 @PTSD = FY10_PTSDdx_poss,
		 @MDD = FY10_MDDdx_poss,
		 @SleepApnea = SleepApnea,
		 @Osteoporosis = Osteoporosis,
		 @NicDx_Poss = FY10_NICdx_poss,
		 @SedativeOpioid_Rx = FY10_SEDRX,
		 @Detox_CPT = FY10_A1bii_detox,
		 @COCNdx = FY10_COCNdx_Poss,
		 @SUD_NoOUD_NoAUD = suddx_other,
		 @EH_HEART = FY10_EH_HEART,
		 @EH_ARRHYTH = FY10_EH_ARRHYTH,
		 @EH_VALVDIS = FY10_EH_VALVDIS,
		 @EH_PULMCIRC = FY10_EH_PULMCIRC,
		 @EH_PERIVALV = FY10_EH_PERIVALV,
		 @EH_PARALYSIS = FY10_EH_PARALYSIS,
		 @EH_OTHNEURO = FY10_EH_OTHNEURO,
		 @EH_CHRNPULM = FY10_EH_CHRNPULM,
		 @EH_COMDIAB = FY10_EH_COMDIAB,
		 @EH_HYPOTHY = FY10_EH_HYPOTHY,
		 @EH_RHEUMART = FY10_EH_RHEUMART,
		 @EH_LIVER = FY10_EH_LIVER,
		 @EH_PEPTICULC = FY10_EH_PEPTICULC,
		 @EH_AIDS = FY10_EH_AIDS,
		 @EH_COAG = FY10_EH_COAG,
		 @EH_WEIGHTLS = FY10_EH_WEIGHTLS,
		 @EH_ELECTRLYTE = FY10_EH_ELECTRLYTE,
		 @EH_DefANEMIA = FY10_EH_DefANEMIA,
		 @InteractionOverdoseOtherAE = Over_suic_X_sedate_iss,  
		 @InteractionOverdoseInpatMHTx = Over_suic_X_FY10_Intrt,
		 @InteractionOUDAnySAE = sedate_is_X_FY10_OPIDd,
		 @InteractionOUDInpatMHTx = fy10_Opid_X_fy10_intrt,
		 @InteractionAnySAEMHInpat = sedate_is_X_FY10_intrt
	FROM
		##RiskScore_tmp_ANYEVENT_PIVOT
	
	DROP TABLE IF EXISTS ##RiskScore_tmp_ANYEVENT_PIVOT
		

	------------------------------------------------------- PRT 07/15/2017
	--get parameters for SAS extract file (AnyEvent Random)
	-------------------------------------------------------
	DROP TABLE IF EXISTS #RiskScore_tmp_ANYEVENT_RANDOM_EXTRACT
	SELECT CASE WHEN Effect like 'Visn%' THEN 'VISN' + SUBSTRING(Effect,6,2) 
				WHEN Effect like 'Sta3n%' THEN 'Station' + SUBSTRING(Effect,15,3)
		   ELSE EFFECT
		   END AS "EFFECT", 
		   Estimate
	INTO #RiskScore_tmp_ANYEVENT_RANDOM_EXTRACT
	FROM [ORM].[Model_AnyEvent_Random_SAS]; 

	----------------------------------------- PRT 07/15/2017
	--Get DISTINCT values of the PIVOT Column 
	-----------------------------------------
	SELECT @ColumnName4= ISNULL(@ColumnName4 + ',','') 
		   + QUOTENAME(EFFECT)
	FROM (SELECT DISTINCT Effect FROM #RiskScore_tmp_ANYEVENT_RANDOM_EXTRACT) AS COL4;

	------------------------------------------- PRT 07/15/2017
	--Prepare the PIVOT query using the dynamic 
	-------------------------------------------
	DROP TABLE IF EXISTS ##RiskScore_tmp_ANYEVENT_RANDOM_PIVOT
	SET @DynamicPivotQuery = 
	  N'SELECT  ' + @ColumnName4 + '
		INTO ##RiskScore_tmp_ANYEVENT_RANDOM_PIVOT
		FROM #RiskScore_tmp_ANYEVENT_RANDOM_EXTRACT
		PIVOT(MIN(Estimate) 
			  FOR EFFECT IN (' + @ColumnName4 + ')) AS PVT4'
	EXEC sp_executesql @DynamicPivotQuery;


	---------------------------------------------------------------- PRT 07/15/2017
	--- Read AnyEvent Random (Station AND VISN) Table INTO Variables
	----------------------------------------------------------------
	SELECT
		@Station358 = Station358,
		@Station402 = Station402,
		@Station405 = Station405,
		@Station436 = Station436,
		@Station437 = Station437,
		@Station438 = Station438,
		@Station442 = Station442,
		@Station459 = Station459,
		@Station460 = Station460,
		@Station463 = Station463,
		@Station501 = Station501,
		@Station502 = Station502,
		@Station503 = Station503,
		@Station504 = Station504,
		@Station506 = Station506,
		@Station508 = Station508,
		@Station509 = Station509,
		@Station512 = Station512,
		@Station515 = Station515,
		@Station516 = Station516,
		@Station517 = Station517,
		@Station518 = Station518,
		@Station519 = Station519,
		@Station520 = Station520,
		@Station521 = Station521,
		@Station523 = Station523,
		@Station526 = Station526,
		@Station528 = Station528,
		@Station529 = Station529,
		@Station531 = Station531,
		@Station534 = Station534,
		@Station537 = Station537,
		@Station538 = Station538,
		@Station539 = Station539,
		@Station540 = Station540,
		@Station541 = Station541,
		@Station542 = Station542,
		@Station544 = Station544,
		@Station546 = Station546,
		@Station548 = Station548,
		@Station549 = Station549,
		@Station550 = Station550,
		@Station552 = Station552,
		@Station553 = Station553,
		@Station554 = Station554,
		@Station556 = Station556,
		@Station557 = Station557,
		@Station558 = Station558,
		@Station561 = Station561,
		@Station562 = Station562,
		@Station564 = Station564,
		@Station565 = Station565,
		@Station568 = Station568,
		@Station570 = Station570,
		@Station573 = Station573,
		@Station575 = Station575,
		@Station578 = Station578,
		@Station580 = Station580,
		@Station581 = Station581,
		@Station583 = Station583,
		@Station585 = Station585,
		@Station586 = Station586,
		@Station589 = Station589,
		@Station590 = Station590,
		@Station593 = Station593,
		@Station595 = Station595,
		@Station596 = Station596,
		@Station598 = Station598,
		@Station600 = Station600,
		@Station603 = Station603,
		@Station605 = Station605,
		@Station607 = Station607,
		@Station608 = Station608,
		@Station610 = Station610,
		@Station612 = Station612,
		@Station613 = Station613,
		@Station614 = Station614,
		@Station618 = Station618,
		@Station619 = Station619,
		@Station620 = Station620,
		@Station621 = Station621,
		@Station623 = Station623,
		@Station626 = Station626,
		@Station629 = Station629,
		@Station630 = Station630,
		@Station631 = Station631,
		@Station632 = Station632,
		@Station635 = Station635,
		@Station636 = Station636,
		@Station637 = Station637,
		@Station640 = Station640,
		@Station642 = Station642,
		@Station644 = Station644,
		@Station646 = Station646,
		@Station648 = Station648,
		@Station649 = Station649,
		@Station650 = Station650,
		@Station652 = Station652,
		@Station653 = Station653,
		@Station654 = Station654,
		@Station655 = Station655,
		@Station656 = Station656,
		@Station657 = Station657,
		@Station658 = Station658,
		@Station659 = Station659,
		@Station660 = Station660,
		@Station662 = Station662,
		@Station663 = Station663,
		@Station664 = Station664,
		@Station666 = Station666,
		@Station667 = Station667,
		@Station668 = Station668,
		@Station671 = Station671,
		@Station672 = Station672,
		@Station673 = Station673,
		@Station674 = Station674,
		@Station675 = Station675,
		@Station676 = Station676,
		@Station678 = Station678,
		@Station679 = Station679,
		@Station687 = Station687,
		@Station688 = Station688,
		@Station689 = Station689,
		@Station691 = Station691,
		@Station692 = Station692,
		@Station693 = Station693,
		@Station695 = Station695,
		@Station740 = 0,								--06/12/2018 remove comment "--" to activate line of code  (change station740 to 0)
		@Station756 = Station756,
		@Station757 = Station757,
		@VISN1 = VISN1,
		@VISN10 = VISN10,
		@VISN11 = VISN11,
		@VISN12 = VISN12,
		@VISN15 = VISN15,
		@VISN16 = VISN16,
		@VISN17 = VISN17,
		@VISN18 = VISN18,
		@VISN19 = VISN19,
		@VISN2 =  VISN2,
		@VISN20 = VISN20,
		@VISN21 = VISN21,
		@VISN22 = VISN22,
		@VISN23 = VISN23,
		@VISN3 =  VISN3,
		@VISN4 =  VISN4,
		@VISN5 =  VISN5,
		@VISN6 =  VISN6,
		@VISN7 =  VISN7,
		@VISN8 =  VISN8,
		@VISN9 =  VISN9
	FROM
		##RiskScore_tmp_ANYEVENT_RANDOM_PIVOT;	

	DROP TABLE IF EXISTS ##RiskScore_tmp_ANYEVENT_RANDOM_PIVOT

	----------------------------------------------------------------------
	----------------------------------------------------------------------
	--  BUILD TEMP TABLE OF ANY EVENT MODEL CALCULATIONS IN 3 PARTS
	--		1. ALL THE VARIABLES EXCEPT "TOTAL MEDS" AND "SEDATIVES"
	--		2. TOTAL MEDICATIONS
	--		3. SEDATIVES (RX OPIOIDS)
	--  THESE 3 TOTALS WILL BE USING IN CALUCATING THE VARIOUS RISK SCORES 
	----------------------------------------------------------------------
	----------------------------------------------------------------------

	DROP TABLE IF EXISTS #TEMP_ANY
	SELECT a.MVIPersonSID,
     		( 
				@Intercept + --((TotalMEDD) * @TotalMEDD) + 					
				([LongActing] * @LongActing) + 			
				([ChronicShortActing] * @ChronicShortActing) + 	
				([NonChronicShortActing] * @NonChronicShortActing) + 	
				([TramadolOnly] * @TramadolOnly) + 				
				(Age30 * @Age30) + 										
				(Age3150 * @Age3150) + 										
				(Age5165 * @Age5165) + 										
				(Age66 * @Age66) + 												
				[EH_HEART] * @EH_HEART + 										
				[EH_ARRHYTH] * @EH_ARRHYTH + 									
				[EH_VALVDIS] * @EH_VALVDIS + 									
				[EH_PULMCIRC] * @EH_PULMCIRC + 									
				[EH_HYPOTHY] * @EH_HYPOTHY + 									
				[EH_RHEUMART] * @EH_RHEUMART + 									
				[EH_COAG] * @EH_COAG + 				
			--	[EH_COAG] * 0.2533 + 											
				[EH_WEIGHTLS] * @EH_WEIGHTLS + 									
				[EH_ELECTRLYTE] * @EH_ELECTRLYTE + 									
				[EH_DefANEMIA] * @EH_DefANEMIA + 									
				[EH_AIDS] * @EH_AIDS + 
				[EH_CHRNPULM] * @EH_CHRNPULM + 
				[EH_COMDIAB] * @EH_COMDIAB + 
				[EH_LIVER] * @EH_LIVER + 
				[EH_OTHNEURO] * @EH_OTHNEURO + 
				[EH_PARALYSIS] * @EH_PARALYSIS + 
				[EH_PEPTICULC] * @EH_PEPTICULC + 
				[EH_PERIVALV] * @EH_PERIVALV + 
				(GenderMale * @GenderMale) + 									
				(SumOverdose_Suicide * @SumOverdose_Suicide) + 							
				(AnySAE * @AnySAE) + 										
				(CASE -- HES
						WHEN [Sum_Painadj] = 0
							THEN @Sum_Painadj0
						WHEN [Sum_Painadj] = 1
							THEN @Sum_Painadj1
						WHEN [Sum_Painadj] = 2
							THEN @Sum_Painadj2
						WHEN [Sum_Painadj] = 3
							THEN @Sum_Painadj3
						END	) + 
					(CASE -- VISN			
						WHEN [VISN] =  1  THEN @VISN1
						WHEN [VISN] =  2  THEN @VISN2
						WHEN [VISN] =  3  THEN @VISN3
						WHEN [VISN] =  4  THEN @VISN4
						WHEN [VISN] =  5  THEN @VISN5
						WHEN [VISN] =  6  THEN @VISN6
						WHEN [VISN] =  7  THEN @VISN7
						WHEN [VISN] =  8  THEN @VISN8
						WHEN [VISN] =  9  THEN @VISN9
						WHEN [VISN] =  10  THEN @VISN10
						WHEN [VISN] =  11  THEN @VISN11
						WHEN [VISN] =  12  THEN @VISN12
						WHEN [VISN] =  15  THEN @VISN15
						WHEN [VISN] =  16  THEN @VISN16
					--	WHEN [VISN] =  17  THEN @VISN17							--06/12/2018 add comment "--" to deactivate line of code
						WHEN [VISN] =  17 AND [STA3N] = 740 THEN 0				--06/12/2018 add line of code
						WHEN [VISN] =  17 AND [STA3N] <> 740 THEN @VISN17		--06/12/2018 add line of code	
						WHEN [VISN] =  18  THEN @VISN18
						WHEN [VISN] =  19  THEN @VISN19
						WHEN [VISN] =  20  THEN @VISN20
						WHEN [VISN] =  21  THEN @VISN21
						WHEN [VISN] =  22  THEN @VISN22
						WHEN [VISN] =  23  THEN @VISN23
						WHEN [VISN] =  0  THEN  0		
						END	) + 
					(CASE -- STA3N
						WHEN [STA3N]  = 358  THEN  @Station358
						WHEN [STA3N]  = 402  THEN  @Station402
						WHEN [STA3N]  = 405  THEN  @Station405
						WHEN [STA3N]  = 436  THEN  @Station436
						WHEN [STA3N]  = 437  THEN  @Station437
						WHEN [STA3N]  = 438  THEN  @Station438
						WHEN [STA3N]  = 442  THEN  @Station442
						WHEN [STA3N]  = 459  THEN  @Station459
						WHEN [STA3N]  = 460  THEN  @Station460
						WHEN [STA3N]  = 463  THEN  @Station463
						WHEN [STA3N]  = 501  THEN  @Station501
						WHEN [STA3N]  = 502  THEN  @Station502
						WHEN [STA3N]  = 503  THEN  @Station503
						WHEN [STA3N]  = 504  THEN  @Station504
						WHEN [STA3N]  = 506  THEN  @Station506
						WHEN [STA3N]  = 508  THEN  @Station508
						WHEN [STA3N]  = 509  THEN  @Station509
						WHEN [STA3N]  = 512  THEN  @Station512
						WHEN [STA3N]  = 515  THEN  @Station515
						WHEN [STA3N]  = 516  THEN  @Station516
						WHEN [STA3N]  = 517  THEN  @Station517
						WHEN [STA3N]  = 518  THEN  @Station518
						WHEN [STA3N]  = 519  THEN  @Station519
						WHEN [STA3N]  = 520  THEN  @Station520
						WHEN [STA3N]  = 521  THEN  @Station521
						WHEN [STA3N]  = 523  THEN  @Station523
						WHEN [STA3N]  = 526  THEN  @Station526
						WHEN [STA3N]  = 528  THEN  @Station528
						WHEN [STA3N]  = 529  THEN  @Station529
						WHEN [STA3N]  = 531  THEN  @Station531
						WHEN [STA3N]  = 534  THEN  @Station534
						WHEN [STA3N]  = 537  THEN  @Station537
						WHEN [STA3N]  = 538  THEN  @Station538
						WHEN [STA3N]  = 539  THEN  @Station539
						WHEN [STA3N]  = 540  THEN  @Station540
						WHEN [STA3N]  = 541  THEN  @Station541
						WHEN [STA3N]  = 542  THEN  @Station542
						WHEN [STA3N]  = 544  THEN  @Station544
						WHEN [STA3N]  = 546  THEN  @Station546
						WHEN [STA3N]  = 548  THEN  @Station548
						WHEN [STA3N]  = 549  THEN  @Station549
						WHEN [STA3N]  = 550  THEN  @Station550
						WHEN [STA3N]  = 552  THEN  @Station552
						WHEN [STA3N]  = 553  THEN  @Station553
						WHEN [STA3N]  = 554  THEN  @Station554
						WHEN [STA3N]  = 556  THEN  @Station556
						WHEN [STA3N]  = 557  THEN  @Station557
						WHEN [STA3N]  = 558  THEN  @Station558
						WHEN [STA3N]  = 561  THEN  @Station561
						WHEN [STA3N]  = 562  THEN  @Station562
						WHEN [STA3N]  = 564  THEN  @Station564
						WHEN [STA3N]  = 565  THEN  @Station565
						WHEN [STA3N]  = 568  THEN  @Station568
						WHEN [STA3N]  = 570  THEN  @Station570
						WHEN [STA3N]  = 573  THEN  @Station573
						WHEN [STA3N]  = 575  THEN  @Station575
						WHEN [STA3N]  = 578  THEN  @Station578
						WHEN [STA3N]  = 580  THEN  @Station580
						WHEN [STA3N]  = 581  THEN  @Station581
						WHEN [STA3N]  = 583  THEN  @Station583
						WHEN [STA3N]  = 585  THEN  @Station585
						WHEN [STA3N]  = 586  THEN  @Station586
						WHEN [STA3N]  = 589  THEN  @Station589
						WHEN [STA3N]  = 590  THEN  @Station590
						WHEN [STA3N]  = 593  THEN  @Station593
						WHEN [STA3N]  = 595  THEN  @Station595
						WHEN [STA3N]  = 596  THEN  @Station596
						WHEN [STA3N]  = 598  THEN  @Station598
						WHEN [STA3N]  = 600  THEN  @Station600
						WHEN [STA3N]  = 603  THEN  @Station603
						WHEN [STA3N]  = 605  THEN  @Station605
						WHEN [STA3N]  = 607  THEN  @Station607
						WHEN [STA3N]  = 608  THEN  @Station608
						WHEN [STA3N]  = 610  THEN  @Station610
						WHEN [STA3N]  = 612  THEN  @Station612
						WHEN [STA3N]  = 613  THEN  @Station613
						WHEN [STA3N]  = 614  THEN  @Station614
						WHEN [STA3N]  = 618  THEN  @Station618
						WHEN [STA3N]  = 619  THEN  @Station619
						WHEN [STA3N]  = 620  THEN  @Station620
						WHEN [STA3N]  = 621  THEN  @Station621
						WHEN [STA3N]  = 623  THEN  @Station623
						WHEN [STA3N]  = 626  THEN  @Station626
						WHEN [STA3N]  = 629  THEN  @Station629
						WHEN [STA3N]  = 630  THEN  @Station630
						WHEN [STA3N]  = 631  THEN  @Station631
						WHEN [STA3N]  = 632  THEN  @Station632
						WHEN [STA3N]  = 635  THEN  @Station635
						WHEN [STA3N]  = 636  THEN  @Station636
						WHEN [STA3N]  = 637  THEN  @Station637
						WHEN [STA3N]  = 640  THEN  @Station640
						WHEN [STA3N]  = 642  THEN  @Station642
						WHEN [STA3N]  = 644  THEN  @Station644
						WHEN [STA3N]  = 646  THEN  @Station646
						WHEN [STA3N]  = 648  THEN  @Station648
						WHEN [STA3N]  = 649  THEN  @Station649
						WHEN [STA3N]  = 650  THEN  @Station650
						WHEN [STA3N]  = 652  THEN  @Station652
						WHEN [STA3N]  = 653  THEN  @Station653
						WHEN [STA3N]  = 654  THEN  @Station654
						WHEN [STA3N]  = 655  THEN  @Station655
						WHEN [STA3N]  = 656  THEN  @Station656
						WHEN [STA3N]  = 657  THEN  @Station657
						WHEN [STA3N]  = 658  THEN  @Station658
						WHEN [STA3N]  = 659  THEN  @Station659
						WHEN [STA3N]  = 660  THEN  @Station660
						WHEN [STA3N]  = 662  THEN  @Station662
						WHEN [STA3N]  = 663  THEN  @Station663
						WHEN [STA3N]  = 664  THEN  @Station664
						WHEN [STA3N]  = 666  THEN  @Station666
						WHEN [STA3N]  = 667  THEN  @Station667
						WHEN [STA3N]  = 668  THEN  @Station668
						WHEN [STA3N]  = 671  THEN  @Station671
						WHEN [STA3N]  = 672  THEN  @Station672
						WHEN [STA3N]  = 673  THEN  @Station673
						WHEN [STA3N]  = 674  THEN  @Station674
						WHEN [STA3N]  = 675  THEN  @Station675
						WHEN [STA3N]  = 676  THEN  @Station676
						WHEN [STA3N]  = 678  THEN  @Station678
						WHEN [STA3N]  = 679  THEN  @Station679
						WHEN [STA3N]  = 687  THEN  @Station687
						WHEN [STA3N]  = 688  THEN  @Station688
						WHEN [STA3N]  = 689  THEN  @Station689
						WHEN [STA3N]  = 691  THEN  @Station691
						WHEN [STA3N]  = 692  THEN  @Station692
						WHEN [STA3N]  = 693  THEN  @Station693
						WHEN [STA3N]  = 695  THEN  @Station695
						WHEN [STA3N]  = 740  THEN  @Station740				--06/12/2018 add this line of code
						WHEN [STA3N]  = 756  THEN  @Station756
						WHEN [STA3N]  = 757  THEN  @Station757
						WHEN [STA3N]  = 0  THEN  0
						END	) + 
				([AUD_ORM] * @AUD_ORM) + 			
				(a.OUD * @OUD) + 						
				([Other_MH_STORM] * @Psych_poss) + 					
				([SUD_NoOUD_NoAUD] * @SUD_NoOUD_NoAUD) + 				
				(MHOutpat * @MHOutPatient) + 				
				(MHInpat * @MHInpat) + 					
				[Osteoporosis] * @Osteoporosis + 
				[SleepApnea] * @SleepApnea  + 
				[NicDx_Poss] * @NicDx_Poss + 
	---			([SedativeRx_Opioid]) * @SedativeRx_Opioid + 
				(Detox_CPT * @Detox_CPT)  +
				([BIPOLAR] * @BIPOLAR) + 
				(PTSD * @PTSD)  +
				([MDD] * @MDD) + 
				(COCNdx * @COCNdx)  +
				(InteractionOverdoseOtherAE * @InteractionOverdoseOtherAE) + 	
				(InteractionOverdoseMHInpat * @InteractionOverdoseInpatMHTx) + 	
				(InteractionOverdoseOUD * 0) + 		
				(InteractionOUDAnySAE * @InteractionOUDAnySAE) + 			
				(InteractionOUDMHInpat * @InteractionOUDInpatMHTx) + 		
				(InteractionAnySAEMHInpat * @InteractionAnySAEMHInpat)	
				) AS "ANY_ALMOST_ALL"
			,CASE 
				WHEN ISNULL(OpioidForPain_Rx,0)=1 THEN (TotalMEDD * @TotalMEDD) 
				WHEN ISNULL(a.OUD,0)=1 THEN (90 * @TotalMEDD) 
				ELSE NULL 
				END  "ANY_TOTMEDD"
			,(SedativeOpioid_Rx * @SedativeOpioid_Rx) AS "ANY_SED_RX"     
	INTO #TEMP_ANY
	FROM [ORM].[RiskScore] AS a										
	LEFT OUTER JOIN (
		SELECT MVIPersonSID
			  ,OpioidForPain_Rx 
		FROM [SUD].[Cohort]
		WHERE OUD = 1
			OR OpioidForPain_Rx = 1
		) AS p ON a.MVIPersonSID = p.MVIPersonSID
	;

	-- Real time RiskScoreAny (Any adverse event- accidents, falls, suicide, overdose...) [RiskScoreAny]
	-- 10% opioid dose [RiskScoreAny10]
	-- 50% opioid dose [RiskScoreAny50]
	-- No sedatives AND with 10% opioid dose [RiskScoreAnyNoSed]

	UPDATE [ORM].[RiskScore]
	SET [RiskScoreAny] = ISNULL(ANY_ALMOST_ALL,0) + ANY_TOTMEDD + ANY_SED_RX,
		[RiskScoreAny10] = ISNULL(ANY_ALMOST_ALL,0) + (0.100000000000000 * ANY_TOTMEDD) + ANY_SED_RX,
		[RiskScoreAny50] = ISNULL(ANY_ALMOST_ALL,0) + (0.500000000000000 * ANY_TOTMEDD) + ANY_SED_RX,
		[RiskScoreAnyNoSed] = ISNULL(ANY_ALMOST_ALL,0) + (0.100000000000000 * ANY_TOTMEDD) + (0 * ANY_SED_RX)
	FROM [ORM].[RiskScore] a
	INNER JOIN #TEMP_ANY b ON a.MVIPersonSID = b.MVIPersonSID
	WHERE b.ANY_TOTMEDD IS NOT NULL
	;

	UPDATE [ORM].[RiskScore]
	SET [RiskScoreAnyHypothetical10] = ISNULL(ANY_ALMOST_ALL,0) + (10 * @TotalMEDD) + ANY_SED_RX,
		[RiskScoreAnyHypothetical50] = ISNULL(ANY_ALMOST_ALL,0) + (50 * @TotalMEDD) + ANY_SED_RX,
		[RiskScoreAnyHypothetical90] = ISNULL(ANY_ALMOST_ALL,0) + (90 * @TotalMEDD) + ANY_SED_RX
	FROM [ORM].[RiskScore] a
	INNER JOIN #TEMP_ANY b ON a.MVIPersonSID = b.MVIPersonSID
	WHERE b.ANY_TOTMEDD IS NULL
	;
	
	UPDATE [ORM].[RiskScore]
	SET RiskScoreAny  = EXP (RiskScoreAny)/(1+ EXP (RiskScoreAny)),
		RiskScoreAny10  = EXP (RiskScoreAny10)/(1+ EXP (RiskScoreAny10)),
		RiskScoreAny50  = EXP (RiskScoreAny50)/(1+ EXP (RiskScoreAny50)),
		RiskScoreAnyNoSed  = EXP (RiskScoreAnyNoSed)/(1+ EXP (RiskScoreAnyNoSed));
	;

	UPDATE [ORM].[RiskScore]
	SET RiskScoreAnyHypothetical10  = EXP (RiskScoreAnyHypothetical10)/(1+ EXP (RiskScoreAnyHypothetical10)),
		RiskScoreAnyHypothetical50  = EXP (RiskScoreAnyHypothetical50)/(1+ EXP (RiskScoreAnyHypothetical50)),
		RiskScoreAnyHypothetical90  = EXP (RiskScoreAnyHypothetical90)/(1+ EXP (RiskScoreAnyHypothetical90))
	;
    
	UPDATE [ORM].[RiskScore]
	SET [RiskScoreHypothetical10] = ISNULL(OVR_ALMOST_ALL,0) + (10 * @TotalMEDD) + OVR_SED_RX,
		[RiskScoreHypothetical50] = ISNULL(OVR_ALMOST_ALL,0) + (50 * @TotalMEDD) + OVR_SED_RX,
		[RiskScoreHypothetical90] = ISNULL(OVR_ALMOST_ALL,0) + (90 * @TotalMEDD) + OVR_SED_RX
	FROM [ORM].[RiskScore] a
	INNER JOIN  #TEMP_OVR b ON a.MVIPersonSID = b.MVIPersonSID
	WHERE b.OVR_TOTMEDD IS  NULL
	;

	UPDATE [ORM].[RiskScore]
	SET RiskScore  = EXP (RiskScore)/(1+ EXP (RiskScore)),
		RiskScore10  = EXP (RiskScore10)/(1+ EXP (RiskScore10)),
		RiskScore50  = EXP (RiskScore50)/(1+ EXP (RiskScore50)),
		RiskScoreNoSed  = EXP (RiskScoreNoSed)/(1+ EXP (RiskScoreNoSed));
		--updating ORM.Cohort riskcategory
	; 

	DROP TABLE IF EXISTS #riskcategory;
	SELECT MVIPersonSID
		  ,RiskCategory
		  ,RiskAnyCategory
		  ,CASE
			WHEN RiskCategory = 5  THEN 'Elevated Risk Due To OUD Dx, No Opioid Rx'
			WHEN RiskCategory = 4 THEN   'Very High - Active Opioid Rx' 
			WHEN RiskCategory = 3 THEN 'High - Active Opioid Rx'
			WHEN RiskCategory = 2 THEN 'Medium - Active Opioid Rx'
			ELSE 'Low - Active Opioid Rx' 
			END AS RiskCategoryLabel
		  ,CASE 
			WHEN RiskAnyCategory = 5  THEN 'Elevated Risk Due To OUD Dx, No Opioid Rx'
			WHEN RiskAnyCategory = 4 THEN   'Very High - Active Opioid Rx' 
			WHEN RiskAnyCategory = 3 THEN 'High - Active Opioid Rx'
			WHEN RiskAnyCategory = 2 THEN 'Medium - Active Opioid Rx'
			ELSE 'Low - Active Opioid Rx' 
			END AS RiskAnyCategoryLabel
	INTO #riskcategory
	FROM (
		SELECT DISTINCT 
			a.MVIPersonSID 
			,CASE 
				WHEN a.OUD = 1 AND ISNULL(b.OpioidForPain_Rx,0) = 0 THEN 5
				WHEN (a.RiskScore >=.0609) THEN 4   --VERY HIGH for OpioidOverdose and suicide
				WHEN (a.RiskScore >=.0420 AND a.RiskScore < .0609) THEN 3  -- HIGH
				WHEN (a.RiskScore >=.01615 AND a.RiskScore <.0420) THEN 2 --MEDIUM
				ELSE 1 END as RiskCategory --LOW --  
			,CASE
				WHEN  a.OUD = 1 AND ISNULL(b.OpioidForPain_Rx,0) = 0 THEN 5
				WHEN (a.RiskScoreAny >=.60 ) THEN 4  
				WHEN (a.RiskScoreAny >=.40 AND a.RiskScoreAny <.60) THEN 3
				WHEN (a.RiskScoreAny >=.16 AND a.RiskScoreAny <.40) THEN 2
				ELSE 1 END AS RiskAnyCategory
		FROM [ORM].[RiskScore] AS a 
		LEFT JOIN (
			SELECT MVIPersonSID
				,OpioidForPain_Rx
				,ODPastYear
			FROM [SUD].[Cohort] 
			) b ON a.MVIPersonSID=b.MVIPersonSID
		) AS a 
	 ;

	UPDATE [ORM].[RiskScore]
	SET Riskcategory= a.riskcategory,
		RiskCategoryLabel= a.RiskCategoryLabel,
		RiskAnyCategory= a.RiskAnyCategory,
		RiskAnyCategoryLabel= a.RiskAnyCategoryLabel
	FROM #riskcategory a 
	INNER JOIN [ORM].[RiskScore] AS b ON a.MVIPersonSID=b.MVIPersonSID
	;
	
	UPDATE [ORM].[RiskScore]
	SET RiskScoreHypothetical10  = EXP (RiskScoreHypothetical10)/(1+ EXP (RiskScoreHypothetical10)),
		RiskScoreHypothetical50  = EXP (RiskScoreHypothetical50)/(1+ EXP (RiskScoreHypothetical50)),
		RiskScoreHypothetical90  = EXP (RiskScoreHypothetical90)/(1+ EXP (RiskScoreHypothetical90));
	;

    DROP TABLE IF EXISTS #Hypotheticalriskcategory;
	SELECT MVIPersonSID
		  ,RiskCategory_Hypothetical10 
		  ,RiskAnyCategory_Hypothetical10
		  ,RiskCategory_Hypothetical50
		  ,RiskAnyCategory_Hypothetical50
		  ,RiskCategory_Hypothetical90
		  ,RiskAnyCategory_Hypothetical90
    	  ,CASE                             
    		WHEN RiskCategory_Hypothetical10 = 4 THEN 'Very High' 
    		WHEN RiskCategory_Hypothetical10 = 3 THEN 'High'
    		WHEN RiskCategory_Hypothetical10 = 2 THEN 'Medium'
    		ELSE 'Low' 
			END AS RiskCategoryLabel_Hypothetical10
		  ,CASE 
    		WHEN RiskAnyCategory_Hypothetical10 = 4 THEN 'Very High' 
    		WHEN RiskAnyCategory_Hypothetical10 = 3 THEN 'High'
    		WHEN RiskAnyCategory_Hypothetical10 = 2 THEN 'Medium'
    		ELSE 'Low' 
			END AS RiskAnyCategoryLabel_Hypothetical10
		  ,CASE                             
    		WHEN RiskCategory_Hypothetical50 = 4 THEN 'Very High' 
    		WHEN RiskCategory_Hypothetical50 = 3 THEN 'High'
    		WHEN RiskCategory_Hypothetical50 = 2 THEN 'Medium'
    		ELSE 'Low' 
			END AS RiskCategoryLabel_Hypothetical50
		  ,CASE 
    		WHEN RiskAnyCategory_Hypothetical50 = 4 THEN 'Very High' 
    		WHEN RiskAnyCategory_Hypothetical50 = 3 THEN 'High'
    		WHEN RiskAnyCategory_Hypothetical50 = 2 THEN 'Medium'
    		ELSE 'Low' 
			END AS RiskAnyCategoryLabel_Hypothetical50
		  ,CASE                             
    		WHEN RiskCategory_Hypothetical90 = 4 THEN 'Very High' 
    		WHEN RiskCategory_Hypothetical90 = 3 THEN 'High'
    		WHEN RiskCategory_Hypothetical90 = 2 THEN 'Medium'
    		ELSE 'Low' 
			END AS RiskCategoryLabel_Hypothetical90
		  ,CASE 
    		WHEN RiskAnyCategory_Hypothetical90 = 4 THEN 'Very High' 
    		WHEN RiskAnyCategory_Hypothetical90 = 3 THEN 'High'
    		WHEN RiskAnyCategory_Hypothetical90 = 2 THEN 'Medium'
    		ELSE 'Low' 
			END AS RiskAnyCategoryLabel_Hypothetical90
	INTO #Hypotheticalriskcategory
	FROM (
		SELECT DISTINCT a.MVIPersonSID
			,CASE 
				WHEN (a.RiskScoreHypothetical10 >=.1656) THEN 4  
				WHEN (a.RiskScoreHypothetical10 >=.0420 AND a.RiskScoreHypothetical10 < .1656) THEN 3
				WHEN (a.RiskScoreHypothetical10 >=.01615 AND a.RiskScoreHypothetical10 <.0420) THEN 2
    			ELSE 1 
				END AS RiskCategory_Hypothetical10 
			,CASE
    			WHEN (a.RiskScoreAnyHypothetical10 >=.60 ) THEN 4  
    			WHEN (a.RiskScoreAnyHypothetical10 >=.40 AND a.RiskScoreAnyHypothetical10 <.60) THEN 3
    			WHEN (a.RiskScoreAnyHypothetical10 >=.16 AND a.RiskScoreAnyHypothetical10 <.40) THEN 2
    			ELSE 1 
				END AS RiskAnyCategory_Hypothetical10
			,CASE 
    			WHEN (a.RiskScoreHypothetical50 >=.1656) THEN 4  
				WHEN (a.RiskScoreHypothetical50 >=.0420 AND a.RiskScoreHypothetical50 < .1656) THEN 3
				WHEN (a.RiskScoreHypothetical50 >=.01615 AND a.RiskScoreHypothetical50 <.0420) THEN 2
    			ELSE 1 
				END AS RiskCategory_Hypothetical50 
			,CASE
    			WHEN (a.RiskScoreAnyHypothetical50 >=.60 ) THEN 4  
    			WHEN (a.RiskScoreAnyHypothetical50 >=.40 AND a.RiskScoreAnyHypothetical50 <.60) THEN 3
    			WHEN (a.RiskScoreAnyHypothetical50 >=.16 AND a.RiskScoreAnyHypothetical50 <.40) THEN 2
    			ELSE 1 
				END AS RiskAnyCategory_Hypothetical50
			,CASE 
				WHEN (a.RiskScoreHypothetical90 >=.1656) THEN 4  
				WHEN (a.RiskScoreHypothetical90 >=.0420 AND a.RiskScoreHypothetical90 < .1656) THEN 3
				WHEN (a.RiskScoreHypothetical90 >=.01615 AND a.RiskScoreHypothetical90 <.0420) THEN 2
    			ELSE 1 
				END AS RiskCategory_Hypothetical90
			,CASE
    			WHEN (a.RiskScoreAnyHypothetical90 >=.60 ) THEN 4  
    			WHEN (a.RiskScoreAnyHypothetical90 >=.40 AND a.RiskScoreAnyHypothetical90 <.60) THEN 3
    			WHEN (a.RiskScoreAnyHypothetical90 >=.16 AND a.RiskScoreAnyHypothetical90 <.40) THEN 2
    			ELSE 1 
				END AS RiskAnyCategory_Hypothetical90
		FROM [ORM].[RiskScore] AS a
   		) AS a 
	;
  
	UPDATE [ORM].[RiskScore]
	SET RiskCategory_Hypothetical10 = a.RiskCategory_Hypothetical10
	  , RiskAnyCategory_Hypothetical10 = a.RiskAnyCategory_Hypothetical10
	  , RiskCategory_Hypothetical50 = a.RiskCategory_Hypothetical50
	  , RiskAnyCategory_Hypothetical50 = a.RiskAnyCategory_Hypothetical50
	  , RiskCategory_Hypothetical90 = a.RiskCategory_Hypothetical90
	  , RiskAnyCategory_Hypothetical90 = a.RiskAnyCategory_Hypothetical90
	  , RiskCategoryLabel_Hypothetical10 = a.RiskCategoryLabel_Hypothetical10
	  , RiskAnyCategoryLabel_Hypothetical10 = a.RiskAnyCategoryLabel_Hypothetical10
	  , RiskCategoryLabel_Hypothetical50 = a.RiskCategoryLabel_Hypothetical50
	  , RiskAnyCategoryLabel_Hypothetical50 = a.RiskAnyCategoryLabel_Hypothetical50
	  , RiskCategoryLabel_Hypothetical90 = a.RiskCategoryLabel_Hypothetical90
	  , RiskAnyCategoryLabel_Hypothetical90 = a.RiskAnyCategoryLabel_Hypothetical90
	FROM #Hypotheticalriskcategory a 
	INNER JOIN [ORM].[RiskScore] AS b ON a.MVIPersonSID=b.MVIPersonSID
	
	DROP TABLE IF EXISTS #RiskScore_tmp_OVERDOSE_EXTRACT 
	DROP TABLE IF EXISTS #RiskScore_tmp_OVERDOSE_RANDOM_EXTRACT
	DROP TABLE IF EXISTS #Temp_Ovr
	DROP TABLE IF EXISTS #RiskScore_tmp_ANYEVENT_EXTRACT
	DROP TABLE IF EXISTS #RiskScore_tmp_ANYEVENT_RANDOM_EXTRACT
	DROP TABLE IF EXISTS #TEMP_ANY
	DROP TABLE IF EXISTS #riskcategory
	DROP TABLE IF EXISTS #Hypotheticalriskcategory 

END