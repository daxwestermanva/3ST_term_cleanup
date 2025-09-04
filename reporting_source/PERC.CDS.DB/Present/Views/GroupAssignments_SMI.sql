


CREATE VIEW [Present].[GroupAssignments_SMI] as 

SELECT [PatientICN]
	  ,MVIPersonSID
	  ,GroupID
      ,[GroupType]
      ,[ProviderSID]
      ,[ProviderName]
      ,[ChecklistID]
      ,Sta3n
	  ,VISN
  FROM [Present].[GroupAssignments]
  WHERE GroupID IN (2,3,4,5)

  UNION

  SELECT [PatientICN]
	  ,MVIPersonSID
	  ,GroupID
      ,[GroupType]
      ,[ProviderSID]
      ,[ProviderName]
      ,[ChecklistID]
      ,Sta3n
	  ,VISN
  FROM SMI.MHProviders