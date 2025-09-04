/*****************************************************************************
*
* View: vw_NLP_CleanedConcepts
* 
* Removes template snippets and irrelevant snippets based on term/snippet logic
*
* Performance Optimizations:
*   - Restructured exclusion logic for better readability and optimization
*   - Early filtering by concept type to reduce processing
*
*****************************************************************************/

CREATE VIEW vw_NLP_CleanedConcepts
AS
  SELECT *
  FROM vw_NLP_Concepts
  WHERE Snippet NOT IN (SELECT Snippet FROM vw_NLP_TemplateSnippets)
    -- Exclude 3ST concept false positives
    AND NOT (Category = '3ST' AND (
      -- Exclude specific terms that are likely false positives
      Term IN ('armed', 'blade', 'razor', 'ice', 'molly', 'drinks', 'drank', 'coc', 
               'cutting', 'snap', 'spice', 'busted','mushrooms','one puff','tripping','mad',
               'use alcohol','knife','in his car','in her car','in their car','coke','bleach',
               'hanging','sentence','wires','cut his','rope','blunt')
      -- Exclude negation patterns
      OR Snippet LIKE '%denies '+Term+'%'
      OR Snippet LIKE '%no '+Term+'%'
      OR Snippet LIKE '%without '+Term+'%'
      OR Snippet LIKE '%avoid '+Term+'%'
      -- Context-specific exclusions
      OR (Term = 'irritable' AND Snippet LIKE '%bowel%')
      OR (Term = 'with a plan' AND Snippet NOT LIKE '%suicid%' AND Snippet NOT LIKE '% si%')
      OR (TargetClass = 'PPAIN' AND Snippet LIKE '%NALOXONE HCL 4MG/SPRAY SOLN NASAL SPRAY%')
      OR (TargetClass = 'CAPACITY' AND Snippet LIKE '%Indication: FOR OPIOID overdose%')
      -- Crisis line mentions with specific terms
      OR ((Snippet LIKE '% 988%' OR Snippet LIKE '%1-800-273%') 
          AND SubclassLabel = 'Pain exceeds tolerance' 
          AND Term IN ('feeling suicidal', 'feel suicidal', 'feel like hurting himself'))
      -- Web-related exclusions
      OR (Snippet LIKE '%www.%' AND Term = 'loneliness')
      OR (Snippet LIKE '%www.%' AND Snippet LIKE '%911%')
      -- Template-like clinical text
      OR (Snippet LIKE '%Veteran was reminded to contact the Mental Health Clinic%' 
          AND SubclassLabel = 'Acquired capacity for suicide' AND Term = 'thoughts of self-harm')
      OR (Snippet LIKE '%Motivational Interviewing (MI)%' 
          AND SubclassLabel = 'Situational capacity for suicide' AND Term = 'substance use')
      OR (Snippet LIKE '% 988%' AND Term = 'illicit substances')
    ))
    -- Exclude DETOX concept false positives
    AND NOT (TargetClass = 'DETOX' AND (
      (Term = 'detoxification' AND TIUStandardTitle = 'ACUPUNCTURE NOTE')
      OR (Term = 'saws' AND TIUStandardTitle IN ('NURSING PROCEDURE NOTE','SURGERY NOTE',
                                                  'SURGERY NURSING NOTE','SURGERY RN NOTE'))
      OR (Term = 'sews' AND TIUStandardTitle = 'CONSENT')
      OR Term = 'Minds'
    ));
