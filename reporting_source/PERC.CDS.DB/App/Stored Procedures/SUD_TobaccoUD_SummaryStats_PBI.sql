-- =============================================
-- Author:		Claire Hannemann
-- Create date: 6/18/24
-- Description:	SUD Tobacco - Summary stats for PBI report

-- =============================================
CREATE PROCEDURE [App].[SUD_TobaccoUD_SummaryStats_PBI]

AS
BEGIN
	SET NOCOUNT ON;
 
 
	DROP TABLE IF EXISTS #HF
	SELECT DISTINCT a.Homestation_VISN
			,a.Homestation_ChecklistID
			,a.Homestation_Facility
			,a.Homestation_Sta3n
			,st.StaffSID
			,st.StaffName
			,st.Sta3n as Staff_Sta3n
			,a.MVIPersonSID
			,a.HealthFactorDateTime
			,a.Past30days
			,a.HealthFactorType
	INTO #HF
	FROM (
		   SELECT DISTINCT d.Homestation_VISN
					,d.Homestation_ChecklistID
					,d.Homestation_Facility
					,ch.STA3N as Homestation_Sta3n
					,d.MVIPersonSID
					,a.HealthFactorDateTime
					,case when a.HealthFactorDateTime >= DATEADD(day,-30,cast(getdate() as date)) then 1 else 0 end as Past30days
					,b.HealthFactorType
					,case when a.EncounterStaffSID=-1 then t.SignedbyStaffSID else a.EncounterStaffSID end as EncounterStaffSID
			FROM [SUD].[TobaccoUD] d WITH (NOLOCK)
			INNER JOIN [Common].[MVIPersonSIDPatientPersonSID] e WITH (NOLOCK) on d.MVIPersonSID=e.MVIPersonSID
			INNER JOIN [HF].[HealthFactor] a WITH (NOLOCK) on e.PatientPersonSID=a.PatientSID
			INNER JOIN [Dim].[HealthFactorType] b WITH (NOLOCK) on a.HealthFactorTypeSID=b.HealthFactorTypeSID
			LEFT JOIN [Lookup].[ChecklistID] ch WITH (NOLOCK) on d.Homestation_ChecklistID=ch.ChecklistID
			LEFT JOIN [TIU].[TIUDocument] t WITH (NOLOCK) on a.VisitSID=t.VisitSID
			WHERE b.HealthFactorType in ('PROACTIVE OUTREACH ATTEMPTED', 'PROACTIVE ABLE TO REACH', 'PROACTIVE PT CONSENTS', 
										 'PROACTIVE PLANS GROUP', 'PROACTIVE PLANS HANDOFF QUITLINE', 'PROACTIVE PLANS E-REFERRAL QUITLINE', 'PROACTIVE PLANS TX PROGRAM',
										 'PROACTIVE PLANS MED REQUEST', 'PROACTIVE PLANS PRE-QUIT', 'PROACTIVE PLANS OTHER',
										 'PROACTIVE OUTREACH ATTEMPTED (PN)', 'PROACTIVE ABLE TO REACH (PN)', 'PROACTIVE CARE NEEDS YES (PN)',
										 'PROACTIVE PLANS GROUP (PN)', 'PROACTIVE PLANS HANDOFF QUITLINE (PN)', 'PROACTIVE PLANS E-REFERRAL QUITLINE (PN)', 'PROACTIVE PLANS TX PROGRAM (PN)',
										 'PROACTIVE PLANS MED REQUEST (PN)', 'PROACTIVE PLANS PRE-QUIT (PN)', 'PROACTIVE PLANS OTHER (PN)')
					and a.HealthFactorDateTime >= '3/11/2024'
		 ) a
	LEFT JOIN [SStaff].[SStaff] st WITH (NOLOCK) on a.EncounterStaffSID=st.StaffSID

	--DELETE FROM #HF WHERE Staff_Sta3n <> Homestation_Sta3n and Staff_Sta3n <> '-1'

	--create provider crosswalk to assign people who may have switched homestations back to the provider's original station
	DROP TABLE IF EXISTS #crosswalk
	SELECT DISTINCT StaffName, staffsid, Homestation_VISN, Homestation_ChecklistID, Homestation_Facility, Homestation_Sta3n
	INTO #crosswalk
	FROM #HF
	WHERE Staff_Sta3n = Homestation_Sta3n-- or Staff_Sta3n ='-1'
	ORDER BY Homestation_ChecklistID

	DROP TABLE IF EXISTS #HF_summary
	SELECT Homestation_VISN
			,Homestation_ChecklistID
			,Homestation_Facility
			,StaffSID
			,StaffName
			,MVIPersonSID
			,HealthFactorDateTime
			,max(IntakeAttempt) as IntakeAttempt
		--	,sum(IntakeAttempt) as IntakeAttemptSum
			,max(IntakeAttempt_30d) as IntakeAttempt_30d
		--	,sum(IntakeAttempt_30d) as IntakeAttemptSum_30d
			,max(IntakeAbleToReach) as IntakeAbleToReach
			,max(IntakeAbleToReach_30d) as IntakeAbleToReach_30d
			,max(IntakePtConsent) as IntakePtConsent
			,max(IntakePtConsent_30d) as IntakePtConsent_30d
			,max(IntakeTreatmentReferral) as IntakeTreatmentReferral
			,max(IntakeTreatmentReferral_30d) as IntakeTreatmentReferral_30d
			,max(FollowUpAttempt) as FollowUpAttempt
		--	,sum(FollowUpAttempt) as FollowUpAttemptSum
			,max(FollowUpAttempt_30d) as FollowUpAttempt_30d
		--	,sum(FollowUpAttempt_30d) as FollowUpAttemptSum_30d
			,max(FollowUpAbleToReach) as FollowUpAbleToReach
			,max(FollowUpAbleToReach_30d) as FollowUpAbleToReach_30d
			,max(FollowUpCareNeeds) as FollowUpCareNeeds
			,max(FollowUpCareNeeds_30d) as FollowUpCareNeeds_30d
			,max(FollowUpTreatmentReferral) as FollowUpTreatmentReferral
			,max(FollowUpTreatmentReferral_30d) as FollowUpTreatmentReferral_30d
			,max(TxReferral_Group) as TxReferral_Group
			,max(TxReferral_Group_30d) as TxReferral_Group_30d
			,max(TxReferral_HandoffQuitline) as TxReferral_HandoffQuitline
			,max(TxReferral_HandoffQuitline_30d) as TxReferral_HandoffQuitline_30d
			,max(TxReferral_EReferralQuitline) as TxReferral_EReferralQuitline
			,max(TxReferral_EReferralQuitline_30d) as TxReferral_EReferralQuitline_30d
			,max(TxReferral_TxProgram) as TxReferral_TxProgram
			,max(TxReferral_TxProgram_30d) as TxReferral_TxProgram_30d
			,max(TxReferral_MedRequest) as TxReferral_MedRequest
			,max(TxReferral_MedRequest_30d) as TxReferral_MedRequest_30d
			,max(TxReferral_PreQuit) as TxReferral_PreQuit
			,max(TxReferral_PreQuit_30d) as TxReferral_PreQuit_30d
			,max(TxReferral_Other) as TxReferral_Other
			,max(TxReferral_Other_30d) as TxReferral_Other_30d
	INTO #HF_summary
	FROM (
			SELECT Homestation_VISN
					,Homestation_ChecklistID
					,Homestation_Facility
					,StaffSID
					,StaffName
					,MVIPersonSID
					,HealthFactorDateTime
					,case when HealthFactorType='PROACTIVE OUTREACH ATTEMPTED' then 1 else 0 end as IntakeAttempt
					,case when HealthFactorType='PROACTIVE OUTREACH ATTEMPTED' and Past30days=1 then 1 else 0 end as IntakeAttempt_30d
					,case when HealthFactorType='PROACTIVE ABLE TO REACH' then 1 else 0 end as IntakeAbleToReach
					,case when HealthFactorType='PROACTIVE ABLE TO REACH' and Past30days=1 then 1 else 0 end as IntakeAbleToReach_30d
					,case when HealthFactorType='PROACTIVE PT CONSENTS' then 1 else 0 end as IntakePtConsent
					,case when HealthFactorType='PROACTIVE PT CONSENTS' and Past30days=1 then 1 else 0 end as IntakePtConsent_30d
					,case when HealthFactorType in ('PROACTIVE PLANS GROUP', 'PROACTIVE PLANS HANDOFF QUITLINE', 'PROACTIVE PLANS E-REFERRAL QUITLINE', 'PROACTIVE PLANS TX PROGRAM',
													'PROACTIVE PLANS MED REQUEST', 'PROACTIVE PLANS PRE-QUIT', 'PROACTIVE PLANS OTHER') then 1 else 0 end as IntakeTreatmentReferral
					,case when HealthFactorType in ('PROACTIVE PLANS GROUP', 'PROACTIVE PLANS HANDOFF QUITLINE', 'PROACTIVE PLANS E-REFERRAL QUITLINE', 'PROACTIVE PLANS TX PROGRAM',
													'PROACTIVE PLANS MED REQUEST', 'PROACTIVE PLANS PRE-QUIT', 'PROACTIVE PLANS OTHER') and Past30days=1 then 1 else 0 end as IntakeTreatmentReferral_30d
					,case when HealthFactorType in ('PROACTIVE OUTREACH ATTEMPTED (PN)','PROACTIVE ABLE TO REACH (PN)','PROACTIVE UNABLE TO REACH (PN)') then 1 else 0 end as FollowUpAttempt
					,case when HealthFactorType in ('PROACTIVE OUTREACH ATTEMPTED (PN)','PROACTIVE ABLE TO REACH (PN)','PROACTIVE UNABLE TO REACH (PN)') and Past30days=1 then 1 else 0 end as FollowUpAttempt_30d
					,case when HealthFactorType='PROACTIVE ABLE TO REACH (PN)' then 1 else 0 end as FollowUpAbleToReach
					,case when HealthFactorType='PROACTIVE ABLE TO REACH (PN)' and Past30days=1 then 1 else 0 end as FollowUpAbleToReach_30d
					,case when HealthFactorType='PROACTIVE CARE NEEDS YES (PN)' then 1 else 0 end as FollowUpCareNeeds
					,case when HealthFactorType='PROACTIVE CARE NEEDS YES (PN)' and Past30days=1 then 1 else 0 end as FollowUpCareNeeds_30d
					,case when HealthFactorType in ('PROACTIVE PLANS GROUP (PN)', 'PROACTIVE PLANS HANDOFF QUITLINE (PN)', 'PROACTIVE PLANS E-REFERRAL QUITLINE (PN)', 'PROACTIVE PLANS TX PROGRAM (PN)',
													'PROACTIVE PLANS MED REQUEST (PN)', 'PROACTIVE PLANS PRE-QUIT (PN)', 'PROACTIVE PLANS OTHER (PN)') then 1 else 0 end as FollowUpTreatmentReferral
					,case when HealthFactorType in ('PROACTIVE PLANS GROUP (PN)', 'PROACTIVE PLANS HANDOFF QUITLINE (PN)', 'PROACTIVE PLANS E-REFERRAL QUITLINE (PN)', 'PROACTIVE PLANS TX PROGRAM (PN)',
													'PROACTIVE PLANS MED REQUEST (PN)', 'PROACTIVE PLANS PRE-QUIT (PN)', 'PROACTIVE PLANS OTHER (PN)') and Past30days=1 then 1 else 0 end as FollowUpTreatmentReferral_30d
					,case when HealthFactorType like 'PROACTIVE PLANS GROUP%' then 1 else 0 end as TxReferral_Group
					,case when HealthFactorType like 'PROACTIVE PLANS GROUP%' and Past30days=1 then 1 else 0 end as TxReferral_Group_30d
					,case when HealthFactorType like 'PROACTIVE PLANS HANDOFF QUITLINE%' then 1 else 0 end as TxReferral_HandoffQuitline
					,case when HealthFactorType like 'PROACTIVE PLANS HANDOFF QUITLINE%' and Past30days=1 then 1 else 0 end as TxReferral_HandoffQuitline_30d
					,case when HealthFactorType like 'PROACTIVE PLANS E-REFERRAL QUITLINE%' then 1 else 0 end as TxReferral_EReferralQuitline
					,case when HealthFactorType like 'PROACTIVE PLANS E-REFERRAL QUITLINE%' and Past30days=1 then 1 else 0 end as TxReferral_EReferralQuitline_30d
					,case when HealthFactorType like 'PROACTIVE PLANS TX PROGRAM%' then 1 else 0 end as TxReferral_TxProgram
					,case when HealthFactorType like 'PROACTIVE PLANS TX PROGRAM%' and Past30days=1 then 1 else 0 end as TxReferral_TxProgram_30d
					,case when HealthFactorType like 'PROACTIVE PLANS MED REQUEST%' then 1 else 0 end as TxReferral_MedRequest
					,case when HealthFactorType like 'PROACTIVE PLANS MED REQUEST%' and Past30days=1 then 1 else 0 end as TxReferral_MedRequest_30d
					,case when HealthFactorType like 'PROACTIVE PLANS PRE-QUIT%' then 1 else 0 end as TxReferral_PreQuit
					,case when HealthFactorType like 'PROACTIVE PLANS PRE-QUIT%' and Past30days=1 then 1 else 0 end as TxReferral_PreQuit_30d
					,case when HealthFactorType like 'PROACTIVE PLANS OTHER%' then 1 else 0 end as TxReferral_Other
					,case when HealthFactorType like 'PROACTIVE PLANS OTHER%' and Past30days=1 then 1 else 0 end as TxReferral_Other_30d

			FROM #HF 
			) a
	GROUP BY Homestation_VISN
			,Homestation_ChecklistID
			,Homestation_Facility
			,StaffSID
			,StaffName
			,MVIPersonSID
			,HealthFactorDateTime

	DROP TABLE IF EXISTS #HF_summary2
	SELECT Homestation_VISN
			,Homestation_ChecklistID
			,Homestation_Facility
			,StaffSID
			,StaffName
			,MVIPersonSID
			,max(IntakeAttempt) as IntakeAttempt
			,sum(IntakeAttempt) as IntakeAttemptSum
			,max(IntakeAttempt_30d) as IntakeAttempt_30d
			,sum(IntakeAttempt_30d) as IntakeAttemptSum_30d
			,max(IntakeAbleToReach) as IntakeAbleToReach
			,max(IntakeAbleToReach_30d) as IntakeAbleToReach_30d
			,max(IntakePtConsent) as IntakePtConsent
			,max(IntakePtConsent_30d) as IntakePtConsent_30d
			,max(IntakeTreatmentReferral) as IntakeTreatmentReferral
			,max(IntakeTreatmentReferral_30d) as IntakeTreatmentReferral_30d
			,max(FollowUpAttempt) as FollowUpAttempt
			,sum(FollowUpAttempt) as FollowUpAttemptSum
			,max(FollowUpAttempt_30d) as FollowUpAttempt_30d
			,sum(FollowUpAttempt_30d) as FollowUpAttemptSum_30d
			,max(FollowUpAbleToReach) as FollowUpAbleToReach
			,max(FollowUpAbleToReach_30d) as FollowUpAbleToReach_30d
			,max(FollowUpCareNeeds) as FollowUpCareNeeds
			,max(FollowUpCareNeeds_30d) as FollowUpCareNeeds_30d
			,max(FollowUpTreatmentReferral) as FollowUpTreatmentReferral
			,max(FollowUpTreatmentReferral_30d) as FollowUpTreatmentReferral_30d
			,max(TxReferral_Group) + max(TxReferral_HandoffQuitline) + max(TxReferral_EReferralQuitline) + max(TxReferral_TxProgram) + max(TxReferral_MedRequest) + max(TxReferral_PreQuit) + max(TxReferral_Other) as TxReferral_Any
			,max(TxReferral_Group_30d) + max(TxReferral_HandoffQuitline_30d) + max(TxReferral_EReferralQuitline_30d) + max(TxReferral_TxProgram_30d) + max(TxReferral_MedRequest_30d) + max(TxReferral_PreQuit_30d) + max(TxReferral_Other_30d) as TxReferral_Any_30d
			,max(TxReferral_Group) as TxReferral_Group
			,max(TxReferral_Group_30d) as TxReferral_Group_30d
			,max(TxReferral_HandoffQuitline) as TxReferral_HandoffQuitline
			,max(TxReferral_HandoffQuitline_30d) as TxReferral_HandoffQuitline_30d
			,max(TxReferral_EReferralQuitline) as TxReferral_EReferralQuitline
			,max(TxReferral_EReferralQuitline_30d) as TxReferral_EReferralQuitline_30d
			,max(TxReferral_TxProgram) as TxReferral_TxProgram
			,max(TxReferral_TxProgram_30d) as TxReferral_TxProgram_30d
			,max(TxReferral_MedRequest) as TxReferral_MedRequest
			,max(TxReferral_MedRequest_30d) as TxReferral_MedRequest_30d
			,max(TxReferral_PreQuit) as TxReferral_PreQuit
			,max(TxReferral_PreQuit_30d) as TxReferral_PreQuit_30d
			,max(TxReferral_Other) as TxReferral_Other
			,max(TxReferral_Other_30d) as TxReferral_Other_30d
	INTO #HF_summary2
	FROM (
			SELECT Homestation_VISN
					,Homestation_ChecklistID
					,Homestation_Facility
					,StaffSID
					,StaffName
					,MVIPersonSID
					,IntakeAttempt
					,IntakeAttempt_30d
					,IntakeAbleToReach
					,IntakeAbleToReach_30d
					,IntakePtConsent
					,IntakePtConsent_30d
					,IntakeTreatmentReferral
					,IntakeTreatmentReferral_30d
					,FollowUpAttempt
					,FollowUpAttempt_30d
					,FollowUpAbleToReach
					,FollowUpAbleToReach_30d
					,FollowUpCareNeeds
					,FollowUpCareNeeds_30d
					,FollowUpTreatmentReferral
					,FollowUpTreatmentReferral_30d
					,TxReferral_Group
					,TxReferral_Group_30d
					,TxReferral_HandoffQuitline
					,TxReferral_HandoffQuitline_30d
					,TxReferral_EReferralQuitline
					,TxReferral_EReferralQuitline_30d
					,TxReferral_TxProgram
					,TxReferral_TxProgram_30d
					,TxReferral_MedRequest
					,TxReferral_MedRequest_30d
					,TxReferral_PreQuit
					,TxReferral_PreQuit_30d
					,TxReferral_Other
					,TxReferral_Other_30d

			FROM #HF_summary
			) a
	GROUP BY Homestation_VISN
			,Homestation_ChecklistID
			,Homestation_Facility
			,StaffSID
			,StaffName
			,MVIPersonSID
		

	SELECT Homestation_VISN
			,Homestation_ChecklistID
			,Homestation_Facility
			,StaffSID
			,StaffName
			,MVIPersonSID
			,IntakeAttempt
			,IntakeAttemptSum
			,IntakeAttempt_30d
			,IntakeAttemptSum_30d
			,IntakeAbleToReach
			,IntakeAbleToReach_30d
			,IntakePtConsent
			,IntakePtConsent_30d
			,IntakeTreatmentReferral
			,IntakeTreatmentReferral_30d
			,FollowUpAttempt
			,FollowUpAttemptSum
			,FollowUpAttempt_30d
			,FollowUpAttemptSum_30d
			,FollowUpAbleToReach
			,FollowUpAbleToReach_30d
			,FollowUpCareNeeds
			,FollowUpCareNeeds_30d
			,FollowUpTreatmentReferral
			,FollowUpTreatmentReferral_30d
			,TxReferral_Any
			,TxReferral_Any_30d
			,TxReferral_Group
			,TxReferral_Group_30d
			,TxReferral_HandoffQuitline
			,TxReferral_HandoffQuitline_30d
			,TxReferral_EReferralQuitline
			,TxReferral_EReferralQuitline_30d
			,TxReferral_TxProgram
			,TxReferral_TxProgram_30d
			,TxReferral_MedRequest
			,TxReferral_MedRequest_30d
			,TxReferral_PreQuit
			,TxReferral_PreQuit_30d
			,TxReferral_Other
			,TxReferral_Other_30d
	FROM #HF_summary2
	WHERE StaffSID=-1
	UNION
	SELECT b.Homestation_VISN
			,b.Homestation_ChecklistID
			,b.Homestation_Facility
			,a.StaffSID
			,a.StaffName
			,MVIPersonSID
			,IntakeAttempt
			,IntakeAttemptSum
			,IntakeAttempt_30d
			,IntakeAttemptSum_30d
			,IntakeAbleToReach
			,IntakeAbleToReach_30d
			,IntakePtConsent
			,IntakePtConsent_30d
			,IntakeTreatmentReferral
			,IntakeTreatmentReferral_30d
			,FollowUpAttempt
			,FollowUpAttemptSum
			,FollowUpAttempt_30d
			,FollowUpAttemptSum_30d
			,FollowUpAbleToReach
			,FollowUpAbleToReach_30d
			,FollowUpCareNeeds
			,FollowUpCareNeeds_30d
			,FollowUpTreatmentReferral
			,FollowUpTreatmentReferral_30d
			,TxReferral_Any
			,TxReferral_Any_30d
			,TxReferral_Group
			,TxReferral_Group_30d
			,TxReferral_HandoffQuitline
			,TxReferral_HandoffQuitline_30d
			,TxReferral_EReferralQuitline
			,TxReferral_EReferralQuitline_30d
			,TxReferral_TxProgram
			,TxReferral_TxProgram_30d
			,TxReferral_MedRequest
			,TxReferral_MedRequest_30d
			,TxReferral_PreQuit
			,TxReferral_PreQuit_30d
			,TxReferral_Other
			,TxReferral_Other_30d
	FROM #HF_summary2 a
	INNER JOIN #crosswalk b on a.StaffSID=b.StaffSID and a.StaffName=b.StaffName
	WHERE a.StaffSID <>-1
		
 
END