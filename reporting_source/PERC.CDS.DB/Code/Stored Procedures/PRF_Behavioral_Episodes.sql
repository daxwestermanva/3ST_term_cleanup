/********************************************************************************************************************
DESCRIPTION: Get unique and continuous episodes of Behavioral PRFs
TEST:
	[EXEC Code.PRF_Behavioral_Episodes]
UPDATE:

********************************************************************************************************************/
CREATE PROCEDURE [Code].[PRF_Behavioral_Episodes] 
AS
BEGIN

--GETTING FLAG EPISODES (activated and reactivated with corresponding inactivation date)

		--There are records where it appears that 2 facilities have overlapping flags
		----Choosing to ignore this in partition in order to have non-overlapping records at the patient level.  Latest action affected was '2016-01-19' 

--Pull all dates from history and mark whether the record was changing from active to inactive or the opposite
DROP TABLE IF EXISTS #alldates
SELECT MVIPersonSID,OwnerChecklistID,OwnerFacility,ActiveFlag,InitialActivation,ActionDateTime,ActionType,HistoricStatus,PrevStatus
	  ,RecordType=CASE WHEN PrevStatus='N' AND HistoricStatus='Y' THEN 'BEGIN'
						WHEN PrevStatus='Y' AND HistoricStatus='N' THEN 'END' END
INTO #alldates
FROM (
	SELECT MVIPersonSID,OwnerChecklistID,OwnerFacility,ActiveFlag,InitialActivation,ActionDateTime,ActionType,HistoricStatus
		  ,EntryCountDesc
		  ,PrevStatus=ISNULL(LAG(HistoricStatus,1) OVER(PARTITION BY MVIPersonSID ORDER BY EntryCountAsc),'N')
	FROM [PRF].[BehavioralMissingPatient] WITH (NOLOCK)
	WHERE NationalPatientRecordFlag='BEHAVIORAL'
	) a
WHERE HistoricStatus<>PrevStatus --only when there was a status change
	----decided to use status change instead of actiontype to account for times when continued is first entry and other nuances

--Add end dates from relevent records and only keep rows with correct begin and end dates
DROP TABLE IF EXISTS #beginend
SELECT MVIPersonSID
	  ,OwnerChecklistID
	  ,InitialActivation
	  ,EpisodeBeginDateTime=ActionDateTime
	  ,ActiveFlag
	  ,EpisodeEndDateTime=CASE WHEN RecordType='BEGIN' THEN LEAD(ActionDateTime,1) OVER(PARTITION BY MVIPersonSID ORDER BY ActionDateTime) END
	  ,EndChecklistID=CASE WHEN RecordType='BEGIN' THEN LEAD(OwnerChecklistID,1) OVER(PARTITION BY MVIPersonSID ORDER BY ActionDateTime) END
	  ,RecordType
INTO #beginend
FROM #alldates

DELETE #beginend WHERE RecordType ='END'

--Compute days in episode
DROP TABLE IF EXISTS #Episodes
SELECT MVIPersonSID
	  ,OwnerChecklistID=ISNULL(EndChecklistID,OwnerChecklistID) --if they are different (rare), the inactivating station will be listed
	  ,ActiveFlag
	  ,InitialActivation
	  ,EpisodeBeginDateTime
	  ,EpisodeEndDateTime
	  ,ActiveDays=CASE 
			WHEN EpisodeEndDateTime IS NULL THEN DateDiff(dd,EpisodeBeginDateTime,DATEADD(dd,1,GetDate())) 
			ELSE DateDiff(dd,EpisodeBeginDateTime,EpisodeEndDateTime)  END  
	  ,FlagEpisode=Dense_Rank() OVER(Partition By MVIPersonSID ORDER BY ISNULL(EpisodeEndDateTime,GETDATE())) 
INTO #Episodes
FROM #beginend

DROP TABLE IF EXISTS #AddTotalEpisodes;
SELECT MVIPersonSID
	  ,OwnerChecklistID
	  ,InitialActivation
	  ,FlagEpisode
	  ,TotalEpisodes=MAX(FlagEpisode) OVER(Partition By MVIPersonSID)
	  ,EpisodeBeginDateTime
	  ,EpisodeEndDateTime
	  ,ActiveDays
	  ,CurrentActiveFlag=MAX(CASE WHEN ActiveFlag='Y' THEN 1 ELSE 0 END) OVER(Partition By MVIPersonSID)
INTO #AddTotalEpisodes
FROM #Episodes

--Set end date to date of death, where appropriate
DROP TABLE IF EXISTS #WithDeceasedDate;
SELECT f.MVIPersonSID
	  ,f.OwnerChecklistID
	  ,f.InitialActivation
	  ,f.FlagEpisode
	  ,f.TotalEpisodes
	  ,f.EpisodeBeginDateTime
	  ,EpisodeEndDateTime=ISNULL(f.EpisodeEndDateTime,p.DateOfDeath)
	  ,ActiveDays=CASE 
		WHEN f.EpisodeEndDateTime IS NULL AND p.DateofDeath IS NOT NULL THEN DateDiff(dd,EpisodeBeginDateTime,DateOfDeath) 
		ELSE f.ActiveDays END 
	  ,f.CurrentActiveFlag
INTO #WithDeceasedDate
FROM #AddTotalEpisodes f
INNER JOIN [Common].[MasterPatient] p WITH (NOLOCK) on p.MVIPersonSID=f.MVIPersonSID

DROP TABLE IF EXISTS #StageEpisodes;
SELECT MVIPersonSID
	  ,OwnerChecklistID
	  ,InitialActivation
	  ,TotalEpisodes
	  ,FlagEpisode
	  ,EpisodeBeginDateTime
	  ,EpisodeEndDateTime
	  ,ActiveDays
	  ,PreviousInactiveDays=DATEDIFF(DAY,LAG(EpisodeEndDateTime,1) OVER(PARTITION BY MVIPersonSID ORDER BY FlagEpisode),EpisodeBeginDateTime)
	  ,CurrentActiveFlag
INTO #StageEpisodes
FROM #WithDeceasedDate
ORDER BY MVIPersonSID,FlagEpisode

EXEC [Maintenance].[PublishTable] 'PRF.Behavioral_EpisodeDates','#StageEpisodes'

END --END OF PROCEDURE