SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

/************************************************************************
 * #3st_subclass_mapping - Load subclass mapping for 3ST concepts
 ************************************************************************/
DROP TABLE IF EXISTS #3st_subclass_mapping
GO

SELECT [INSTANCE_ID]
      ,[CLASS]
      ,[SUBCLASS]
      ,[PREFERRED_LABEL]
      ,[SUBCLASS_GROUPING]
INTO #3st_subclass_mapping
FROM [OMHSP_PERC_NLP].[Dflt].[3ST_subclass_mapping] WITH (NOLOCK)
WHERE Polarity = 'indicates_presence'
    AND (Class = 'Psychological Pain'
        AND Subclass IN ('Pain exceeds tolerance', 'Housing issues', 'Sleep issues', 'Financial issues', 'Legal issues')
        OR (Class = 'Capacity for Suicide'))

/************************************************************************
 * #TIU - Load TIU document definitions and titles for filtering
 ************************************************************************/

DROP TABLE IF EXISTS #TIU
GO

WITH cte_TIUStandardTitle AS (
    SELECT [TIUStandardTitleSID]
          ,[TIUStandardTitleIEN]
          ,[Sta3n]
          ,[TIUStandardTitle]
          ,[TIUSubjectMatterDomainSID]
          ,[TIURoleSID]
          ,[TIUSettingSID]
          ,[TIUServiceSID]
          ,[TIUDocumentTypeSID]
          ,[MasterEntryForVUIDFlag]
          ,[VUID]
    FROM [CDWWork].[Dim].[TIUStandardTitle] WITH (NOLOCK)
),
cte_TIUDocumentDefinition AS (
    SELECT [TIUDocumentDefinitionSID]
          ,[TIUDocumentDefinitionIEN]
          ,[Sta3n]
          ,[TIUDocumentDefinition]
          ,[TIUDocumentDefinitionAbbreviation]
          ,[TIUDocumentDefinitionType]
          ,[TIUDocumentDefinitionPrintName]
          ,[PersonalOwnerStaffSID]
          ,[UserClassSID]
          ,[TIUStatusSID]
          ,[SharedFlag]
          ,[NationalStandardFlag]
          ,[PostingIndicator]
          ,[LaygoAllowedFlag]
          ,[TargetTextFieldSubscript]
          ,[BoilerplateOnUploadEnabledFlag]
          ,[DistributeFlag]
          ,[SuppressVisitSelectionFlag]
          ,[EditTemplate]
          ,[PrintFormHeader]
          ,[PrintFormNumber]
          ,[PrintGroup]
          ,[AllowCustomFormHeadersFlag]
          ,[TIUTimestamp]
          ,[TIUStandardTitleSID]
          ,[MapAttemptedDateTime]
          ,[MapAttemptedVistaErrorDate]
          ,[MapAttemptedDateTimeTransformSID]
          ,[MapAttemptedByStaffSID]
    FROM [CDWWork].[Dim].[TIUDocumentDefinition] WITH (NOLOCK)
),
cte_Config_NLP_3ST_TIUStandardTitle AS (
    SELECT *
    FROM cte_TIUStandardTitle
)
SELECT s.TIUStandardTitle
      ,s.TIUStandardTitleSID
      ,c.TIUDocumentDefinition
      ,c.TIUDocumentDefinitionSID
      ,CASE WHEN t.TIUStandardTitle IS NOT NULL -- StandardTitle inclusions for 3ST
                AND TIUDocumentDefinition NOT IN ('MH TMS NURSE NOTE') -- DocumentDefinition exclusions for 3ST
            THEN 1 
            ELSE 0 
        END AS TIU_3ST
INTO #TIU
FROM cte_TIUStandardTitle s WITH (NOLOCK)
    INNER JOIN cte_TIUDocumentDefinition c WITH (NOLOCK)
        ON s.TIUStandardTitleSID = c.TIUStandardTitleSID
    LEFT JOIN cte_Config_NLP_3ST_TIUStandardTitle t WITH (NOLOCK)
        ON t.TIUStandardTitle = s.TIUStandardTitle


/************************************************************************
 * #hdap_nlp_omhsp_positive_30_days - Preload POSITIVE Labels up to 30 days back
 ************************************************************************/

DROP TABLE IF EXISTS #hdap_nlp_omhsp_positive_30_days

SELECT TOP 100000
    nlp.*
   ,subclass.INSTANCE_ID
   ,subclass.PREFERRED_LABEL
   ,ISNUMERIC(nlp.TargetSubClass) AS TargetSubClass_is_numeric
