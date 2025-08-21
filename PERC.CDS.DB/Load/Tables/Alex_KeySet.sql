CREATE TABLE [Load].[Alex_KeySet] (
    [GUID]            VARCHAR (100) NULL,
    [UserID]          INT           NULL,
    [Version]         INT           NULL,
    [KeyID]           VARCHAR (50)  NULL,
    [Type]            VARCHAR (50)  NULL,
    [LastModifiedOn]  DATETIME2 (0) NULL,
    [ETLLoadDateTime] DATETIME2 (0) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Alex_KeySet]
    ON [Load].[Alex_KeySet];

