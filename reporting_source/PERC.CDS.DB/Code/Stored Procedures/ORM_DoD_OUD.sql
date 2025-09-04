/***-- =============================================
Developer(s):	Martins, Susana, William Kazanis
Create date: 12/1/2023
Object Name:	code.ORM_DoD_OUD
Output:		ORM.DoD_OUD
Requirements:
(1) Identify all OUD codes from Monthly DoD (JVPN) purchased and direct care files
(2) Include all DaVINCI DoD purchased and direct care files
(3) Imputed ben_cat for JVPN patients to ben_cat = 4 to denote active duty service in the last year

Revision Log:
Version		Date			Developer					Description
1.0         2023/12/03		Kazanis, William			Adapted code created by Susana Martins to identify OUD Diagnoses in DoD data pulls
1.01		2024/02/05		Kazanis, William			Added ICD10 with dots
1.02		2024/02/07		Kazanis, William			Built lookup table with MVIPersonSID and first and last name
1.03		2025/05/15		Kazanis, William			Added Column for Direct or Network (Community) care
-- =============================================
*/


CREATE PROCEDURE [Code].[ORM_DoD_OUD]
AS
BEGIN

/* *************************************************************************************************** */
/* Create staging tables for JVPN Inpatient and Outpient, purchased (network) and direct care datesets */
/* Select max dataset for each Person ID (EDIPI) from JVPN data pulls                                  */
/* *************************************************************************************************** */

-- Network (purchased) Inpatient
drop table if exists #jvpnNI
select * 
into #jvpnNI
from [pdw].[CDWWork_JVPN_NetworkInpat] as a WITH (NOLOCK)
inner join
	( 
		select 
			maxextractionloaddate = max(extractionloaddate) , 
			edipi = personID 
		from [pdw].[CDWWork_JVPN_NetworkInpat]  WITH (NOLOCK)
		group by personID 
	) as b
on a.ExtractionLoadDate=b.maxextractionloaddate and a.personID=b.edipi

--Network (purchased) Outpatient
drop table if exists #jvpnno
select * 
into #jvpnno
from [pdw].[CDWWork_JVPN_NetworkOutpat] as a WITH (NOLOCK)
inner join
	( 
		select 
			maxextractionloaddate = max(extractionloaddate), 
			edipi = personID 
		from [pdw].[CDWWork_JVPN_NetworkOutpat]  WITH (NOLOCK)
		group by personID
	) as b
on a.ExtractionLoadDate=b.maxextractionloaddate and a.personID=b.edipi

--Direct Outpaient
drop table if exists #jvpncap
select * 
into #jvpncap
from [pdw].[CDWWork_JVPN_CAPER] as a WITH (NOLOCK)
inner join 
	(
		select 
			maxextractionloaddate = max(extractionloaddate) , 
			edipi = personID 
		from [pdw].[CDWWork_JVPN_CAPER]  WITH (NOLOCK)
		group by personID
	) as b
on a.ExtractionLoadDate=b.maxextractionloaddate and a.personID=b.edipi

--Direct Inpatient
drop table if exists #jvpnDI
select * 
into #jvpnDI
from [pdw].[CDWWork_JVPN_DirectInpat] as a WITH (NOLOCK)
inner join 
	( 
		select 
			maxextractionloaddate = max(extractionloaddate) , 
			edipi = patientuniqueID 
		from [pdw].[CDWWork_JVPN_DirectInpat]  WITH (NOLOCK)
		group by PatientUniqueID
	) as b
on a.ExtractionLoadDate=b.maxextractionloaddate and a.PatientUniqueID=b.edipi



/* *************************************************************************************************** */
/* READ OUD VALUES FROM XLA */
/* *************************************************************************************************** */

-- OUD Value Set
DROP TABLE IF EXISTS #OUD;
SELECT  
	[SetTerm],
	[Vocabulary],
	[Value_DOT]=[Value],
	[Detail],
	[Value]=Replace([Value] ,'.','') --Removing dots from ICD10 codes to match with DoD ICD Formatting
    --,[ALEXGUID]
    --,[ValueGroup]
	--,[Exclusion]
	--,[SuperSetFlag]
