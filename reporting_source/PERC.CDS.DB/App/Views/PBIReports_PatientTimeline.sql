



-- =======================================================================================================
-- Author:		Christina Wade
-- Create date:	3/24/2025
-- Description:	To be used as Fact source in CaseFactors and Clinical_Insights cross-drill Power BI report.
--				Adapted from [App].[PowerBIReports_Timeline] 
--
--				Row duplication is expected in this dataset.
--
-- Modifications:
-- 5/15/2025 -- Adding in Demo Mode data; logic in line with SUD Case Finder Demo data
--
--
-- =======================================================================================================

CREATE VIEW [App].[PBIReports_PatientTimeline] AS

	select distinct MVIPersonSID
		,EventType
		,EventCategory
		,EventDetails
		,StartDate=cast(StartDate as date)
		,EndDate=cast(EndDate as date)
		,Label
		,case when eventtype = 'Suicide Event or Overdose' then 1 
			  when eventtype = 'MH Admission' then 2
	  		  when eventtype = 'Psychotherapy' then 3
			  when eventtype = 'Psychotropic Medications' then 4
			  end EventSort
	from ( 
		select distinct m.MVIPersonSID
				,'Psychotropic Medications' as EventType 
				,case when a.OpioidForPain_rx = 1 or a.OpioidAgonist_Rx=1  then 'Opioid'
					  when a.Anxiolytics_Rx = 1 or a.Benzodiazepine_Rx =1  then 'Anxiolytic or Benzodiazepine'
					  when a.Antidepressant_Rx = 1 then 'Antidepressant'
					  when a.Antipsychotic_Rx =1 then 'Antipsychotic'
					  when a.MoodStabilizer_Rx = 1 then 'Mood Stabilizer'
					  when Stimulant_Rx = 1 then 'Stimulant'
					  END AS EventCategory
				,a.DrugNamewithoutdose as EventDetails
				,m.TrialStartDateTime as StartDate
				,m.TrialEndDateTime as EndDate
				,case when m.MPR_Trial is not null and m.MPR_Trial <1 then 'MPR: ' + cast(cast(m.MPR_Trial*100 as int) as varchar(50)) +'%' 
					  when m.MPR_Trial is not null and m.MPR_Trial >=1 then 'MPR: 100%' 
					  else '' end AS Label
		FROM Common.PBIReportsCohort as p WITH (NOLOCK) 
		INNER JOIN [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Drug] AS m WITH (NOLOCK) ON  m.MVIPersonSID = p.MVIPersonSID
		INNER JOIN (select distinct DrugNameWithoutDose, Psychotropic_Rx ,Benzodiazepine_Rx,	OpioidForPain_Rx 
					  ,Stimulant_Rx,Antipsychotic_Rx,Antidepressant_Rx,Anxiolytics_Rx,MoodStabilizer_Rx ,OpioidAgonist_Rx
					  from  [lookup].[nationaldrug] WITH (NOLOCK)) AS a 
					  on a.drugnamewithoutdose = m.drugnamewithoutdose 
		WHERE TrialStartDateTime > getdate() - 3650 and 
			( Psychotropic_Rx = 1 or
			--    Anxiolytics_Rx = 1 or
					Benzodiazepine_Rx = 1 or
			--		Antipsychotic_Rx = 1 or
					OpioidForPain_Rx = 1 
			--	or	MoodStabilizer_Rx = 1 or
			--		--SedatingPainORM_Rx = 1 
				or	Stimulant_Rx = 1 
			--	or	Antidepressant_Rx = 1 
			or	OpioidAgonist_Rx = 1 
			) 

	UNION 

		SELECT DISTINCT m.MVIPersonSID
			,'Psychotropic Medications' as EventType 
			,'Opioid' AS EventCategory
			,m.DrugNamewithdose as EventDetails
			,m.TrialStartDateTime as StartDate
			,m.TrialEndDateTime as EndDate
			, case when m.MPR_Trial is not null then 'MPR: ' + cast(cast(m.MPR_Trial*100 as int) as varchar(50)) +'%' 
				  else '' end AS Label
		FROM Common.PBIReportsCohort as p WITH (NOLOCK)
		inner join [PDW].[OIT_Rockies_DOEx_OIT_Rockies_MPR_Opioid] AS m WITH (NOLOCK) ON  m.MVIPersonSID = p.MVIPersonSID
		WHERE TrialStartDateTime > getdate() - 3650 

	UNION 

		select distinct p.MVIPersonSID
			,'MH Admission'
			,case when MentalHealth_TreatingSpecialty=1 THEN 'MH'
					--WHEN MedSurgInpatient_TreatingSpecialty =1 THEN 'Med Surg'
					--WHEN a.SedatingPainORM_rx = 1 THEN 'Non-Opioid Pain Medications'
					when Domiciliary_TreatingSpecialty=1 or Residential_TreatingSpecialty=1 
						or Homeless_TreatingSpecialty =1  then 'Residential'
					when NursingHome_TreatingSpecialty =1 then 'NursingHome'
				END AS EventCategory
			,b.TreatingSpecialtyName
			,BsInDateTime
			,case when BsOutDateTime is null or BsOutDateTime = '12/31/2100 12:00:00 AM' then getdate()+30 
					else BsOutDateTime end BsOutDateTime
			,case when BsOutDateTime is null or BsOutDateTime = '12/31/2100 12:00:00 AM' then AdmitDiagnosis + ' (Currently Admitted)'
					else AdmitDiagnosis end AdmitDiagnosis
		from Common.PBIReportsCohort as p WITH (NOLOCK)
		inner join Common.InpatientRecords as a WITH (NOLOCK) on p.MVIPersonSID=a.MVIPersonSID 
		inner join LookUp.TreatingSpecialty as b WITH (NOLOCK) on a.TreatingSpecialtySID = b.TreatingSpecialtySID
		where b.MedSurgInpatient_TreatingSpecialty = 0 

	UNION 

		select distinct p.MVIPersonSID
			,'Suicide Event or Overdose'
			,EventType
			,SDVClassification
			,EventDateFormatted
			,dateadd(d,1,EventDateFormatted)
			,MethodType1
		from Common.PBIReportsCohort as p WITH (NOLOCK)
		inner join OMHSP_Standard.SuicideOverdoseEvent AS a WITH (NOLOCK)  ON A.MVIPERSONSID = p.MVIPersonSID
		where EventDateFormatted > getdate() - 7300 

	UNION

		SELECT p.MVIPersonSID,
		'Psychotherapy'
		,TemplateGroup
		,TemplateGroup
		,VisitDateTime
		,dateadd(d,1,VisitDateTime)
		,''
		FROM Common.PBIReportsCohort as p WITH (NOLOCK)
		INNER JOIN EBP.TemplateVisits e WITH (NOLOCK) ON p.MVIPersonSID=e.MVIPersonSID
		WHERE VisitDateTime > getdate() - 3650
	) as a 
	where eventcategory is not null

	UNION

	SELECT DISTINCT MVIPersonSID
		,TimelineEventType
		,TimelineEventCategory
		,TimelineEventDetails
		,TimelineStartDate
		,TimelineEndDate
		,TimelineLabel
		,TimelineEventSort
	FROM [App].[PBIReports_TestPatients] WITH (NOLOCK)