CREATE TABLE [ORM].[HospicePalliativeCare] (
    [MVIPersonSID] INT NULL,
    [Hospice]      INT NULL,
    [Palliative]   INT NULL,
    [Oncology]     INT NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_HospicePalliativeCare]
    ON [ORM].[HospicePalliativeCare];

