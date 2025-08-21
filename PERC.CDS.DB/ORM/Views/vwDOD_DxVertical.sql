



/***********************************************************
MODIFICATIONS:
	2022-02-23	CLB Created initial view for DOD STORM data coming from JVPN transfer
	2022-03-01	RAS	Formatting and removed extra subquery
***********************************************************/

CREATE VIEW [ORM].[vwDOD_DxVertical]
AS


SELECT MVIPersonSID
	  ,DxCategory
FROM (
	SELECT 
		MVIPersonSID
		,SleepApnea
		,SedativeUseDisorder
		,SEDATEISSUE
		,PTSD
		,OVERDOSE_SUICIDE
		,OtherSUD_RiskModel
		,OTHER_MH_STORM
		,Osteoporosis
		,OUD
		,NICdx_poss
		,MDD
		,EH_WEIGHTLS
		,EH_VALVDIS
		,EH_UNCDIAB
		,EH_RHEUMART
		,EH_RENAL
		,EH_PULMCIRC
		,EH_PERIVALV
		,EH_PEPTICULC
		,EH_PARALYSIS
		,EH_OTHNEURO
		,EH_OBESITY
		,EH_NMETTUMR
		,EH_METCANCR
		,EH_LYMPHOMA
		,EH_LIVER
		,EH_HYPOTHY
		,EH_HYPERTENS
		,EH_HEART
		,EH_ELECTRLYTE
		,EH_DefANEMIA
		,EH_COMDIAB
		,EH_COAG
		,EH_CHRNPULM
		,EH_BLANEMIA
		,EH_ARRHYTH
		,EH_AIDS
		,CocaineUD_AmphUD
		,CannabisUD_HallucUD	
		,AUD_ORM
		,BIPOLAR
		FROM [ORM].[vwDOD_TriSTORM]
		) p
UNPIVOT (Flag FOR DxCategory IN (
	   SleepApnea
	  ,SedativeUseDisorder
      ,SEDATEISSUE
      ,PTSD
      ,OVERDOSE_SUICIDE
      ,OtherSUD_RiskModel
      ,OTHER_MH_STORM
      ,Osteoporosis
      ,OUD
      ,NICdx_poss
      ,MDD
      ,EH_WEIGHTLS
      ,EH_VALVDIS
      ,EH_UNCDIAB
      ,EH_RHEUMART
      ,EH_RENAL
      ,EH_PULMCIRC
      ,EH_PERIVALV
      ,EH_PEPTICULC
      ,EH_PARALYSIS
      ,EH_OTHNEURO
      ,EH_OBESITY
      ,EH_NMETTUMR
      ,EH_METCANCR
      ,EH_LYMPHOMA
      ,EH_LIVER
      ,EH_HYPOTHY
      ,EH_HYPERTENS
      ,EH_HEART
      ,EH_ELECTRLYTE
      ,EH_DefANEMIA
      ,EH_COMDIAB
      ,EH_COAG
      ,EH_CHRNPULM
      ,EH_BLANEMIA
      ,EH_ARRHYTH
      ,EH_AIDS
      ,CocaineUD_AmphUD
      ,CannabisUD_HallucUD	
      ,AUD_ORM
      ,BIPOLAR
	  )
	  ) AS unpvt
WHERE Flag = 1