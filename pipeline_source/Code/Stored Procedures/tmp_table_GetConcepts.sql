--Pull in concepts of interest for CDS projects
SELECT d.MVIPersonSID
	,a.TargetClass
	,CASE WHEN s.PREFERRED_LABEL IS NOT NULL THEN s.PREFERRED_LABEL
		ELSE a.TargetSubClass
		END AS SubclassLabel
	,a.Term
	,a.ReferenceDateTime
	,a.TIUStandardTitle
	,a.TIUDocumentSID
	,a.NoteAndSnipOffset
	,TRIM(REPLACE(a.Snippet,'SNIPPET:','')) AS Snippet
	,CASE WHEN a.TargetClass IN ('PPAIN','CAPACITY','JOBINSTABLE','JUSTICE','SLEEP','FOODINSECURE','DEBT','HOUSING') 
		THEN '3ST' ELSE NULL END AS Category
FROM [PDW].[HDAP_NLP_OMHSP] a WITH (NOLOCK)
INNER JOIN Common.vwMVIPersonSIDPatientPersonSID d WITH (NOLOCK)
	ON a.PatientSID = d.PatientPersonSID
INNER JOIN Common.MasterPatient mvi WITH (NOLOCK)
	ON d.MVIPersonSID=mvi.MVIPersonSID
LEFT JOIN #Subclass s
	ON TRY_CAST(a.TargetSubClass AS INT)=s.INSTANCE_ID
WHERE mvi.DateOfDeath_Combined IS NULL
AND a.Label = 'POSITIVE'
AND ((a.TargetClass IN ('PPAIN','CAPACITY') AND s.INSTANCE_ID IS NOT NULL)-- AND t.TIUStandardTitleSID IS NOT NULL)
	OR (a.TargetClass IN ('XYLA') AND (a.TargetSubClass='SUS' OR a.TargetSubClass='SUS-P')) --only suspected IDU and suspected xylazine, not other types of mentions e.g., education
	OR a.TargetClass IN ('LIVESALONE','LONELINESS','DETOX','IDU'
						,'CAPACITY' --Capacity (3ST)
						,'JOBINSTABLE','JUSTICE','SLEEP','FOODINSECURE','DEBT','HOUSING' --PPAIN (3ST)
						)
					)
AND CAST(a.ReferenceDateTime AS date) >= @BeginDate