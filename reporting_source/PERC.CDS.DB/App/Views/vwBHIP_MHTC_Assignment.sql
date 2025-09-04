










CREATE VIEW [App].[vwBHIP_MHTC_Assignment] 
AS   
 ----------------------------------------------------------------------------------------------*/
SELECT distinct VISN, substring([ADMPARENT_FCDM], 7, 100) station
      ,[PatientName]
      ,[LastFour]
      ,[PatientICN]
      ,[MVIPersonSID]
      ,m.[checklistid]
      ,[visitsid] 
      ,[healthfactordatetime]  
	  ,Note_Date
      ,[Note_MHTC]  
	  ,[Note_Author]
      ,[asgn_type]   
      ,[Team]
      --,[TeamSID]
      ,[teamrole]
      ,[staffname]
      ,[RelationshipStartDate]
      --,[RelationshipEndDate]
  FROM [BHIP].[MHTCAssignment] m WITH (NOLOCK)
  INNER JOIN  [LookUp].[Sta6a] l WITH (NOLOCK) on m.checklistid = l.checklistid