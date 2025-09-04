
/* ==========================================================================================
  Authors:        Catherine Barry; modified by Grace Chung
  Create date: 2023-08-21
  Description: Code to generate an SSRS report to identify and compare MHTC assignments from a) MHTC note templates/health factors and b) PCMM tables
                 
  Modifications: 
  2023-08-26	CNB Truncated to include only Pilot sites
  2023-08-29	CNB	Reformatted results to be more readable in field-facing report 
				 and truncated to include only cases where there is a) no PCMM MHTC or b) the PCMM MHTC has a relationship start date PRIOR to the MHTC Note template, which indicates the PCMM entry needs updateing
  2023-09-22	CNB	Added code to compare MHTC name in the MHTC Note vs. in PCMM and to remove matching cases (they are not actionable)
  2023-09-28	CNB Added 596A4 as part of Pilot list; was previously misspecified
  2023-11-15    Grace Chung (GC)
                1. #AddLocationsVistA was created and renamed to #PatientHealthFactorBHIP, and not used in rest of query.
				   Therefore, the step to renamed was commented out and step to create #AddLocationsVistA was changed to 
				   #PatientHealthFactorBHIP
				2. #g1team was created and not used in downstream queries and therefore the step was commented out
				3. Updated step that generates single record for each patient from Max to Partition with latest HealthFactorDateTime
  2023-11-21    Grace Chung
				1. combine condition in step #mhtc_hp2 to #mhtc_hp
				2. add partition in step to extract unique record to be site specific  
  2023-11-22	CNB In preparation for future needs and validation testing: Removed limitation to pilot facility; all facilities now included (but currently only pilots are using the relevant note templates)
  2023-11-28    GC	Added Note Date in lieu of HealthFactorDateTime 
  2024-02-02    GC Changed partition of unique record to order by note entrydatetime only instead of entrydatetime, healthfactordatetime  
  2024-03-11    GC	Added a step to retrieve latest Healthfactordatetime before joining the notes table to correct the note data pull
  2024-03-26    GC  Unassigned patients were not showing in the report.  Added a separated step to retrieve unassigned patients. 
  2024-03-28    GC  Included reassignment records having NULL PCMM data.  Those might have misuse the healthfactor 'Reassign' when they should use 'Initial assignment'
  2024-04-22    GC  Pull PCMM data from [PDW].[VSSC_Out_DoEX_VSSCPCMMAssignments] instead of Present.Providers for update to date data
  2024-04-29    GC  Added code to #ACTIONABLE that would take care of last name comparison when one has an extra space than the other
  2024-04-30	JEB D&A PERC Support - Added alias to remove Build Warning
  2024-06-26    GC  Replace '.','-',' ' with '' for Note_MHTC and PCMM staffnames 
  2024-07-09    GC  changed multiple Replace statements with a [Dflt].[ufn_FormatName] function
  2024-08-16    GC  Switched note title source from Lookup.ListMember to [Dim].[TIUDocumentDefinition]
                    Commented out new tables for HotFix version
					Uncommented out new tables for next month release 
  2024-08-19    GC  Update #Helpdesk to #MHTC_hp
  2024-08-20    GC  Change not title table back to Lookup.Listmember (This update has been changed from weekly to nightly job)
  2024-09-16    GC  Change date range to 1 year back
  2024-09-25    GC  Added "Note Author" column
  2024-10-25    GC  Fixed last name matching error for last name having two words.  Logic updated to only select first word of two-word last names 
                    #actionable logic updated to first select matching records and send the rest to #actionable 
  2025-02-10    GC  Added 'MHTC BHIP CC NEEDS ASSESSMENT AND INTERVENTION PLAN CONSULT' as a third note title 
  2024-02-18    GC  Update #MHTC_hp logic to take either HealthFactorDateTime <= EntryDateTime or HealthFactorDateTime and EntryDateTime entered on the same date
  2024-03-13    GC  Update [PDW].[VSSC_Out_DoEX_VSSCPCMMAssignments] with [Comm].[providers] 
                    Exclude records from final report if matching records found in [Common].[ProviderTeamHistory] 
  2024-04-17    GC  Exclude test patients from cohort 
  2024-05-22    GC  Use BHIP.Templates as input table
  2024-07-10    GC  Fix logic in step #MHTC_hp: RelationshipstartDate needs to be >= HealthFactorDate
  2024-07-21    GC  Fix #MHTC_hp logic by commenting out RelationshipstartDate needs to be >= HealthFactorDate
  ==========================================================================================
 
 HF of interest:
First - type of assignment, must choose 1
		VA-MH-BHIP-INITIAL ASSIGN
		VA-MH-BHIP-REASSIGN
		VA-MH-BHIP-UNASSIGN
Then, information about MHTC
		Mental Health Treatment Coordinator --note; this HF was available prior to this national note; in order to pull the correct MHTC for this note, use in conjunction with Assignment type
Then, information about reason for a) reassignment or b) unassignment	
		VA-MH-BHIP-REASS-REQUEST	
		VA-MH-BHIP-REASS-TEAM	
		VA-MH-BHIP-REASS-TRANS	
		VA-MH-BHIP-REASS-OTH
		VA-MH-BHIP-VET PREFER UN
		VA-MH-BHIP-VET CITC	
		VA-MH-BHIP-VET DISCHARGE	
		VA-MH-BHIP-VET NEW FACILITY	
		VA-MH-BHIP-VET OTHER
	list 
	, 'MHTC_BHIPCC_InitialAssign', 'MHTC_BHIPCC_Reassign', 'MHTC_BHIPCC_Unassign')

--REMEMBER: If the agn_type is null it usually means the wrong/non-national MHTC note was used (or the national note was cut-and-pasted) and these cases won't be pulled into step 3

-----------------------------------*/
 
