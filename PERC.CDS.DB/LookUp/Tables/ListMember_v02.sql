CREATE TABLE [LookUp].[ListMember_v02] (
    [List]             VARCHAR (50)  NOT NULL,
    [Domain]           VARCHAR (50)  NOT NULL,
    [ItemID]           INT           NOT NULL,
    [Attribute1]       VARCHAR (50)  NOT NULL,
    [AttributeValue1]  VARCHAR (500) NULL,
    [Attribute2]       VARCHAR (50)  NULL,
    [AttributeValue2]  VARCHAR (500) NULL,
    [CreatedDateTime]  SMALLDATETIME CONSTRAINT [DF_ListMember_v02_CreatedDateTime] DEFAULT (getdate()) NOT NULL,
    [MappingSource]    VARCHAR (50)  NULL,
    [ApprovalStatus]   VARCHAR (50)  NULL,
    [ApprovedDateTime] SMALLDATETIME NULL,
    CONSTRAINT [PK_LookUp_ListMember_v02] PRIMARY KEY CLUSTERED ([List] ASC, [Domain] ASC, [ItemID] ASC)
);

