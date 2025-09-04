
/* ==========================================================================================
  Authors:        Catherine Barry; modified by Grace Chung
  Create date: 2023-08-21
  Description: This Dashboard helps MHTC to track their to do list in the note 
                 
  Modifications: 
  2024-04-12   G.C.  Added Note title and Note Date to the report 
  2024-04-24   G.C.  Added patient PCMM team 
  2024-05-09   G.C.  Include NA cases in the report, change patientSSN to last4
  2024-05-14   G.C.  Remove '_@@@@@@@@@@@@@@_' from HF comments 
  2024-06-10  Barry, Catherine	Identify cases in Step 1 where an NA should cancel out a preceding Ongoing or FU action
  2024-06-11   G.C.  Replace HealthFactorType with Print Name, added "HF Category" column   
  2024-06-17   G.C.  Update NA cancellation codes
  2024-06-18   G.C.  Update DIM.HealthFactorType table "HealthFactorCategory" reference 
  2024-06-21   G.C.  Changed 'ONGOING' to 'Ongoing'
  2024-07-09   G.C.  Added Note Author 
  2024-10-30   G.C.  Adding upcoming appointment, use Present.AppointmentsFuture instead of Appt.Appointment_recent 
  2024-11-18   G.C.  Remove rows from detail that do not have a match in cohort final table 
  2025-02-10   G.C.  Added 'MHTC BHIP CC NEEDS ASSESSMENT AND INTERVENTION PLAN CONSULT' as a third note title 
                     Identify cases in Step 1 where an NA and 'Today%' should cancel out a preceding Ongoing or FU action
  2025-04-22   G.C.  Exclude Test patients from COMMON.MASTERPATIENT
  2025-04-24   G.C.  Fix duplicate HF_KEY 
  2025-05-27   G.C.  Change input table to BHIP.Templates
  2025-05-29   G.C.  Removed 'NA' cases from #BI_PAT2; Removed NA column from BHIP.MHTC_FollowUp
                     Update logic in STEP 1b to remove null joins in #NA_TODAY_FU and #NA_TODAY_OG
					 Update logic in STEP 1b to also join the tables by Healthfactordatetime in #BI_PAT1_NA_FU and #BI_PAT1_NA_OG 
					 Remove Patientsid and added MVIPersonsid in BHIP.MHTC_FollowUp
  2025-06-02	CNB	Revamped inclusion of BHIP.Templates. 
				Also correct a bug where Ongoing cases with later 'Today' action were being removed; Ongoing should only be removed due to an 'NA'; today just indicated a date when the ongoing item was completed. 
  2025-06-09    G.C. Use HealthFactorDateTime if VisitDateTime is null
 ==========================================================================================*/
CREATE PROCEDURE [Code].[BHIP_MHTC_FollowUp]

