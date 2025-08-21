


/***********************************************************
MODIFICATIONS:
	2022-02-04	RAS Created initial view for DOD STORM data coming from JVPN transfer
	2022-02-23  CLB Added restriction based on ExtractionLoadDate to only include most recent data transfer; renamed
					fields that have been transformed to CamelCase in DBS101 but conflict with Present.Dx column names
	2022-06-16	JEB Updated to point to Core instead of directly to PDW. Added WITH (NOLOCK)
					Note, explicit view definition required
	2022-07-27  CLB Updated synonym following change to JVPN data flow
***********************************************************/
CREATE VIEW [ORM].[vwDOD_TriSTORM]
AS
SELECT DISTINCT
	COALESCE(mp.MVIPersonSID,sv.MVIPersonSID,0) as MVIPersonSID
	,RIGHT('000' + dod.SSN,9) as PatientSSN
	--,dod.PainAdjustment				-- formerly Sum_PainAdj
	--,dod.RiskScoreHypMedVA			-- formerly RiskScore_hyp_med_VA
	--,dod.RiskScoreHypMedTRI			-- formerly RiskScore_hyp_med_Tri
	--,dod.RiskScoreHypLowVA			-- formerly RiskScore_hyp_low_VA
	--,dod.RiskScoreHypLowTRI			-- formerly RiskScore_hyp_low_Tri
	--,dod.RiskScoreHypHighVA			-- formerly RiskScore_hyp_high_VA
	--,dod.RiskScoreHypHighTRI			-- formerly RiskScore_hyp_high_Tri
	--,dod.RiskScoreVA					-- formerly RiskScore_VA
	--,dod.RiskScoreTRI					-- formerly RiskScore_Tri
	--,dod.ExpRiskScoreAnyMedVA			-- formerly expRiskScoreAnymed_va
	--,dod.ExpRiskScoreAnyMedTRI		-- formerly expRiskScoreAnymed_TRI
	--,dod.ExpRiskScoreAnyLowVA			-- formerly expRiskScoreAnylow_va
	--,dod.ExpRiskScoreAnyLowTRI		-- formerly expRiskScoreAnylow_TRI
	--,dod.ExpRiskScoreAnyHighVA		-- formerly expRiskScoreAnyhigh_va
	--,dod.ExpRiskScoreAnyHighTRI		-- formerly expRiskScoreAnyhigh_TRI
	--,dod.ExpRiskScoreAnyVA			-- formerly expRiskScoreAny_VA
	--,dod.ExpRiskScoreAnyTRI			-- formerly expRiskScoreAny_TRI
	--,dod.StateCountry
	--,dod.ServiceBranch
	--,dod.ScoreDate					-- formerly Score_Date
	--,dod.PsychDxPoss					-- formerly psychdx_poss
	--,dod.PatID
	,dod.EDIPN
	,dod.detox AS DETOX_CPT  
	--,dod.BenCatCom					-- formerly ben_cat_com
	--,dod.A1biiDetox					-- formerly A1bii_detox
	,dod.SleepApnea
	,dod.SedativeUseDisorder
	--,dod.SedativeOpioidRX				-- formerly SedativeOpioid_RX]
	,dod.SedateIssueV2 AS SEDATEISSUE	-- formerly sedate_issue_v2
	,dod.PTSDDxPoss AS PTSD				-- formerly PTSDdx_poss
	,dod.OverSuicideV2 AS OVERDOSE_SUICIDE	 -- formerly Over_suicide_v2
	,dod.OtherSUDRiskModel	AS	OtherSUD_RiskModel		-- formerly OtherSUD_RiskModel
	,dod.OtherMH AS OTHER_MH_STORM
	,dod.Osteoporosis
	--,dod.opioid_tier
	,dod.OPIDdx_poss AS OUD
	,dod.NICdx_poss
	,dod.MEDD
	,dod.MDDdx_poss AS MDD
	,dod.InpMH AS MHINPAT	  -- formerly inp_mh
	,CASE WHEN dod.Gender= 'M' THEN 1 ELSE 0 END AS GenderMale
	,dod.er_visit AS ERVISIT 
	,dod.EH_WEIGHTLS
	,dod.EH_VALVDIS
	,dod.EH_UNCDIAB
	,dod.EH_RHEUMART
	,dod.EH_RENAL
	,dod.EH_PULMCIRC
	,dod.EH_PERIVALV
	,dod.EH_PEPTICULC
	,dod.EH_PARALYSIS
	,dod.EH_OTHNEURO
	,dod.EH_OBESITY
	,dod.EH_NMETTUMR
	,dod.EH_METCANCR
	,dod.EH_LYMPHOMA
	,dod.EH_LIVER
	,dod.EH_HYPOTHY
	,dod.EH_HYPERTENS
	,dod.EH_HEART
	,dod.EH_ELECTRLYTE
	,dod.EH_DefANEMIA
	,dod.EH_COMDIAB
	,dod.EH_COAG
	,dod.EH_CHRNPULM
	,dod.EH_BLANEMIA
	,dod.EH_ARRHYTH
	,dod.EH_AIDS
	,dod.dmis  --CLB: flagging for review that this is a matching field name
	,dod.CocaineUDAmphUD AS CocaineUD_AmphUD			-- formerly CocaineUD_AmphUD
	,dod.CannabisUDHallucUD	AS CannabisUD_HallucUD		-- formerly CannabisUD_HallucUD
	,dod.ACLDxPoss AS AUD_ORM		-- formerly ALCdx_poss
	--,dod.AgeGroup					-- formerly age_group
	,dod.AFFDxPoss AS BIPOLAR		-- formerly AFFdx_poss
	,dod.FirstName
	,dod.LastName
	,dod.DateOfBirth				-- formerly DOB
	,dod.ApproximateDate			-- formerly appx_dt
	,dod.ApproximateDateType		-- formerly appx_dt_type
	,dod.Age --3/24/22 CLB changed to dod.Age instead of mp.Age, since that results in NULL values for those not matching on SSN. Could consider replacing with actual calculation if want to align with CommonMasterpatient.
	-- Can we eliminate these case statements since ORM_RiskVariables already computes this?
	--,CASE WHEN mp.Age <= 30 THEN 1 ELSE 0 END AS Age30
	--,CASE WHEN mp.Age >=31 AND mp.Age <= 50 THEN 1 ELSE 0 END AS Age3150
	--,CASE WHEN mp.Age >= 51 AND mp.Age <= 65 THEN 1 ELSE 0 END AS Age5165
	--,CASE WHEN mp.Age >= 66 THEN 1 ELSE 0 END AS Age66    
FROM [PDW].[CDWWork_JVPN_TriSTORM] dod 
LEFT JOIN [Common].[MasterPatient] mp WITH (NOLOCK) 
	ON dod.SSN = mp.PatientSSN 
LEFT JOIN [SVeteran].[SMVIPersonSiteAssociation] sv WITH (NOLOCK) 
	ON dod.EDIPN = TRY_CAST(sv.EDIPI AS INT)
WHERE (mp.MVIPersonSID IS NOT NULL OR sv.MVIPersonSID IS NOT NULL)
	AND dod.ExtractionLoadDate = (SELECT MAX(ExtractionLoadDate) FROM [PDW].[CDWWork_JVPN_TriSTORM])