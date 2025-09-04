-- =============================================
-- Author:       Liam Mina
-- Create date:  2021-11-04
-- Description:  

-- Modifications:
-- 10-17-23      CW      Adding in Detox rules
-- 10-18-23      VJ      Removed all group notes from IVDU as per SME feedback 9/26, 9/29
--                       Removed sexual health inventory template from IVDU as per SME feedback 9/21
-- 12-05-23      VJ      Removed additional notes from IVDU as per KR feedback (12/4)
-- 01-04-24      CW/VJ   Removed additional notes from IVDU as per KR feedback (1/3)
-- 04-03-24      LM      Broke up initial query for faster run time
-- 01-06-25      LM      Added staff name and entrydate
-- 05-12-25      LM      Added initial data for 3ST concepts Capacity and Psychological Pain
-- 05-28-25      CW      Updated exclusionary criteria re: IDU concept
-- 06-11-25      CW      Added Xylazine to concepts. Updating Concept labels per SPP guidance.
-- 06-12-25      LM      Refresh only past 30 days nightly (rest of year is static) for efficiency
-- =======================================================================================================

-- EXEC Code.Present_NLP_Variables @InitialBuild=1

CREATE PROCEDURE [Code].[Present_NLP_Variables]
    @InitialBuild BIT = 0