INTO #OUD
FROM [xla].[Lib_SetValues_CDS] WITH (NOLOCK)
WHERE setterm LIKE 'OUD' AND Vocabulary LIKE 'ICD%';


/* *************************************************************************************************** */
/* Select all instances of OUD from each dataset */
/* *************************************************************************************************** */

DROP TABLE IF EXISTS #jvpn_oud
SELECT SOURCE
	,EDIPI = personid
	,instance_date = cast([BeginDateOfCare] as datetime2(0))
	,InstanceDateType
	,NetworkInpatSID as RecordID
	,IDTYPE
	,ICD10
	,ICD10_dot
	,ben_cat  --Imputed to 4 for JVPN patients to denote Active Duty in the past year
	,ActiveDuty_PurchasedCare_Flag = CASE When ([SOURCE] like '%Network%')  Then 1 ELSE 0 END
INTO #jvpn_oud
FROM 
(

--Purchased (Network) Inpatient Care
SELECT SOURCE='[PDW].[CDWWork_JVPN_NetworkInpat]',NetworkInpatSID,IDTYPE='NetworkInpatSID',  personid, BeginDateOfCare,InstanceDateType = 'BeginDateOfCare',primarydiagnosis as ICD10, Value_DOT as ICD10_dot,  4 as ben_cat FROM #jvpnNI a INNER JOIN #OUD b on a.primarydiagnosis=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_NetworkInpat]',NetworkInpatSID,IDTYPE='NetworkInpatSID',  personid, BeginDateOfCare,InstanceDateType = 'BeginDateOfCare',secdiagnosis2 as ICD10, Value_DOT as ICD10_dot, 4 as ben_cat FROM #jvpnNI a INNER JOIN #OUD b on a.secdiagnosis2=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_NetworkInpat]',NetworkInpatSID,IDTYPE='NetworkInpatSID',  personid, BeginDateOfCare,InstanceDateType = 'BeginDateOfCare',secdiagnosis3 as ICD10, Value_DOT as ICD10_dot, 4 as ben_cat FROM #jvpnNI a INNER JOIN #OUD b on a.secdiagnosis3=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_NetworkInpat]',NetworkInpatSID,IDTYPE='NetworkInpatSID',  personid, BeginDateOfCare,InstanceDateType = 'BeginDateOfCare',secdiagnosis4, Value_DOT as ICD10_dot, 4 as ben_cat FROM #jvpnNI a INNER JOIN #OUD b on a.secdiagnosis4=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_NetworkInpat]',NetworkInpatSID,IDTYPE='NetworkInpatSID',  personid, BeginDateOfCare,InstanceDateType = 'BeginDateOfCare',secdiagnosis5, Value_DOT as ICD10_dot, 4 as ben_cat FROM #jvpnNI a INNER JOIN #OUD b on a.secdiagnosis5=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_NetworkInpat]',NetworkInpatSID,IDTYPE='NetworkInpatSID',  personid, BeginDateOfCare,InstanceDateType = 'BeginDateOfCare',secdiagnosis6, Value_DOT as ICD10_dot, 4 as ben_cat FROM #jvpnNI a INNER JOIN #OUD b on a.secdiagnosis6=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_NetworkInpat]',NetworkInpatSID,IDTYPE='NetworkInpatSID', personid, BeginDateOfCare,InstanceDateType = 'BeginDateOfCare',secdiagnosis7, Value_DOT as ICD10_dot, 4 as ben_cat FROM #jvpnNI a INNER JOIN #OUD b on a.secdiagnosis7=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_NetworkInpat]',NetworkInpatSID,IDTYPE='NetworkInpatSID',  personid, BeginDateOfCare,InstanceDateType = 'BeginDateOfCare',secdiagnosis8, Value_DOT as ICD10_dot, 4 as ben_cat FROM #jvpnNI a INNER JOIN #OUD b on a.secdiagnosis8=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_NetworkInpat]',NetworkInpatSID,IDTYPE='NetworkInpatSID',  personid, BeginDateOfCare,InstanceDateType = 'BeginDateOfCare',secdiagnosis8, Value_DOT as ICD10_dot, 4 as ben_cat FROM #jvpnNI a INNER JOIN #OUD b on a.secdiagnosis9=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_NetworkInpat]',NetworkInpatSID,IDTYPE='NetworkInpatSID', personid, BeginDateOfCare,InstanceDateType = 'BeginDateOfCare',secdiagnosis8, Value_DOT as ICD10_dot, 4 as ben_cat FROM #jvpnNI a INNER JOIN #OUD b on a.secdiagnosis10=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_NetworkInpat]',NetworkInpatSID,IDTYPE='NetworkInpatSID',  personid, BeginDateOfCare,InstanceDateType = 'BeginDateOfCare',secdiagnosis8, Value_DOT as ICD10_dot, 4 as ben_cat FROM #jvpnNI a INNER JOIN #OUD b on a.secdiagnosis11=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_NetworkInpat]',NetworkInpatSID,IDTYPE='NetworkInpatSID',  personid, BeginDateOfCare,InstanceDateType = 'BeginDateOfCare',secdiagnosis8, Value_DOT as ICD10_dot, 4 as ben_cat FROM #jvpnNI a INNER JOIN #OUD b on a.secdiagnosis12=b.Value 
UNION

--Purchased (Network) Oupatient Care
SELECT SOURCE='[PDW].[CDWWork_JVPN_NetworkOutpat]',NetworkOutpatSID,IDTYPE='NetworkOutpatSID',  personid,begindateofcare,InstanceDateType = 'BeginDateOfCare',primarydiagnosis, Value_DOT as ICD10_dot, 4 as ben_cat FROM #jvpnno a INNER JOIN #OUD b on a.primarydiagnosis=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_NetworkOutpat]',NetworkOutpatSID,IDTYPE='NetworkOutpatSID',  personid,begindateofcare,InstanceDateType = 'BeginDateOfCare',secdiagnosis1, Value_DOT as ICD10_dot, 4 as ben_cat FROM #jvpnno a INNER JOIN #OUD b on a.secdiagnosis1=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_NetworkOutpat]',NetworkOutpatSID,IDTYPE='NetworkOutpatSID',  personid,begindateofcare,InstanceDateType = 'BeginDateOfCare',secdiagnosis2, Value_DOT as ICD10_dot, 4 as ben_cat FROM #jvpnno a INNER JOIN #OUD b on a.secdiagnosis2=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_NetworkOutpat]',NetworkOutpatSID,IDTYPE='NetworkOutpatSID',  personid,begindateofcare,InstanceDateType = 'BeginDateOfCare',secdiagnosis3, Value_DOT as ICD10_dot, 4 as ben_cat FROM #jvpnno a INNER JOIN #OUD b on a.secdiagnosis3=b.Value 
UNION
SELECT  SOURCE='[PDW].[CDWWork_JVPN_NetworkOutpat]',NetworkOutpatSID,IDTYPE='NetworkOutpatSID', personid,begindateofcare,InstanceDateType = 'BeginDateOfCare',secdiagnosis4, Value_DOT as ICD10_dot, 4 as ben_cat FROM #jvpnno a INNER JOIN #OUD b on a.secdiagnosis4=b.Value 
UNION
--Direct Oupatient Care
SELECT SOURCE='[PDW].[CDWWork_JVPN_CAPER]',CaperSID,IDTYPE='CaperSID',  personid, ServiceDate,InstanceDateType = 'ServiceDate',[Diag1], Value_DOT as ICD10_dot, 4 as bencatcom FROM #jvpncap a INNER JOIN #OUD b on a.[Diag1]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_CAPER]',CaperSID,IDTYPE='CaperSID', personid, ServiceDate,InstanceDateType = 'ServiceDate',[Diag2], Value_DOT as ICD10_dot, 4 as bencatcom FROM #jvpncap a INNER JOIN #OUD b on a.[Diag2]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_CAPER]',CaperSID,IDTYPE='CaperSID', personid, ServiceDate,InstanceDateType = 'ServiceDate',[Diag3], Value_DOT as ICD10_dot, 4 as bencatcom FROM #jvpncap a INNER JOIN #OUD b on a.[Diag3]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_CAPER]',CaperSID,IDTYPE='CaperSID', personid, ServiceDate,InstanceDateType = 'ServiceDate',[Diag4], Value_DOT as ICD10_dot, 4 as bencatcom FROM #jvpncap a INNER JOIN #OUD b on a.[Diag4]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_CAPER]',CaperSID,IDTYPE='CaperSID', personid, ServiceDate,InstanceDateType = 'ServiceDate',[Diag5], Value_DOT as ICD10_dot, 4 as bencatcom FROM #jvpncap a INNER JOIN #OUD b on a.[Diag5]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_CAPER]',CaperSID,IDTYPE='CaperSID', personid, ServiceDate,InstanceDateType = 'ServiceDate',[Diag6], Value_DOT as ICD10_dot, 4 as bencatcom FROM #jvpncap a INNER JOIN #OUD b on a.[Diag6]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_CAPER]',CaperSID,IDTYPE='CaperSID', personid, ServiceDate,InstanceDateType = 'ServiceDate',[Diag7], Value_DOT as ICD10_dot, 4 as bencatcom FROM #jvpncap a INNER JOIN #OUD b on a.[Diag7]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_CAPER]',CaperSID,IDTYPE='CaperSID', personid, ServiceDate,InstanceDateType = 'ServiceDate',[Diag8], Value_DOT as ICD10_dot, 4 as bencatcom FROM #jvpncap a INNER JOIN #OUD b on a.[Diag8]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_CAPER]',CaperSID,IDTYPE='CaperSID', personid, ServiceDate,InstanceDateType = 'ServiceDate',[Diag9], Value_DOT as ICD10_dot, 4 as bencatcom FROM #jvpncap a INNER JOIN #OUD b on a.[Diag9]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_CAPER]',CaperSID,IDTYPE='CaperSID', personid, ServiceDate,InstanceDateType = 'ServiceDate',[Diag10], Value_DOT as ICD10_dot, 4 as bencatcom FROM #jvpncap a INNER JOIN #OUD b on a.[Diag10]=b.Value 
UNION
--Direct Inpatient Care
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]', DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis1], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis1]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis2], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis2]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis3], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis3]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis4], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis4]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis5], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis5]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis6], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis6]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis7], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis7]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis8], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis8]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis9], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis9]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis10], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis10]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis11], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis11]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis12], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis12]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis13], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis13]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis14], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis14]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis15], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis15]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis16], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis16]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis17], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis17]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis18], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis18]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis19], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis19]=b.Value 
UNION
SELECT SOURCE='[PDW].[CDWWork_JVPN_DirectInpat]',DirectInpatSID,IDTYPE='DirectInpatSID', PatientUniqueID, ServiceDate,InstanceDateType = 'ServiceDate',[Diagnosis20], Value_DOT as ICD10_dot, 4 as ben_cat_common FROM #jvpnDI a INNER JOIN #OUD b on a.[Diagnosis20]=b.Value 
)a 


