-- =============================================
-- Author: Robin Kinnard
-- Create date: 9/6/24
-- Description: Category II Patient Record Flag Counts
-- Modifications:
-- =============================================
/*  Testing:
	EXEC [App].[LocalPatientRecordFlag]
	@StaffLastName='tramm'
*/

CREATE PROCEDURE [App].[PRF_CatII_Counts] 

	@checklistid VARCHAR(1000)
	,@flag varchar(max)

AS
BEGIN	

DECLARE @FlagList TABLE ([LocalPatientRecordFlag] VARCHAR(max))

INSERT @FlagList  SELECT value FROM string_split(@flag, ',')

DECLARE @facilitylist TABLE ([checklistid] VARCHAR(max))

INSERT @facilitylist  SELECT value FROM string_split(@checklistid, ',')

select 
[VISN]
,[Facility]
,act.[Sta3n]
,flag.[LocalPatientRecordFlag]
,[LocalPatientRecordFlagDescription]
,[Count]
,cid.[checklistid]

from [PRF].[ActiveCatII_Counts] as act
inner join [Lookup].[ChecklistID] as cid on (act.OwnerChecklistID = cid.ChecklistID)

inner join @FlagList as flag on flag.[LocalPatientRecordFlag] = act.LocalPatientRecordFlag 

inner join @facilitylist as fac on act.OwnerChecklistID = fac.checklistid

end 


/*
select 
[VISN]
,[Facility]
,act.[Sta3n]
,[LocalPatientRecordFlag]
,[LocalPatientRecordFlagDescription]
,[Count]

from [PRF].[ActiveCatII_Counts] as act
inner join [Lookup].[ChecklistID] as cid on (act.Sta3n = cid.STA3N)
where visn=1 and act.sta3n=518


VISN
Facility
Local Patient Record Flag
Local Patient Record Flag Description
Count of patients
*/