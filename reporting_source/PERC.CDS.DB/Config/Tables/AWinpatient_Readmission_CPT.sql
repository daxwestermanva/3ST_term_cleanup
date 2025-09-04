CREATE TABLE [Config].[AWinpatient_Readmission_CPT] (
    [CPTcode]                     VARCHAR (10) NULL,
    [AHRQ_CCS_Procedure_Category] INT          NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_AWinpatient_Readmission_CPT]
    ON [Config].[AWinpatient_Readmission_CPT];