--select count(*) as dxs, count(distinct edipi) as pats from #jvpn_oud
--select count(*),extractionloaddate from [Dflt].[RB03_JVPN_RX_A06] group by extractionloaddate order by ExtractionLoadDate

/* *************************************************************************************************** */
/* Temporary end point for OUD from JVPN while we await DaVINCI migration */
/* *************************************************************************************************** */

drop table if exists #jvpnDI
drop table if exists #jvpncap
drop table if exists #jvpnno
drop table if exists #jvpnni




/* *************************************************************************************************** */
/* *************************************************************************************************** 
	Building a EDIPI to MVIPERSONSID lookup table with columns for first and last name
   *************************************************************************************************** */
/* *************************************************************************************************** */

/* Testing for the number of distinct edipi in #jvpn_oud
select count(*) as rows_entry, count(distinct edipi) as pats from #jvpn_oud
*/
DROP TABLE IF EXISTS #MVINAME
SELECT DISTINCT
	dod.EDIPI,
	COALESCE(mp.MVIPersonSID,sv.MVIPersonSID,0) as MVIPersonSID, --VA patient identifier of choice (PatientICN, MVIPersonSID,etc)
	COALESCE(mp.LastName, sv.lastname,reg.lastname) as LastName,
	COALESCE(mp.FirstName, sv.Firstname, reg.Firstname) as FirstName,
	COALESCE(mp.MiddleName, sv.Middlename) as MiddleName,
	COALESCE(mp.namesuffix, sv.namesuffix) as NameSuffix,
	COALESCE(
		CAST(mp.DateOfBirth as date),
		CAST(sv.birthdatetime as date),
		CAST(reg.dob as date)
		) as DateofBirth,
	COALESCE(mp.age,
		DATEDIFF(year,cast(sv.birthdatetime as date),getdate()), 
		DATEDIFF(year,cast(reg.dob as date),getdate())
		) as age,  --only one table has age, the rest have age computed
	COALESCE(mp.Gender,sv.gender,reg.gender) as Gender
