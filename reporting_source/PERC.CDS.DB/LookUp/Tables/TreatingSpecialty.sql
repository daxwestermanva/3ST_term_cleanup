CREATE TABLE [LookUp].[TreatingSpecialty] (
    [TreatingSpecialtySID]                INT           NOT NULL,
    [TreatingSpecialtyName]               VARCHAR (100) NULL,
    [Specialty]                           VARCHAR (100) NULL,
    [PTFCode]                             VARCHAR (50)  NULL,
    [Sta3n]                               SMALLINT      NOT NULL,
    [MedSurgInpatient_TreatingSpecialty]  BIT           NULL,
    [MentalHealth_TreatingSpecialty]      BIT           NULL,
    [Reach_MHDischarge_TreatingSpecialty] BIT           NULL,
    [Reach_AnyMH_TreatingSpecialty]       BIT           NULL,
    [Domiciliary_TreatingSpecialty]       BIT           NULL,
    [Homeless_TreatingSpecialty]          BIT           NULL,
    [NursingHome_TreatingSpecialty]       BIT           NULL,
    [Residential_TreatingSpecialty]       BIT           NULL,
    [RRTP_TreatingSpecialty]              BIT           NULL
);


GO
CREATE CLUSTERED INDEX [CIX_LookUPTreatingSpecialtySID]
    ON [LookUp].[TreatingSpecialty]([TreatingSpecialtySID] ASC);

