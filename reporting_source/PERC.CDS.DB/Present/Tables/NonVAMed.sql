CREATE TABLE [Present].[NonVAMed] (
    [MVIPersonSID]               INT            NULL,
    [PatientPersonSID]           INT            NULL,
    [Sta3n]                      INT            NOT NULL,
    [Sta6a]                      NVARCHAR (100) NULL,
    [InstanceFromDate]           DATE           NULL,
    [InstancetoDate]             DATE           NULL,
    [InstanceSID]                BIGINT         NOT NULL,
    [InstanceType]               VARCHAR (14)   NOT NULL,
    [OrderSID]                   INT            NULL,
    [OrderType]                  VARCHAR (24)   NOT NULL,
    [OrderName]                  VARCHAR (100)  NULL,
    [DodFlag]                    INT            NULL,
    [Source]                     VARCHAR (1)    NOT NULL,
    [DrugNameWithoutDose_Max]    VARCHAR (100)  NULL,
    [SetTerm]                    VARCHAR (200)  NULL,
    [OUD_Methadone_BUP_PastYear] INT            NULL,
    [UpdatedPerName]             VARCHAR (250)  NULL
);










GO