INTO #MVINAME
FROM #jvpn_oud as dod--the DoD dataset
LEFT JOIN [Common].[MasterPatient] mp WITH(NOLOCK) ON dod.edipi = mp.edipi 
LEFT JOIN [SVeteran].[SMVIPersonSiteAssociation] sv WITH(NOLOCK) ON dod.EDIPI = sv.EDIPI  --try EDIPN join (most of the matches come from here)
LEFT JOIN [PDW].[CDWWork_JVPN_VARegistry] reg WITH(NOLOCK) ON dod.EDIPI = reg.edipn


--Build staging table (temporary until DaVINCI transfer)
DROP TABLE IF EXISTS #stage
SELECT
	jvpn.[SOURCE] 
	,mvi.[MVIPersonSID]
	,jvpn.[EDIPI] 
	,mvi.[LastName]
	,mvi.[FirstName]
	,mvi.[MiddleName] 
	,mvi.[NameSuffix] 
	,mvi.[DateofBirth] 
	,mvi.[age] 
	,mvi.[Gender] 
	,jvpn.[instance_date] 
	,jvpn.[InstanceDateType] 
	,jvpn.[RecordID] 
	,jvpn.[IDTYPE] 
	,jvpn.[ICD10] 
	,jvpn.[ICD10_dot]
	,jvpn.[ben_cat] 
	,jvpn.[ActiveDuty_PurchasedCare_Flag] 
	,enc.MaxDoDEncounter
	, CASE WHEN source LIKE '%CDWWork_JVPN_NetworkInpat%' OR source LIKE '%CDWWork_JVPN_NetworkOutpat%' THEN 'NETWORK OR COMMUNITY CARE'
		WHEN source like '%CDWWork_JVPN_CAPER%' OR SOURCE LIKE '%CDWWork_JVPN_DirectInpat%' THEN 'DIRECT CARE'  END as CareType
