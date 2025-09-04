CREATE TABLE [Config].[SPPRITE_RiskFactors] (
    [ID]           CHAR (1)      NOT NULL,
    [DisplayOrder] TINYINT       NULL,
    [Label]        VARCHAR (100) NULL,
    [Active]       BIT           NULL,
    PRIMARY KEY CLUSTERED ([ID] ASC)
);