INTO #hdap_nlp_omhsp_positive_30_days
FROM [OMHSP_PERC_PDW].[App].[HDAP_NLP_OMHSP] nlp WITH (NOLOCK)
    LEFT JOIN #3st_subclass_mapping subclass WITH (NOLOCK)
        ON nlp.TargetSubClass = CAST(subclass.INSTANCE_ID AS VARCHAR)
WHERE nlp.ReferenceDateTime >= DATEADD(DAY, -30, CURRENT_TIMESTAMP)
    AND nlp.[Label] = 'POSITIVE'

GO

-- Clean up temporary table no longer needed
DROP TABLE IF EXISTS #3st_subclass_mapping
GO

-- Create indexes to optimize joins and filtering
CREATE NONCLUSTERED INDEX idx_patient_sid 
    ON #hdap_nlp_omhsp_positive_30_days(PatientSID)
GO

CREATE NONCLUSTERED INDEX idx_target_class__INSTANCE_ID 
    ON #hdap_nlp_omhsp_positive_30_days(TargetClass, INSTANCE_ID)
GO

CREATE NONCLUSTERED INDEX idx_target_class__TargetSubClass 
    ON #hdap_nlp_omhsp_positive_30_days(TargetClass, TargetSubClass)
GO

/************************************************************************
 * #GetConcepts - Extract and categorize NLP concepts with patient data
 ************************************************************************/

DROP TABLE IF EXISTS #GetConcepts

;WITH cte_DWS_PatientSIDToMVISID AS (
    SELECT [PatientSID]
          ,[PatientGID]
          ,[MVIPersonSID]
          ,[PatientICN]
          ,[Sta3n]
          ,[IsPrimary]
          ,[InsertLogID]
    FROM [OMHSP_PERC_PDW].[App].[DWS_PatientSIDToMVISID] WITH (NOLOCK)
),
cte_MasterPatient AS (
    SELECT [PatientGID]
          ,[MVIPersonSID]
          ,[Sta3n]
          ,[PatientName]
          ,[PatientLastName]
          ,[PatientFirstName]
          ,[PatientSSN]
          ,[DateOfDeath]
          ,[Gender]
          ,[PatientICN]
          ,[DateOfBirth]
          ,[TestPatientFlag]
          ,[SourcePatientSID]
          ,[ModifiedDateTime]
          ,[HealthRecordModifiedDateTime]
          ,[ICNUpdateFlag]
          ,[InsertLogID]
          ,[UpdateLogID]
          ,[VeteranFlag]
    FROM [OMHSP_PERC_PDW].[App].[DWS_MasterPatient_002] WITH (NOLOCK)
)
SELECT d.MVIPersonSID
      ,nlp.TargetClass
      ,CASE WHEN nlp.PREFERRED_LABEL IS NOT NULL 
            THEN nlp.PREFERRED_LABEL
            ELSE nlp.TargetSubClass
        END AS SubclassLabel
      ,nlp.Term
      ,nlp.ReferenceDateTime
      ,nlp.TIUStandardTitle
      ,nlp.TIUDocumentSID
      ,nlp.NoteAndSnipOffset
      ,TRIM(REPLACE(nlp.Snippet, 'SNIPPET:', '')) AS Snippet
      ,CASE WHEN nlp.TargetClass IN ('PPAIN', 'CAPACITY', 'JOBINSTABLE', 'JUSTICE', 'SLEEP', 'FOODINSECURE', 'DEBT', 'HOUSING') 
            THEN '3ST' 
            ELSE NULL 
        END AS Category
INTO #GetConcepts
FROM #hdap_nlp_omhsp_positive_30_days nlp
    INNER JOIN cte_DWS_PatientSIDToMVISID d
        ON nlp.PatientSID = d.PatientSID
    INNER JOIN cte_MasterPatient mvi
        ON d.MVIPersonSID = mvi.MVIPersonSID
WHERE (nlp.TargetClass IN ('PPAIN', 'CAPACITY') AND nlp.INSTANCE_ID IS NOT NULL)
    OR (nlp.TargetClass IN ('XYLA') AND (nlp.TargetSubClass = 'SUS' OR nlp.TargetSubClass = 'SUS-P'))
    OR nlp.TargetClass IN (
        'LIVESALONE'
       ,'LONELINESS'
       ,'DETOX'
       ,'IDU'
       ,'CAPACITY'
       ,'JOBINSTABLE'
       ,'JUSTICE'
       ,'SLEEP'
       ,'FOODINSECURE'
       ,'DEBT'
       ,'HOUSING'
    )