INTO #stage 
FROM #jvpn_oud AS jvpn
LEFT JOIN #MVINAME AS mvi
ON jvpn.EDIPI=mvi.edipi
left join ORM.DoD_Max_Encounter_Date AS enc WITH (NOLOCK)
ON jvpn.edipi=enc.edipi

/*
--drop table if exists [ORM].[dod_oud];

CREATE TABLE [ORM].[dod_oud](
	[SOURCE] [varchar](34) NOT NULL,
	[MVIPersonSID] [int] NULL,
	[EDIPI] [varchar](50) NULL,
	[LastName] [varchar](50) NULL,
	[FirstName] [varchar](50) NULL,
	[MiddleName] [varchar](50) NULL,
	[NameSuffix] [varchar](50) NULL,
	[DateofBirth] [date] NULL,
	[age] [int] NULL,
	[Gender] [varchar](50) NULL,
	[instance_date] [datetime2](0) NULL,
	[InstanceDateType] [varchar](15) NOT NULL,
	[RecordID] [int] NOT NULL,
	[IDTYPE] [varchar](16) NOT NULL,
	[ICD10] [varchar](50) NULL,
	[ICD10_dot] [varchar](200) NOT NULL,
	[ben_cat] [int] NOT NULL,
	[ActiveDuty_PurchasedCare_Flag] [int] NOT NULL,
	[MaxDoDEncounter] [date] NULL,
	[CareType] [varchar](50) NULL
) ON [DefFG]
*/


