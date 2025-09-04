CREATE TABLE [Config].[DMC_DisplayMessage] (
    [DisplayMessage]     TINYINT       NOT NULL,
    [DisplayMessageText] VARCHAR (300) NULL,
    [Link]               VARCHAR (50)  NULL,
    [Criteria]           VARCHAR (150) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_DMC_DisplayMessage]
    ON [Config].[DMC_DisplayMessage];

