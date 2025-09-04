CREATE TABLE [Present].[MOUD] (
    [MVIPersonSID]       INT           NULL,
    [PatientSID]         INT           NULL,
    [Sta3n]              INT           NULL,
    [MOUD]               VARCHAR (150) NULL,
    [NonVA]              BIT           NOT NULL,
    [Inpatient]          BIT           NOT NULL,
    [Rx]                 BIT           NOT NULL,
    [OTP]                BIT           NOT NULL,
    [CPT]                BIT           NOT NULL,
    [CPRS_Order]         BIT           NOT NULL,
    [MOUDDate]           DATETIME2 (0) NULL,
    [Prescriber]         VARCHAR (150) NULL,
    [StaPa]              VARCHAR (150) NULL,
    [ActiveMOUD]         BIT           NOT NULL,
    [ActiveMOUD_Patient] BIT           NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_MOUD]
    ON [Present].[MOUD];

