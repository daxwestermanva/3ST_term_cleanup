SELECT [Label]
      ,[SnippetID]
      ,[Term]
      ,[PatientSID]
      ,[Sta3n]
      ,[ReferenceDateTime]
      ,[TIUdocumentSID]
      ,[NoteAndSnipOffset]
      ,[TargetClass]
      ,[TIUstandardTitle]
      ,[Snippet]
      ,[VisitSID]
      ,[TargetSubClass]
      ,[TermID]
      ,[OpCode]
      ,[FileDate]
FROM [OMHSP_PERC_PDW].[App].[HDAP_NLP_OMHSP] nlp with (nolock)
    left join [OMHSP_PERC_NLP].[Dflt].[3ST_subclass_mapping] subclass with (nolock)
    on ISNUMERIC(nlp.[TargetSubClass]) = 1
        and CAST(nlp.TargetSubClass AS INT) = subclass.Instance_ID
where 
	nlp.[Label] = 'POSITIVE'
    AND ((nlp.TargetClass IN ('PPAIN','CAPACITY') AND subclass.Instance_ID IS NOT NULL)
    OR (nlp.TargetClass IN ('XYLA') AND (nlp.TargetSubClass = 'SUS' OR nlp.TargetSubClass = 'SUS-P'))
    OR nlp.TargetClass IN ('LIVESALONE','LONELINESS','DETOX','IDU','CAPACITY','JOBINSTABLE',
                            'JUSTICE','SLEEP','FOODINSECURE','DEBT','HOUSING'))