drop table if exists #jvpn_oud
DROP TABLE IF EXISTS #MVINAME

--Select * into ORM.DoD_OUD from #stage
EXEC [Maintenance].[PublishTable] 'ORM.DoD_OUD','#stage'


/* -- REMOVE TO ADD DAVINCI


/* *************************************************************************************************** */
/* READ INSTANCES FROM DaVINCI  */
/* *************************************************************************************************** */



DROP TABLE IF EXISTS #davinci_OUD
SELECT SOURCE
, EDIPI
,[Date]=admission_date
,ICD10=primary_diagnosis
,ben_cat
,ActiveDuty_PurchasedCare_Flag= CASE When [SOURCE] like '%TED%' and ben_cat=4 Then 1 ELSE 0 END
INTO #davinci_OUD
FROM 
(
SELECT SOURCE='[DOD].[TEDI]',  EDIPI, admission_date,primary_diagnosis,ben_cat FROM [DaVINCI].[DOD].[TEDI] a INNER JOIN #OUD b on a.primary_diagnosis=b.Value 
UNION
SELECT SOURCE='[DOD].[TEDI]',  EDIPI,admission_date,sec_diagnosis1,ben_cat FROM [DaVINCI].[DOD].[TEDI] a INNER JOIN #OUD b on a.sec_diagnosis1=b.Value 
UNION
SELECT SOURCE='[DOD].[TEDI]',  EDIPI,admission_date,sec_diagnosis2,ben_cat FROM [DaVINCI].[DOD].[TEDI] a INNER JOIN #OUD b on a.sec_diagnosis2=b.Value 
UNION
SELECT SOURCE='[DOD].[TEDI]',  EDIPI,admission_date,sec_diagnosis3,ben_cat FROM [DaVINCI].[DOD].[TEDI] a INNER JOIN #OUD b on a.sec_diagnosis3=b.Value 
UNION
SELECT SOURCE='[DOD].[TEDI]',  EDIPI,admission_date,sec_diagnosis4,ben_cat FROM [DaVINCI].[DOD].[TEDI] a INNER JOIN #OUD b on a.sec_diagnosis4=b.Value 
UNION
SELECT SOURCE='[DOD].[TEDI]',  EDIPI,admission_date,sec_diagnosis5,ben_cat FROM [DaVINCI].[DOD].[TEDI] a INNER JOIN #OUD b on a.sec_diagnosis5=b.Value 
UNION
SELECT SOURCE='[DOD].[TEDI]',  EDIPI,admission_date,sec_diagnosis6,ben_cat FROM [DaVINCI].[DOD].[TEDI] a INNER JOIN #OUD b on a.sec_diagnosis6=b.Value 
UNION
SELECT  SOURCE='[DOD].[TEDI]', EDIPI,admission_date,sec_diagnosis7,ben_cat FROM [DaVINCI].[DOD].[TEDI] a INNER JOIN #OUD b on a.sec_diagnosis7=b.Value 
UNION
SELECT SOURCE='[DOD].[TEDI]',  EDIPI,admission_date,sec_diagnosis8,ben_cat FROM [DaVINCI].[DOD].[TEDI] a INNER JOIN #OUD b on a.sec_diagnosis8=b.Value 
UNION
SELECT  SOURCE='[DOD].[TEDNI]',  EDIPI, begin_date_of_care,primary_diagnosis,ben_cat FROM [DaVINCI].[DOD].[TEDNI] a INNER JOIN #OUD b on a.primary_diagnosis=b.Value 
UNION
SELECT SOURCE='[DOD].[TEDNI]',  EDIPI,begin_date_of_care,sec_diagnosis1,ben_cat FROM [DaVINCI].[DOD].[TEDNI] a INNER JOIN #OUD b on a.sec_diagnosis1=b.Value 
UNION
SELECT SOURCE='[DOD].[TEDNI]',  EDIPI,begin_date_of_care,sec_diagnosis2,ben_cat FROM [DaVINCI].[DOD].[TEDNI] a INNER JOIN #OUD b on a.sec_diagnosis2=b.Value 
UNION
SELECT SOURCE='[DOD].[TEDNI]',  EDIPI,begin_date_of_care,sec_diagnosis3,ben_cat FROM [DaVINCI].[DOD].[TEDNI] a INNER JOIN #OUD b on a.sec_diagnosis3=b.Value 
UNION
SELECT  SOURCE='[DOD].[TEDNI]', EDIPI,begin_date_of_care,sec_diagnosis4,ben_cat FROM [DaVINCI].[DOD].[TEDNI] a INNER JOIN #OUD b on a.sec_diagnosis4=b.Value 
UNION
SELECT SOURCE='[DOD].[CAPER]',  EDIPI, ServiceDate,[Diag1],bencatcom FROM [DaVINCI].[DOD].[CAPER] a INNER JOIN #OUD b on a.[Diag1]=b.Value 
UNION
SELECT SOURCE='[DOD].[CAPER]', EDIPI, ServiceDate,[Diag2],bencatcom FROM [DaVINCI].[DOD].[CAPER] a INNER JOIN #OUD b on a.[Diag2]=b.Value 
UNION
SELECT SOURCE='[DOD].[CAPER]', EDIPI, ServiceDate,[Diag3],bencatcom FROM [DaVINCI].[DOD].[CAPER] a INNER JOIN #OUD b on a.[Diag3]=b.Value 
UNION
SELECT SOURCE='[DOD].[CAPER]',  EDIPI, ServiceDate,[Diag4],bencatcom FROM [DaVINCI].[DOD].[CAPER] a INNER JOIN #OUD b on a.[Diag4]=b.Value 
UNION
SELECT SOURCE='[DOD].[CAPER]', EDIPI, ServiceDate,[Diag5],bencatcom FROM [DaVINCI].[DOD].[CAPER] a INNER JOIN #OUD b on a.[Diag5]=b.Value 
UNION
SELECT SOURCE='[DOD].[CAPER]', EDIPI, ServiceDate,[Diag6],bencatcom FROM [DaVINCI].[DOD].[CAPER] a INNER JOIN #OUD b on a.[Diag6]=b.Value 
UNION
SELECT SOURCE='[DOD].[CAPER]', EDIPI, ServiceDate,[Diag7],bencatcom FROM [DaVINCI].[DOD].[CAPER] a INNER JOIN #OUD b on a.[Diag7]=b.Value 
UNION
SELECT SOURCE='[DOD].[CAPER]', EDIPI, ServiceDate,[Diag8],bencatcom FROM [DaVINCI].[DOD].[CAPER] a INNER JOIN #OUD b on a.[Diag8]=b.Value 
UNION
SELECT SOURCE='[DOD].[CAPER]', EDIPI, ServiceDate,[Diag9],bencatcom FROM [DaVINCI].[DOD].[CAPER] a INNER JOIN #OUD b on a.[Diag9]=b.Value 
UNION
SELECT SOURCE='[DOD].[CAPER]', EDIPI, ServiceDate,[Diag10],bencatcom FROM [DaVINCI].[DOD].[CAPER] a INNER JOIN #OUD b on a.[Diag10]=b.Value 
UNION
SELECT SOURCE='[DOD].[SIDR]', EDIPI, admission,[Diagnosis_1],ben_cat_common FROM [DaVINCI].[DOD].[SIDR] a INNER JOIN #OUD b on a.[Diagnosis_1]=b.Value 
UNION
SELECT SOURCE='[DOD].[SIDR]', EDIPI, admission,[Diagnosis_2],ben_cat_common FROM [DaVINCI].[DOD].[SIDR] a INNER JOIN #OUD b on a.[Diagnosis_2]=b.Value 
UNION
SELECT SOURCE='[DOD].[SIDR]', EDIPI, admission,[Diagnosis_3],ben_cat_common FROM [DaVINCI].[DOD].[SIDR] a INNER JOIN #OUD b on a.[Diagnosis_3]=b.Value 
UNION
SELECT SOURCE='[DOD].[SIDR]', EDIPI, admission,[Diagnosis_4],ben_cat_common FROM [DaVINCI].[DOD].[SIDR] a INNER JOIN #OUD b on a.[Diagnosis_4]=b.Value 
UNION
SELECT SOURCE='[DOD].[SIDR]', EDIPI, admission,[Diagnosis_5],ben_cat_common FROM [DaVINCI].[DOD].[SIDR] a INNER JOIN #OUD b on a.[Diagnosis_5]=b.Value 
UNION
SELECT SOURCE='[DOD].[SIDR]', EDIPI, admission,[Diagnosis_6],ben_cat_common FROM [DaVINCI].[DOD].[SIDR] a INNER JOIN #OUD b on a.[Diagnosis_6]=b.Value 
UNION
SELECT SOURCE='[DOD].[SIDR]', EDIPI, admission,[Diagnosis_7],ben_cat_common FROM [DaVINCI].[DOD].[SIDR] a INNER JOIN #OUD b on a.[Diagnosis_7]=b.Value 
UNION
SELECT SOURCE='[DOD].[SIDR]', EDIPI, admission,[Diagnosis_8],ben_cat_common FROM [DaVINCI].[DOD].[SIDR] a INNER JOIN #OUD b on a.[Diagnosis_8]=b.Value 
)a 