CREATE PROCEDURE [Code].[BHIP_MHTCAssignment]

AS BEGIN


/****************************************************/
/* Step 1: pull MHTC Assignment records from BHIP.Templates*/
/****************************************************/
Drop table if Exists #BHIP_Template  --select  * from #BHIP_Template where mvipersonsid = 52732808
select * 
INTO #BHIP_Template
FROM BHIP.Templates t WITH (NOLOCK)
WHERE category like 'MHTC BHIP CC Assignment'
/****************************************************/
/* Step 2: Combine note and HF to one record*/
/****************************************************/
DROP TABLE IF EXISTS #NOTE_HF  --select * from #Note_HF where mvipersonsid =  13675760
select a.*, v.patienticn , v.patientname, v.LastFour
into #NOTE_HF
from
(
select t1.mvipersonsid 
    , t1.checklistid
	, t1.visitsid
	, t1.healthfactordatetime
	--, ROW_Number() OVER(PARTITION BY  t1.checklistid,t1.mvipersonsid ORDER BY t2.EntryDateTime DESC ) as RN
	, t1.EntryDateTime AS Note_Date
	, t1.Staffname Note_Author
	, TRIM(t2.comments) AS Note_MHTC
	, asgn_type = CASE When t1.list like 'MHTC_BHIPCC_InitialAssign' then 'Initial Assignment'
	                   when t1.list like 'MHTC_BHIPCC_Unassign' then 'Unassignment'
					   when t1.list like 'MHTC_BHIPCC_Reassign' then 'Re-Assignment'
				  End  
	from #BHIP_Template t1   WITH (NOLOCK) 
	Left JOIN #BHIP_Template t2 WITH (NOLOCK) on t1.mvipersonsid = t2.mvipersonsid and t1.entrydatetime = t2.entrydatetime  and t1.visitsid = t2.visitsid 
	and t1.list in ('MHTC_BHIPCC_InitialAssign','MHTC_BHIPCC_Unassign','MHTC_BHIPCC_Reassign') and t2.list like 'MHTC_BHIPCC_MHTCName'
) as a 
left join Common.MasterPatient v WITH (NOLOCK) on a.mvipersonsid = v.mvipersonsid 
where asgn_type is not null
/*******************************************
Step 3: Pull PCMM Data
*******************************************/
DROP TABLE IF EXISTS #PCMM  --1031200  vs. 1027089(CDS)  select * from #PCMM where mvipersonsid = 13675760
SELECT * INTO #PCMM
FROM
(
SELECT v.MVIPersonsid
, v.PatientICN
, l.checklistid
, patientsid
, v.staffname
, TeamRole 
, team
, TeamType Teamfocus
, RelationshipstartdateTime  Relationshipstartdate 
, ROW_Number() OVER(PARTITION BY  v.patienticn, l.checklistid ORDER BY Relationshipstartdatetime   DESC) as RN
--FROM  [PDW].[VSSC_Out_DoEX_VSSCPCMMAssignments] V 
FROM [Common].[Providers]   v WITH (NOLOCK)
--LEFT JOIN [SStaff].[SStaff] AS st WITH (NOLOCK) ON v.PrimaryProviderSID = st.staffsid
LEFT JOIN [LookUp].[Sta6a] as sta WITH (NOLOCK) ON v.sta6a = sta.Sta6a
LEFT OUTER JOIN Common.MasterPatient  AS mv WITH (NOLOCK) ON v.PatientICN = mv.PatientICN
LEFT JOIN [Lookup].[ChecklistID] AS l WITH (NOLOCK) ON l.ChecklistID = sta.ChecklistID
WHERE ProvType = 'MHTC'
AND   Team like '%BHIP%'
) as a 
WHERE RN =1


