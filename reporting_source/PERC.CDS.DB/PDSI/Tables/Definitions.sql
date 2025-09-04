CREATE TABLE [PDSI].[Definitions] (
    [Program_ID]        FLOAT (53)     NULL,
    [MeasureID]         FLOAT (53)     NULL,
    [DimensionID]       FLOAT (53)     NULL,
    [Dimension]         NVARCHAR (255) NULL,
    [Measurename]       NVARCHAR (255) NULL,
    [VariableNameClean] NVARCHAR (255) NULL,
    [DashboardOrder]    FLOAT (53)     NULL,
    [VariableName]      NVARCHAR (255) NULL,
    [Description]       NVARCHAR (255) NULL,
    [TimePeriod]        NVARCHAR (255) NULL,
    [%National]         NVARCHAR (255) NULL,
    [ActiveMeasure]     FLOAT (53)     NULL,
    [ScoreDirection]    NVARCHAR (255) NULL,
    [DiagnosisCriteria] NVARCHAR (255) NULL,
    [DiagnosisName]     NVARCHAR (255) NULL,
    [DiagnosisCohort]   NVARCHAR (255) NULL,
    [MedicationCohort]  NVARCHAR (255) NULL,
    [Exclusion]         NVARCHAR (255) NULL,
    [Numerator]         NVARCHAR (255) NULL,
    [Actionable]        NVARCHAR (255) NULL,
    [Denominator]       NVARCHAR (255) NULL,
    [OtherInformation]  NVARCHAR (600) NULL,
    [OtherInformation2] NVARCHAR (600) NULL,
    [Rational]          NVARCHAR (255) NULL,
    [Contact]           NVARCHAR (255) NULL,
    [ContactEmail]      NVARCHAR (255) NULL,
    [Guidance]          NVARCHAR (800) NULL,
    [Guidance2]         NVARCHAR (255) NULL,
    [LinktoResources]   NVARCHAR (600) NULL,
    [LinktoResources2]  NVARCHAR (255) NULL,
    [CutOffs]           FLOAT (53)     NULL,
    [MeasureMnemonic]   NVARCHAR (255) NULL
)
WITH (DATA_COMPRESSION = PAGE);




GO
