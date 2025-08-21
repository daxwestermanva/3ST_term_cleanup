


CREATE VIEW [Present].[GroupAssignments_PDSI] as 

SELECT [PatientICN]
	  ,MVIPersonSID
	  ,CASE WHEN GroupID=9 THEN 1 ELSE GroupID END as GroupID
      ,[GroupType]
      ,[ProviderSID]
      ,[ProviderName]
      ,[ChecklistID]
      ,Sta3n
	  ,VISN
  FROM [Present].[GroupAssignments]
  WHERE GroupID IN (2,3,4,5,6,7,9)