AS
BEGIN
    EXEC [Log].[ExecutionBegin] 'Code.Present_NLP_Variables', 'Execution of SP Code.Present_NLP_Variables';

    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    EXEC [Log].[ExecutionBegin] 'EXEC Code.OMHSP_Standard_SBOR', 'Execution of Code.OMHSP_Standard_SBOR SP';

    DECLARE @BeginDate DATE;

    -- Determine if this is an initial build
    IF (SELECT COUNT(*) FROM Present.NLP_Variables) = 0
    BEGIN
        SET @InitialBuild = 1;
    END;

    -- Set the BeginDate based on the build type
    IF @InitialBuild = 1
    BEGIN
        SET @BeginDate = DATEADD(DAY, -366, CAST(GETDATE() AS DATE));
    END
    ELSE
    BEGIN
        SET @BeginDate = DATEADD(DAY, -30, CAST(GETDATE() AS DATE));
    END;

    -- For 3ST concepts, limit on subclass and TIU Standard Title
    DROP TABLE IF EXISTS #Subclass;
    SELECT  Instance_ID
            , Class
            , SUBCLASS
            , Preferred_Label
            , SUBCLASS_GROUPING
    INTO 
    

    
    FROM Config.NLP_3ST_subclass_labels WITH (NOLOCK)
    WHERE   Polarity = 'indicates_presence'
            AND (
                    (
                        Class = 'Psychological Pain' 
                        AND Subclass IN (
                            'Pain exceeds tolerance'
                            , 'Housing issues'
                            , 'Sleep issues'
                            , 'Financial issues'
                            , 'Legal issues'
                        )
                ) OR (
                    Class = 'Capacity for Suicide'
                )
            );

    DROP TABLE IF EXISTS #TIU;
    SELECT  s.TIUStandardTitle
            , s.TIUStandardTitleSID
            , c.TIUDocumentDefinition
            , c.TIUDocumentDefinitionSID
            , CASE 
                WHEN t.TIUStandardTitle IS NOT NULL 
                    AND TIUDocumentDefinition NOT IN ('MH TMS NURSE NOTE') 
                THEN 1 
                ELSE 0 
            END AS TIU_3ST
    INTO #TIU
    FROM Dim.TIUStandardTitle s WITH (NOLOCK)
        INNER JOIN Dim.TIUDocumentDefinition c WITH (NOLOCK)
            ON s.TIUStandardTitleSID = c.TIUStandardTitleSID
        LEFT JOIN Config.NLP_3ST_TIUStandardTitle t WITH (NOLOCK)
            ON t.TIUStandardTitle = s.TIUStandardTitle;

    -- Pull in concepts of interest for CDS projects
    DROP TABLE IF EXISTS #GetConcepts;
    SELECT d.MVIPersonSID
        , a.TargetClass
        , CASE 
            WHEN s.PREFERRED_LABEL IS NOT NULL THEN s.PREFERRED_LABEL
            ELSE a.TargetSubClass
        END AS SubclassLabel
        , a.Term
        , a.ReferenceDateTime
        , a.TIUStandardTitle
        , a.TIUDocumentSID
        , a.NoteAndSnipOffset
        , TRIM(REPLACE(a.Snippet, 'SNIPPET:', '')) AS Snippet
        , CASE 
            WHEN a.TargetClass IN (
                    'PPAIN'
                    , 'CAPACITY'
                    , 'JOBINSTABLE'
                    , 'JUSTICE'
                    , 'SLEEP'
                    , 'FOODINSECURE'
                    , 'DEBT'
                    , 'HOUSING'
            ) THEN '3ST' 
            ELSE NULL 
        END AS Category
    INTO #GetConcepts
    FROM [PDW].[HDAP_NLP_OMHSP] a WITH (NOLOCK)
        INNER JOIN Common.vwMVIPersonSIDPatientPersonSID d WITH (NOLOCK)
            ON a.PatientSID = d.PatientPersonSID
        INNER JOIN Common.MasterPatient mvi WITH (NOLOCK)
            ON d.MVIPersonSID = mvi.MVIPersonSID
        LEFT JOIN #Subclass s
            ON TRY_CAST(a.TargetSubClass AS INT) = s.INSTANCE_ID
    WHERE mvi.DateOfDeath_Combined IS NULL
        AND a.Label = 'POSITIVE'
        AND   (
                (
                        a.TargetClass IN (
                            'PPAIN'
                            , 'CAPACITY'
                        ) 
                        AND s.INSTANCE_ID IS NOT NULL
                )
                OR (
                    a.TargetClass IN ('XYLA')
                    AND (
                            a.TargetSubClass = 'SUS'
                            OR a.TargetSubClass = 'SUS-P'
                    )
                )
                OR a.TargetClass IN (
                    'LIVESALONE'
                    , 'LONELINESS'
                    , 'DETOX'
                    , 'IDU'
                    , 'CAPACITY'
                    , 'JOBINSTABLE'
                    , 'JUSTICE'
                    , 'SLEEP'
                    , 'FOODINSECURE'
                    , 'DEBT'
                    , 'HOUSING'
                )
        )
        AND CAST(a.ReferenceDateTime AS DATE) >= @BeginDate;

    -- Additional processing and cleanup logic...

    -- Publish the results
    IF @InitialBuild = 1 
    BEGIN
        EXEC [Maintenance].[PublishTable] 'Present.NLP_Variables', '#StageVariables';
    END
    ELSE
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;
                DELETE [Present].[NLP_Variables] WITH (TABLOCK)
                WHERE ReferenceDateTime >= @BeginDate 
                   OR ReferenceDateTime <= DATEADD(DAY, -366, CAST(GETDATE() AS DATE));

                INSERT INTO [Present].[NLP_Variables] WITH (TABLOCK) (
                    [MVIPersonSID]
                    , [ChecklistID]
                    , [Concept]
                    , [SubclassLabel]
                    , [Term]
                    , [EntryDateTime]
                    , [ReferenceDateTime]
                    , [TIUDocumentDefinition]
                    , [StaffName]
                    , [Snippet]
                    , [CountDesc]
                )
                SELECT  [MVIPersonSID]
                        , [ChecklistID]
                        , [Concept]
                        , [SubclassLabel]
                        , [Term]
                        , [EntryDateTime]
                        , [ReferenceDateTime]
                        , [TIUDocumentDefinition]
                        , [StaffName]
                        , [Snippet]
                        , [CountDesc]
                FROM #StageVariables;

                DECLARE @AppendRowCount INT = (SELECT COUNT(*) FROM #StageVariables);
                EXEC [Log].[PublishTable] 'Present', 'NLP_Variables', '#StageVariables', 'Append', @AppendRowCount;
            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            ROLLBACK TRANSACTION;
            PRINT 'Error publishing to Present.NLP_Variables; transaction rolled back';
            DECLARE @ErrorMsg VARCHAR(1000) = ERROR_MESSAGE();
            EXEC [Log].[ExecutionEnd] 'Error';
            THROW;
        END CATCH;
    END;

    DROP TABLE IF EXISTS #StageVariables;

    EXEC [Log].[ExecutionEnd] @Status = 'Completed';
END;