AS BEGIN
/***************************************************************************************************************************
STEP 1 IDENTIFY PATIENTS WITH HEALTH FACTORS FROM THE BHIP MHTC CC ASSESSMENT AND INTERVENTION NOTE
***************************************************************************************************************************/

	DROP TABLE IF EXISTS #BI_PAT1   
	SELECT distinct CHECKLISTID
		--,  V.PATIENTSID
		,  B.MVIPERSONSID
		,  C.PATIENTICN
		,  HEALTHFACTORSID
		,  cast(EntryDateTime as datetime2(0)) Note_Date
		,  TIUDocumentDefinition Note_Title 
		,  StaffName Author 
		,  COALESCE(VISITDATETIME, Healthfactordatetime) VISITDATETIME 
		,  B.VISITSID 
		,  HealthFactorDTAType as HealthFactorType
		, List
		, (CASE WHEN list like '%FollowUp' THEN 'FollowUp'  
			    WHEN list like '%Ongoing' THEN 'Ongoing'  
			    WHEN list like '%NA' THEN 'NA' 
				WHEN list LIKE '%Today'  THEN 'Today' 
			   ELSE '' END) HF_CATEGORY
		,  PrintName
		,  cast(HEALTHFACTORDATETIME as datetime2(0)) HEALTHFACTORDATETIME
		, Replace( COMMENTS,'_@@@@@@@@@@@@@@_','') COMMENTS
	INTO #BI_PAT1   
	FROM BHIP.Templates B WITH (NOLOCK)    --for testing only
	--FROM BHIP.Templates B 
	LEFT JOIN COMMON.vwMVIPersonSIDPatientICN as c WITH (NOLOCK) on B.mvipersonsid = C.mvipersonsid
	WHERE TIUDocumentDefinition in ('MHTC BHIP CC Needs Assessment and Intervention', 'MHTC BHIP CC NEEDS ASSESSMENT AND INTERVENTION PLAN','MHTC BHIP CC NEEDS ASSESSMENT AND INTERVENTION PLAN_CONSULT') --grace 6/3
	ORDER BY  HEALTHFACTORDATETIME  

		/*****************
		--STEP 1b IDENTIFY NA or TODAY cases to remove/replace prior (if exists) OG or FU selections  --4829
		*****************/
		
		DROP TABLE IF EXISTS #alltrunc   
		SELECT *
		,CASE
			WHEN RIGHT(List, 9) = '_FollowUp' THEN LEFT(list, LEN(list) - 9)
			WHEN RIGHT(list, 6) = '_Today' THEN LEFT(list, LEN(list) - 6)
			WHEN RIGHT(list, 8) = '_Ongoing' THEN LEFT(list, LEN(list) - 8) --GRACE: missing NA?
			WHEN Right(list,3) = '_NA' THEN LEFT(list, LEN(list) -3) 
			ELSE list
		END AS truncated_HF
		INTO #alltrunc
		FROM #BI_PAT1  
		where HF_Category <>''
		--select top 100 * from #alltrunc
		
		
		--NA
		DROP TABLE IF EXISTS #NA_TODAY --select * from #NA_TODAY where patienticn = 1014598300
		select patienticn
			,list
			, healthfactordatetime
			,checklistid
			,truncated_HF
			,HF_category --need to keep this to differentiate between NA and Today in a later step
		INTO #NA_TODAY
		FROM #alltrunc
		where (HF_Category = 'NA' or HF_Category = 'TODAY')
		--select top 10 * from #na_today

		--select * from #NA_TODAY  where checklistid in ('653','668','687','692','556','757')

		--FU
		DROP TABLE IF EXISTS #FU 
		select patienticn
			,list
			, healthfactordatetime
			,checklistid
			,truncated_HF
			,HF_Category
		INTO #FU
		FROM #alltrunc
		where HF_Category = 'FollowUp'
		
		----select top 10 * from #FU

		--OG
		DROP TABLE IF EXISTS #OG   
		select patienticn
			,list
			, healthfactordatetime
			,checklistid
			,truncated_HF
			, HF_category
		INTO #OG
		FROM #alltrunc
		where HF_Category = 'Ongoing'

		--

		--Find later HF date of NA/TODAY HF_Type having same Truncated_HF value as a FU HF_Type 
		DROP TABLE IF EXISTS #NA_TODAY_FU  
		SELECT * INTO #NA_TODAY_FU  
		FROM 
		(
			select n.patienticn, n.list as HF_NA, n.HealthFactorDateTime HF_Time_NA, f.list as HF_FU, f.HealthFactorDateTime HF_Time_FU 
			from #NA_Today n
			left join #FU f 
			on n.patienticn = f.patienticn
			and n.truncated_HF = f.truncated_HF 
			and n.HealthFactorDateTime >  f.healthfactordatetime  
		) as a 
		WHERE HF_FU is not null

		--Find later HF date of NA HF_Type having same Truncated_HF value as a OG HF_Type 
		--Identify when an 'Ongoing' action has an 'NA' action sometime afterward, indicating the ongoing action is no longer needed. 
		--ONLY remove if this is N/A; 'today' should not be removed for an ONGOING type b/c it is meant to continue and only an N/A indicates it should not longer continue
		DROP TABLE IF EXISTS #NA_OG 
		select *
		INTO #NA_OG 
		FROM
		(
			SELECT n.patienticn, n.list HF_NA, n.HealthFactorDateTime HF_Time_NA, O.list HF_OG, O.HealthFactorDateTime HF_Time_OG 
			from #NA_TODAY n  
			left join #OG O
			on n.patienticn = O.patienticn 
			and n.truncated_HF = O.truncated_HF 
			and n.HealthFactorDateTime > O.healthfactordatetime  
			and n.hF_category='NA' --only use the NA; 'today' doesn't cancel out ongoing items
		) as a 
		WHERE HF_OG is not null
		--select top 10 * from #NA_TODAY_OG 


		--Remove NA_FU Records from #BI_PAT1 #BI_PAT1_NA_FU		
		DROP TABLE IF EXISTS #BI_PAT1_NA_TODAY_FU    --select * from #BI_PAT1_NA_TODAY_FU where patienticn = 1014598300
		select * 
		INTO #BI_PAT1_NA_TODAY_FU
		from #BI_PAT1 B     
		WHERE NOT EXISTS 
			(select PatientICN, HF_NA from #NA_TODAY_FU N WHERE B.patienticn = N.patientICN and B.list = N.HF_NA and B.HealthfactorDateTime = N.HF_Time_NA)
		and NOT EXISTS 
			(SELEct PatientICN, HF_FU from #NA_TODAY_FU N WHERE B.patienticn = N.patientICN and B.list = N.HF_FU and B.HealthfactorDateTime = N.HF_Time_FU)

---CNB: 6/2/25 Validate to be on the look out for incorrect Ongoing removals: if there are 2 or more Ongoing, they should NOT cancel each other out, but they might be cancelling out sometimes below? 
		--Remove NA_OG Records from #BI_PAT1_NA_FU
		DROP TABLE IF EXISTS #BI_PAT1_NA_OG   
		select * 
		INTO #BI_PAT1_NA_OG 
		from #BI_PAT1_NA_TODAY_FU NF
		WHERE NOT EXISTS 
			(select PatientICN, HF_NA from #NA_OG N WHERE NF.patienticn = N.patientICN and NF.list = N.HF_NA and NF.Healthfactordatetime = N.HF_Time_NA )   
		and NOT EXISTS  
			(SELEct PatientICN, HF_OG from #NA_OG N WHERE NF.patienticn = N.patientICN and NF.list = N.HF_OG and NF.Healthfactordatetime = N.HF_Time_OG)    

/***************************************************************************************************************************
STEP 2: ADD a HF_KEY FOR POWER BI DRILL DOWN TABLE JOINS
***************************************************************************************************************************/
	DROP TABLE IF EXISTS #BI_PAT2  
	SELECT *
		, CONCAT(ChecklistID,'-',PATIENTICN,'-', VISITDATETIME ) AS HF_KEY 
	INTO #BI_PAT2
	FROM #BI_PAT1_NA_OG 
	WHERE HF_Category='FollowUp' or HF_Category = 'Ongoing' 
	 

	DROP TABLE IF EXISTS #BI_PAT3  
	SELECT DISTINCT 
		   CHECKLISTID
		--,  PATIENTSID
		,  MVIPERSONSID
		,  PATIENTICN
		,  VISITDATETIME 
		,  VISITSID
		,  HEALTHFACTORSID 
		,  HealthFactorType
		,  HF_CATEGORY
		,  PrintName
		,  HEALTHFACTORDATETIME
		,  COMMENTS
		,  HF_KEY
		, list
	INTO #BI_PAT3
	FROM #BI_PAT2 
 
/***************************************************************************************************************************
STEP 2: IDENTIFY TRACKING ITEMS: FOLLOWUP, ONGOING ETC.
***************************************************************************************************************************/
	DROP TABLE IF EXISTS #BI_SUM1  
	SELECT DISTINCT 
		CHECKLISTID
		, S.MVIPERSONSID
		--, S.Patientsid 
		, S.PATIENTICN
		, M.PATIENTNAME
		, M.PATIENTSSN
		, S.Note_Date
		, S.Note_Title
		, S.Author
		, S.VISITSID 
		, Visitdatetime 
		, FOLLOWUP = SUM(CASE WHEN HF_Category = 'FOllowUp' THEN 1 ELSE 0 END)
		, ONGOING = SUM(CASE WHEN HF_Category = 'Ongoing' THEN 1 ELSE 0 END)
		, NA = SUM(CASE WHEN HF_Category='NA' THEN 1 ELSE 0 END)
	INTO #BI_SUM1  
	FROM #BI_PAT2 S 
		INNER JOIN COMMON.MASTERPATIENT AS M WITH (NOLOCK) ON S.MVIPERSONSID=M.MVIPERSONSID
		WHERE M.Testpatient = 0
	GROUP BY CHECKLISTID,S.MVIPERSONSID, S.PATIENTICN,  M.PATIENTNAME, M.PATIENTSSN, HEALTHFACTORDATETIME, S.VisitSID, /*patientsid ,*/ Note_date, Note_title, Author, visitdatetime 
	ORDER BY S.MVIPERSONSID, VisitDateTime 

/***************************************************************************************************************************
 STEP 4: Get Patient PCMM Team 
***************************************************************************************************************************/
	DROP TABLE IF EXISTS #PCMM -- 
	SELECT MVIPersonsid
		, v.PatientICN
		, l.checklistid
		, patientsid
		, staffname
		, primarystandardposition ProvType
		, team
		, Teamfocus
		, relationshipstartdate  
	INTO #PCMM
	FROM  [PDW].[VSSC_Out_DoEX_VSSCPCMMAssignments] V
		LEFT JOIN [SStaff].[SStaff] AS st WITH (NOLOCK) ON v.PrimaryProviderSID = st.staffsid
		LEFT JOIN [LookUp].[Sta6a] as sta WITH (NOLOCK) ON v.InstitutionCode = sta.Sta6a
		LEFT OUTER JOIN Common.MasterPatient AS mv WITH (NOLOCK) ON v.PatientICN = mv.PatientICN
		LEFT JOIN [Lookup].[ChecklistID] AS l WITH (NOLOCK) ON l.ChecklistID = sta.ChecklistID
	WHERE 1=1
		AND MVIPersonsid in (select distinct MVIPersonsid from #BI_PAT1 )
		AND PrimaryStandardPosition LIKE '%MHTC%'
		AND RelationshipEndDate is NULL
		And mv.TestPatient = 0 
/***************************************************************************************************************************
 STEP 5: CREATE FINAL OUTPUT TABLE
***************************************************************************************************************************/
DROP TABLE IF EXISTS #STAGE   
select 
VISN
, ADMPARENT_FCDM
, Mvipersonsid
--, Patientsid 
, PATIENTNAME
, PATIENTSSN
, Last4
, PATIENTICN 
, CHECKLISTID
, COALESCE(MHTC_PCMM,'No BHIP Team') MHTC_PCMM
, Visit_Date 
, Note_Date 
, Note_Title
, Author
, FOLLOWUP
, ONGOING
, NA 
, HF_KEY
INTO #STAGE  
FROM 
(
SELECT Distinct 
VISN
, ADMPARENT_FCDM
, H.Mvipersonsid
--, H.Patientsid 
, PATIENTNAME
, PATIENTSSN 
, Right(PATIENTSSN, 4) Last4
, H.PATIENTICN 
, H.CHECKLISTID
, Team MHTC_PCMM
, Visitdatetime   AS Visit_Date
, Note_Date
, Note_Title
, Author 
, FOLLOWUP
, ONGOING
, NA 
, CONCAT(H.CHECKLISTID,'-', H.PatientICN,'-',VisitDateTime ) HF_KEY
, ROW_Number() OVER(PARTITION BY H.checklistid,H.patienticn,VisitDateTime  ORDER BY Note_Date DESC) as RN
FROM #BI_SUM1   H
INNER JOIN  [LOOKUP].[STA6A] L WITH (NOLOCK) on H.checklistid = l.checklistid 
LEFT JOIN #PCMM p on h.checklistid = p.checklistid and h.MVIPersonSID = p.MVIPersonSID
WHERE (FOLLOWUP>=1 OR ONGOING>=1 OR NA=1) 
) as a
WHERE RN=1
ORDER BY PATIENTICN, Visit_Date

/**********************************************************
Upcoming appointments for patients 
**********************************************************/
DROP TABLE IF EXISTS #App 
;WITH StopCodes AS 
(
	SELECT sta3n
		,stopcodename
		,stopcode
		,stopcodesid
	FROM [LookUp].[StopCode]
    WHERE MHOC_MentalHealth_Stop = 1
)
,Locations AS 
(
	SELECT l.sta3n
	    ,l.locationsid 
		,l.locationname
	FROM [Dim].[Location] l
	JOIN stopcodes s ON l.sta3n = s.sta3n
		AND l.PrimaryStopCodeSID = s.stopcodesid
	WHERE locationname NOT LIKE 'zz%'
)
SELECT Distinct a.sta3n
    , s.PatientICN 
	,A.appointmentdatetime
	,d.locationname AS Clinic
,   ROW_Number() OVER(PARTITION BY a.sta3n, a.patientsid ORDER BY Appointmentdatetime ) as RN	
INTO #APP 
FROM Locations d
INNER JOIN Present.AppointmentsFuture A WITH (NOLOCK) ON d.locationsid = a.locationsid
JOIN #Stage s on a.checklistid = s.checklistid and a.mvipersonsid=s.mvipersonsid   
WHERE  appointmentdatetime >  getdate()

/**********************************************************
Final Table: select latest appointment from each patient and add to table #stage
**********************************************************/
DROP Table IF EXISTS #Final 
select 
VISN
, ADMPARENT_FCDM
, Mvipersonsid 
, PATIENTNAME
, PATIENTSSN
, Last4
, S.PATIENTICN 
, CHECKLISTID
, MHTC_PCMM
, CAST(Visit_Date as datetime2(0)) Visit_Date
, Note_Date
, Note_Title
, Author 
, p.AppointmentDateTime Next_Appt
, CASE WHEN datediff(day,getdate(),p.AppointmentDateTime) between 0 and 30 THEN 'Next 30 days'
       WHEN datediff(day,getdate(),p.AppointmentDateTime) between 31 and 60 THEN 'Next 31-60 days'
	   WHEN datediff(day,getdate(),p.AppointmentDateTime) between 61 and 90 THEN 'Next 61-90 days'
	   WHEN datediff(day,getdate(),p.AppointmentDateTime) > 90 THEN 'Next 91 days +'
	   ELSE 'No upcoming appt'
	   END as 'Appt_date_Groups'
, p.Clinic
, FOLLOWUP
, ONGOING 
, HF_KEY
INTO #Final   
from #Stage s 
left join #APP p on s.patienticn = P.PatientICN and LEFT(s.CHECKLISTID,3) = p.Sta3n
where P.rn= 1 or p.rn is null
--*********************************************************************************

EXEC [Maintenance].[PublishTable] 'BHIP.MHTC_FollowUpDetails','#BI_PAT3'  
EXEC [Maintenance].[PublishTable] 'BHIP.MHTC_FollowUp','#Final' --

END