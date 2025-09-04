/***-- =============================================
Developer(s):	Kazanis, William
Create date: 2/20/2024
Object Name:	code.ORM_DoD_Max_Encounter_Date
Output:		ORM.DoD_Max_Encounter_Date
Requirements:
(1) Identify max encounter date from Monthly DoD (JVPN) purchased and direct care files
(2) Include all DaVINCI DoD purchased and direct care files in determining the max encounter date

Revision Log:
Version		Date			Developer					Description
1.0         2024/2/20		Kazanis, William			Adapted code created by Susana Martins to identify OUD Diagnoses in DoD data pulls

-- =============================================
*/


CREATE PROCEDURE [Code].[ORM_DoD_Max_Encounter_Date]
AS
BEGIN

drop table if exists #stage
select edipi, max(cast(maxenddateofcare as date)) as MaxDoDEncounter 
into #stage
from
(
--Network (purchased) Inpatient  --Selecting end date of care whenever available
		select 
			maxenddateofcare = enddateofcare , 
			edipi = personID 
		from [pdw].[CDWWork_JVPN_NetworkInpat] 


Union all
--Network (purchased) Outpatient --Selecting end date of care whenever available
		select 
			maxEnddateofCare = EnddateofCare, 
			edipi = personID 
		from [pdw].[CDWWork_JVPN_NetworkOutpat] 


Union all
--Direct Outpaient
		select 
			maxservicedate = servicedate , 
			edipi = personID 
		from [pdw].[CDWWork_JVPN_CAPER] 


Union All
--Direct Inpatient
		select 
			maxservicedate = servicedate , 
			edipi = patientuniqueID 
		from [pdw].[CDWWork_JVPN_DirectInpat] 

) as d
group by edipi


/*
--drop table if exists [ORM].[DoD_Max_Encounter_Date]

CREATE TABLE [ORM].[DoD_Max_Encounter_Date](
	[edipi] [varchar](50) NULL,
	MaxDoDEncounter  [date] NULL
) ON [DefFG]
*/
EXEC [Maintenance].[PublishTable] 'ORM.DoD_Max_Encounter_Date','#stage'
drop table if exists #stage;

END