/*******************************************
 Step 4: Obtain only one row per patient based on latest note date, healthfactordate per site per patient 
 streamline to actionable cases: 1) there is no MHTC in PCMM even though a note showed an MHTC assignment or 
 2) the MHTC in PCMM had a relationshp BEFORE the MHTC note, indicating it likely needs and update
*******************************************/
DROP TABLE IF EXISTS #MHTC_hp --select * from #MHTC_hp  where mvipersonsid = 13675760
select * INTO #MHTC_hp  --select * from    #MHTC_hp 
from 
(
select  h.patienticn
	, h.mvipersonsid 
	, h.patientname
	, h.LastFour
	, h.checklistid
	, h.visitsid 
	, healthfactordatetime
	, ROW_Number() OVER(PARTITION BY  h.checklistid,h.patienticn ORDER BY Note_Date DESC ) as RN
	, Note_Date
	, Note_Author 
	, Note_MHTC
	, asgn_type 
	, team 
	, TeamRole 
	, staffname
	, cast(NULLIF(relationshipstartdate,'') AS datetime) relationshipstartdate
	--, cast(NULLIF(relationshipenddate,'') AS datetime) relationshipenddate
	from #Note_HF h  --select * from #Note_HF  where mvipersonsid in (52732808, 9491448,39027577)
	Left JOIN #PCMM p on h.mvipersonsid = p.mvipersonsid and h.checklistid = p.checklistid 
where  datediff(day, Healthfactordatetime, Note_Date) >=0 
and Note_Date >= DATEADD(year, -1, GETDATE())
)as a 
where rn = 1
/*******************************************
 Step 5:obtain table with last name of PCMM MHTC (staffname)
 *******************************************/
DROP TABLE IF EXISTS #STRING --select * from #string where staffname like 'Torres%'
select checklistid   
	,patienticn
	,Note_MHTC
	,Note_Date 
	,staffname 
	,asgn_type
	--If Lastname has two words with space, select the first word
	,CASE WHEN LEN(TRIM(LastName)) - LEN(REPLACE(TRIM(LastName), ' ', '')) =1 THEN SUBSTRING(LastName,1,charindex(' ',LastName)-1)
	--If Lastname has two words with dash, select the first word
	      WHEN LEN(TRIM(LastName)) - LEN(REPLACE(TRIM(LastName), '-', '')) =1 THEN SUBSTRING(LastName,1,charindex('-',LastName)-1)
	      ELSE LastName
		  END As LastName 
INTO #STRING
FROM
(
  select checklistid   
	,patienticn
	,Note_MHTC
	,Note_Date 
	,staffname 
	,asgn_type
	,case when len(staffname)>0 then left(staffname,charindex(',',staffname)-1)  else '' end as LastName
from #MHTC_hp --select * from #string where asgn_type like 'unassign%' and (Note_MHTC not LIKE CONCAT('%', LastName, '%') or staffname is null)
) as a 
--***********
-- Step 6:Find name matching between note MHTC and PCMM staffname 
--*************
drop table if exists #matched_PCMM  --select * from #matched_PCMM  wwhere mvipersonsid in (52732808, 9491448,39027577)
Select t1.* --8634
INTO #Matched_PCMM
FROM #MHTC_hp AS t1   --select patienticn, note_MHTC, note_date, staffname, relationshipstartdate from #MHTC_HP
LEFT JOIN #string AS t2
on t1.checklistid = t2.checklistid and t1.patienticn=t2.patienticn and t1.Note_Date=t2.Note_Date and t1.staffname = t2.staffname 
where  	([Dflt].[ufn_FormatName](t1.Note_MHTC) like ('%'+[Dflt].[ufn_FormatName](t2.lastname)+'%') and t2.staffname is not null )
or (t1.asgn_type like 'unassignment' and t1.Note_MHTC is null and t1.staffname is null)

 --***********************************
