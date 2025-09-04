SELECT Instance_ID
            , [Class]
            , [Subclass]
            , Preferred_Label
            , SUBCLASS_GROUPING
FROM [OMHSP_PERC_NLP].[Dflt].[3ST_subclass_mapping] WITH (NOLOCK)
WHERE	Polarity = 'indicates_presence'
    AND (
				(
					[Class] = 'Psychological Pain'
    AND [Subclass] IN (
                        'Pain exceeds tolerance'
                        , 'Housing issues'
                        , 'Sleep issues'
                        , 'Financial issues'
                        , 'Legal issues'
                    )
                )
    OR (
                [Class] = 'Capacity for Suicide'
            )
      )