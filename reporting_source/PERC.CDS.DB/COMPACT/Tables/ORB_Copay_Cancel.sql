CREATE TABLE [COMPACT].[ORB_Copay_Cancel] (
    [MVIPersonSID]    INT             NOT NULL,
    [Sta6a]           VARCHAR (50)    NULL,
    [ARBillNumber]    VARCHAR (50)    NULL,
    [VisitSID]        BIGINT          NULL,
    [InpatientSID]    BIGINT          NULL,
    [TotalCharge]     DECIMAL (19, 4) NULL,
    [COMPACTCategory] VARCHAR (50)    NULL,
    [COMPACTAction]   VARCHAR (50)    NULL
);