-- Step 7:Remove matched records, null Note_MHTC and Null Staffname   
--**************************************

Drop table if exists #pre_actionable  -- select * from #pre_actionable where mvipersonsid in (52732808, 9491448,39027577)
select * into #pre_actionable --7951 select note_date, note_MHTC, staffname , asgn_type, relationshipstartdate from #final
from
(
select * from #MHTC_HP 
except 
select * from #matched_PCMM --select note_MHTC,staffname, terminationdate from #matched where patienticn = 1008983437
) as a

--***********
-- Step 8:Further filter the final records by finding matching names between note MHTC and PCMM_History staffname 
--*************
	-- add lastName column to PCMM History table 
DROP TABLE IF EXISTS #PCMMHistory_lastName --where patienticn = 1046295182
select checklistid   
	,patienticn 
	,staffname  
	,team
	,Provtype
	,MHTC
	,RelationshipStartDateTime
	,RelationshipEndDateTime_derived 
	--If Lastname has two words with space, select the first word
	,CASE WHEN LEN(TRIM(LastName)) - LEN(REPLACE(TRIM(LastName), ' ', '')) =1 THEN SUBSTRING(LastName,1,charindex(' ',LastName)-1)
	--If Lastname has two words with dash, select the first word
	      WHEN LEN(TRIM(LastName)) - LEN(REPLACE(TRIM(LastName), '-', '')) =1 THEN SUBSTRING(LastName,1,charindex('-',LastName)-1)
	      ELSE LastName
		  END As LastName 
INTO #PCMMHistory_LastName  --where patienticn = 1045977894
FROM
(
  select checklistid   
	,patienticn
	,staffname 
	,team
	,MHTC
	,provtype  
	,RelationshipStartDatetime
	,RelationshipEndDateTime_derived 
	,case when len(staffname)>0 then left(staffname,charindex(',',staffname)-1)  else '' end as LastName
from [Common].[ProviderTeamHistory]  
where provtype like 'MHTC'--select * from #string where asgn_type like 'unassign%' and (Note_MHTC not LIKE CONCAT('%', LastName, '%') or staffname is null)
and team like '%BHIP%'
) as a 

-- find matching historical assigned PCMM providers
drop table if exists #matched_PCMM_Historical  --8151--select * from #matched_PCMM_Historical  where patienticn = 1045977894
select * 
INTO #Matched_PCMM_Historical
from
(
Select t1.PatientICN, t1.MVIPersonSID, t1.PatientName, t1.LastFour, t1.Checklistid, t1.Note_date, Note_MHTC,t2.staffName, t1.asgn_type, 
       t2.team, t2.provtype, t2.MHTC,  t2.lastname, t2.RelationshipStartDateTime, t2.RelationshipEndDateTime_derived 
	   ,ROW_Number() OVER(PARTITION BY  t1.patienticn, t1.checklistid, t1.note_date ORDER BY relationshipstartdatetime ) as RN
  --2694 select * from #Matched_PCMM_Historical where patienticn = where provtype not like 'MHTC' or provtype is null
FROM #pre_actionable AS t1   --select * from #pre_actionable  where patienticn = 1045977894
LEFT JOIN #PCMMHistory_LastName AS t2
on t1.checklistid = t2.checklistid and t1.patienticn=t2.patienticn  
where   ([Dflt].[ufn_FormatName](t1.Note_MHTC) like ('%'+[Dflt].[ufn_FormatName](t2.lastname)+'%') and  t2.RelationshipStartDateTime >= t1.Note_Date) 
) as a 
where rn = 1
 

--***********
-- Step 9:Filter #pre-actionable table with #matched_PCMM_Historical
--*************
Drop table if exists #actionable  
select * 
into #actionable --13682  --select distinct patienticn from #actionable --434

from #pre_actionable a --select count(*) from #pre_actionable --14117
where not exists
(
select patienticn, note_date, note_MHTC from #Matched_PCMM_Historical H where a.patienticn = h.patienticn and a.note_date = h.Note_Date and a.note_mhtc = h.note_MHTC and a.checklistid = h.checklistid 
)  
 

--*******************************************************************************************************************

EXEC [Maintenance].[PublishTable] 'BHIP.MHTCAssignment','#Actionable' 
 
END