/* *************************************************************************************************** */
/* MERGE all instances of OUD from JVPN and DaVINCI */
/* *************************************************************************************************** */

drop table if exists #DoD_OUD_All
select * into #DoD_OUD_All from (
select * from #jvpn_oud where admission_date > (select dateadd(day,-1,max([date])) from #davinci_OUD) --All JVPN From the last FULL day in DaVINCI forward
union all
select * from #davinci_OUD where date <= (select dateadd(day,-1,max([date])) from #davinci_OUD) --All DaVINCI data from the last FULL day in DaVINCI backward
union all
select * from #davinci_OUD where EDIPI not in (select edipi from #jvpn_oud) and Date > (select dateadd(day,-1,max([date])) from #davinci_OUD) --All DaVINCI for pats not in JVPN after the last full day
) as a

/* *************************************************************************************************** */
/* Create full table of OUD from JVPN and DaVINCI */
/* *************************************************************************************************** */

Select * into ORD.DoD_OUD from #DoD_OUD_All

/*
select 
	SOURCE
	,ben_cat
	,ActiveDuty_PurchasedCare_Flag
	,ICD10
	--,admission_date
	, count(*) as ents
	, count(distinct edipi) as pats
from 
	#DoD_OUD_All
group by 
	SOURCE
	,ben_cat
	,ActiveDuty_PurchasedCare_Flag
	,ICD10
	--,admission_date
order by 
	SOURCE
	,ben_cat
	,ActiveDuty_PurchasedCare_Flag
	,ICD10
	--,admission_date
*/
*/ -- REMOVE TO ADD DAVINCI
--select count(*) as entries, count(distinct edipi) as pats from #DoD_OUD_All


END