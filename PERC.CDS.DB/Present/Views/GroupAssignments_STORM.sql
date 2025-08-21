




CREATE VIEW [Present].[GroupAssignments_STORM] as 

SELECT a.[PatientICN]
	  ,a.MVIPersonSID
	  ,CASE WHEN a.GroupID=8 AND (b.NonVAPrescriberFlag_VA = 0 OR b.NonVAPrescriberFlag_VA IS NULL) THEN 1 
	        WHEN a.GroupID = 10 THEN 6
			WHEN a.Groupid = 8 AND b.NonVAPrescriberFlag_VA = 1 THEN 6
	  ELSE a.GroupID END as GroupID
	 -- ,Case when GroupType like 'Opioid Prescriber' then 1
		--	when GroupType like 'PCP' then 2
		--	when GroupType like 'BHIP' then 3
		--	when GroupType like 'PACT' then 4
		--	when GroupType like 'MHTC' then 5 else 0 
		--end as GroupID
      ,CASE WHEN a.GroupType = 'VA Opioid Prescriber' AND b.NonVAPrescriberFlag_VA = 1 THEN 'Community Care Prescriber'
	       ELSE a.GroupType END AS GroupType
      ,a.[ProviderSID]
      ,a.[ProviderName]
      ,a.[ChecklistID]
      ,a.Sta3n
	  ,a.VISN
  FROM [Present].[GroupAssignments] a
  LEFT JOIN [ORM].[NonVAProviders] b
  ON a.ProviderSID = b.ProviderSID AND b.NonVAPrescriberFlag_VA = 1
  WHERE a.GroupID IN (2,3,4,5,8,10)
 --  GroupType in (
	-- 'BHIP'
	--,'MHTC'
	--,'Opioid Prescriber'
	--,'PACT'
	--,'PCP'
	--)