CREATE TABLE [Config].[PERC_Acronyms] (
    [Acronym]     VARCHAR (15)  NULL,
    [Definition]  VARCHAR (200) NULL,
    [Description] VARCHAR (500) NULL
);


GO
CREATE CLUSTERED COLUMNSTORE INDEX [CCIX_PERC_Acronyms]
    ON [Config].[PERC_Acronyms];

