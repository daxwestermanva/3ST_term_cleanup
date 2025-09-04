/*****************************************************************************
*****************************************************************************/
DROP TABLE IF EXISTS #StageVariables
SELECT MVIPersonSID
	,ChecklistID
	,CASE WHEN TargetClass = 'LIVESALONE'	THEN 'Lives Alone'
		WHEN TargetClass='CAPACITY' THEN 'Capacity for Suicide'
		WHEN TargetClass='PPAIN' THEN 'Psychological Pain'
		ELSE TargetClass 
		END AS Concept
	,SubclassLabel= CASE
		WHEN SubclassLabel='Acquired capacity for suicide' OR Subclasslabel = 'practical' THEN 'Repeated Exposure to Painful/Provocative Events'
		WHEN SubclassLabel='Dispositional capacity for suicide' OR SubclassLabel='dispositional' THEN 'Genetic/Temperamental Risk Factors'
		WHEN SubclassLabel='Situational capacity for suicide' OR Subclasslabel = 'situational' THEN 'Acute/Situational Risk Factors'
		WHEN SubclassLabel='Practical capacity for suicide' OR Subclasslabel= 'acquired' THEN 'Access to Lethal Means'
		WHEN TargetClass='CAPACITY' THEN NULL
		WHEN TargetClass='Sleep' THEN 'Sleep issues'
		WHEN TargetClass='Debt' THEN 'Financial issues'
		WHEN TargetClass='Justice' THEN 'Legal issues'
		WHEN TargetClass='FoodInsecure' THEN 'Food insecurity'
		WHEN TargetClass='Housing' THEN 'Housing issues'
		WHEN TargetClass='JobInstable' THEN 'Job instability'
		WHEN TargetClass='Loneliness' THEN 'Loneliness'
		WHEN TargetClass='LivesAlone' THEN 'Lives Alone'
		WHEN TargetClass='XYLA' THEN 'Suspected Xylazine Exposure'
		WHEN TargetClass='IDU' THEN 'Suspected Injection Drug Use'
		ELSE SubclassLabel
	END	
	,Term
	,EntryDateTime
	,ReferenceDateTime
	,TIUDocumentDefinition
	,StaffName
	,REPLACE(Snippet,Term,Term) AS Snippet --do this to allow for proper formatting in report when term may not be all lowercase within the snippet
	,ROW_NUMBER() OVER (PARTITION BY MVIPersonSID, TargetClass, SubclassLabel ORDER BY ReferenceDateTime DESC, EntryDateTime DESC) AS CountDesc
INTO #StageVariables
FROM #OneRecordPerNote 