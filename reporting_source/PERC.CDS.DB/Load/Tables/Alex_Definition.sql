CREATE TABLE [Load].[Alex_Definition] (
    [GUID]            VARCHAR (100)  NULL,
    [Definition]      VARCHAR (500)  NULL,
    [Description]     VARCHAR (1000) NULL,
    [Version]         INT            NULL,
    [UserID]          INT            NULL,
    [OrgID]           INT            NULL,
    [DependencyGUID]  INT            NULL,
    [Status]          VARCHAR (50)   NULL,
    [ActivateOn]      DATETIME2 (0)  NULL,
    [DeactivateOn]    DATETIME2 (0)  NULL,
    [LastModifiedOn]  DATETIME2 (0)  NULL,
    [ETLLoadDateTime] DATETIME2 (0)  NULL,
    [Collections]     VARCHAR (500)  NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_Alex_Definition]
    ON [Load].[Alex_Definition];

