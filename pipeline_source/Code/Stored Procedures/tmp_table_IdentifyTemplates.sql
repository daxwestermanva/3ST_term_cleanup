SELECT Snippet
	,TargetClass
	,COUNT(DISTINCT MVIPersonSID) AS PatientCount
	,COUNT(DISTINCT TIUDocumentSID) AS DocumentCount
FROM #GetConcepts  -- pipeline_source\Code\Stored Procedures\tmp_table_GetConcepts.sql
GROUP BY Snippet, TargetClass


DELETE FROM #GetConcepts
WHERE Snippet IN (SELECT Snippet FROM #IdentifyTemplates WHERE PatientCount>=10 AND DocumentCount>=10)


DELETE FROM #GetConcepts 
--3ST Concepts
WHERE (Category='3ST'
		AND (Term IN ('armed', 'blade', 'razor', 'ice', 'molly', 'drinks', 'drank', 'coc', 'cutting', 'snap', 'spice', 'busted','mushrooms','one puff','tripping'
						,'mad','use alcohol','knife','in his car','in her car','in their car','coke','bleach','hanging','sentence','wires','cut his','rope','blunt') --1418020
			OR Snippet LIKE CONCAT('%denies ',Term,'%')
			OR Snippet LIKE CONCAT('%no ',Term,'%') 
			OR Snippet LIKE CONCAT('%without ',Term,'%')
			OR Snippet LIKE CONCAT('%avoid ',Term,'%')
			OR (Term='irritable' AND Snippet LIKE '%bowel%')
			OR (Term='with a plan' AND (Snippet NOT LIKE '%suicid%' AND Snippet NOT LIKE '% si%'))--8864
			OR (TargetClass='PPAIN' AND Snippet LIKE '%NALOXONE HCL 4MG/SPRAY SOLN NASAL SPRAY%')
			OR (TargetClass='CAPACITY' AND Snippet LIKE '%Indication: FOR OPIOID overdose%')
			OR ((Snippet LIKE '% 988%' OR Snippet LIKE '%1-800-273%') AND SubclassLabel='Pain exceeds tolerance' AND Term IN ('feeling suicidal', 'feel suicidal', 'feel like hurting himself'))
			OR (Snippet LIKE '%www.%' AND Term='loneliness') --LM - not sure this one is worth it - only 63 rows 
			OR (Snippet LIKE '%www.%' AND Snippet LIKE  '%911%') 
			OR (Snippet LIKE '%Veteran was reminded to contact the Mental Health Clinic%' AND SubclassLabel='Acquired capacity for suicide' AND Term='thoughts of self-harm') 
			OR (Snippet LIKE '%Motivational Interviewing (MI)%' AND SubclassLabel='Situational capacity for suicide' AND Term='substance use') 
			OR (Snippet LIKE '% 988%' AND Term='illicit substances')
		))
--Detox Concepts
OR (TargetClass='DETOX' AND
 ((TERM IN ('detoxification') AND TIUstandardTitle IN ('ACUPUNCTURE NOTE'))
 OR (TERM IN ('saws') AND TIUstandardTitle IN ('NURSING PROCEDURE NOTE','SURGERY NOTE','SURGERY NURSING NOTE','SURGERY RN NOTE'))
 OR (TERM IN ('sews') AND TIUstandardTitle IN ('CONSENT'))
 OR TERM IN ('Minds')
 ))