-- Clean up temporary table no longer needed
DROP TABLE #hdap_nlp_omhsp_positive_30_days

/************************************************************************
 * #IdentifyTemplates - Identify frequently occurring template snippets
 ************************************************************************/

DROP TABLE IF EXISTS #IdentifyTemplates
SELECT Snippet
      ,TargetClass
      ,COUNT(DISTINCT MVIPersonSID) AS PatientCount
      ,COUNT(DISTINCT TIUDocumentSID) AS DocumentCount
INTO #IdentifyTemplates
FROM #GetConcepts
GROUP BY Snippet, TargetClass

-- Remove concepts associated with frequently occurring templates
-- This deletes rows where the snippet appears in 10+ patients AND 10+ documents
DELETE FROM #GetConcepts
WHERE Snippet IN (
    SELECT Snippet 
    FROM #IdentifyTemplates 
    WHERE PatientCount >= 10 AND DocumentCount >= 10
)

/************************************************************************
 * Data cleanup - Remove irrelevant and false positive snippets
 ************************************************************************/

-- Additional deletions identifying irrelevant snippets
DELETE FROM #GetConcepts 
WHERE (
    -- 3ST Concepts exclusions
    Category = '3ST'
    AND (
        Term IN (
            'armed', 'blade', 'razor', 'ice', 'molly', 'drinks', 'drank', 'coc', 'cutting', 
            'snap', 'spice', 'busted', 'mushrooms', 'one puff', 'tripping', 'mad', 'use alcohol', 
            'knife', 'in his car', 'in her car', 'in their car', 'coke', 'bleach', 'hanging', 
            'sentence', 'wires', 'cut his', 'rope', 'blunt'
        ) -- Reference: 1418020
        OR Snippet LIKE CONCAT('%denies ', Term, '%')
        OR Snippet LIKE CONCAT('%no ', Term, '%') 
        OR Snippet LIKE CONCAT('%without ', Term, '%')
        OR Snippet LIKE CONCAT('%avoid ', Term, '%')
        OR (Term = 'irritable' AND Snippet LIKE '%bowel%')
        OR (Term = 'with a plan' AND (Snippet NOT LIKE '%suicid%' AND Snippet NOT LIKE '% si%')) -- Reference: 8864
        OR (TargetClass = 'PPAIN' AND Snippet LIKE '%NALOXONE HCL 4MG/SPRAY SOLN NASAL SPRAY%')
        OR (TargetClass = 'CAPACITY' AND Snippet LIKE '%Indication: FOR OPIOID overdose%')
        OR ((Snippet LIKE '% 988%' OR Snippet LIKE '%1-800-273%') 
            AND SubclassLabel = 'Pain exceeds tolerance' 
            AND Term IN ('feeling suicidal', 'feel suicidal', 'feel like hurting himself'))
        OR (Snippet LIKE '%www.%' AND Term = 'loneliness') -- Note: Only 63 rows affected
        OR (Snippet LIKE '%www.%' AND Snippet LIKE '%911%') 
        OR (Snippet LIKE '%Veteran was reminded to contact the Mental Health Clinic%' 
            AND SubclassLabel = 'Acquired capacity for suicide' 
            AND Term = 'thoughts of self-harm') 
        OR (Snippet LIKE '%Motivational Interviewing (MI)%' 
            AND SubclassLabel = 'Situational capacity for suicide' 
            AND Term = 'substance use') 
        OR (Snippet LIKE '% 988%' AND Term = 'illicit substances')
    )
)
OR (
    -- DETOX Concepts exclusions
    TargetClass = 'DETOX' 
    AND (
        (Term IN ('detoxification') AND TIUStandardTitle IN ('ACUPUNCTURE NOTE'))
        OR (Term IN ('saws') AND TIUStandardTitle IN ('NURSING PROCEDURE NOTE', 'SURGERY NOTE', 'SURGERY NURSING NOTE', 'SURGERY RN NOTE'))
        OR (Term IN ('sews') AND TIUStandardTitle IN ('CONSENT'))
        OR Term IN ('Minds')
    )
)

/************************************************************************
 * Cleanup - Drop all temporary tables
 ************************************************************************/

-- Clean up all temporary tables
DROP TABLE IF EXISTS #3st_subclass_mapping
DROP TABLE IF EXISTS #TIU
DROP TABLE IF EXISTS #hdap_nlp_omhsp_positive_30_days
DROP TABLE IF EXISTS #GetConcepts
DROP TABLE IF EXISTS #IdentifyTemplates