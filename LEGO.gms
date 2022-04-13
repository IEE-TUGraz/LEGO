$Title Low-carbon Electricity Generation Optimization (LEGO) model

$OnText

Developed by

   Sonja Wogrin
   wogrin@tugraz.at
   Diego Alejandro Tejada Arango
   dtejada@comillas.edu
   
Contributors
   Thomas Klatzer
   thomas.klatzer@tugraz.at
   Robert Gaugl
   robert.gaugl@tugraz.at

Version: 2021-06
Integrated version including: DSM + TEP (SOCP) + H2 (Basic)
Code Folding works with GAMS Studio version 32 or newer
(Fold all: Alt+O; Unfold all: Shift+Alt+O)

$OffText


*-------------------------------------------------------------------------------
*                                 Options
*-------------------------------------------------------------------------------
* definition of symbol for comments at the end of the line
$EOLCOM //

$onFold // Options -------------------------------------------------------------

$OnEmpty OnMulti OffListing

* checking user 1 definition
$if %gams.user1% == "" $log user1 not defined
$if %gams.user1% == "" $stop

* Default values for command parameters
$if not set BatchUpdate $set BatchUpdate "0"
$if not set RelaxedMIP  $set RelaxedMIP  "0"
$if not set EnableSOCP  $set EnableSOCP  "0"
$if not set RegretCalc  $set RegretCalc  "0"

* optimizer definition
option   lp   = cplex ;
option  mip   = cplex ;
option rmip   = cplex ;
option rmiqcp = cplex ;
option  miqcp = cplex ;

* general options
option optcr    =   1e-3 ;   // tolerance to solve MIP until IntGap < OptcR
option reslim   =   3600 ;   // maximum run time [sec]
option threads  =     -1 ;   // number of cores
option solprint =    on  ;   // print the final solution in the .lst file
option limrow   =    100 ;   // maximum number of equations in the .lst file
option limcol   =    100 ;   // maximum number of variables in the .lst file
option savepoint=      0 ;   // save into a gdx file solution (0=no save, 1=only the last one, 2=for each solve)

* profile options
option profile=1, profileTol = 0.01 ;

$offFold


*-------------------------------------------------------------------------------
*                                Definitions
*-------------------------------------------------------------------------------
$onFold // Sets ----------------------------------------------------------------
sets
* sets to preserve chronology
   p                "               periods                           "

* sets for representative periods model
   rp               "                           representative periods"
   k                "periods      inside a      representative period "
   hindex(p,rp,k)   "relation among periods and representative periods"
   rpk   (  rp,k)   "active                     representative periods"

* sets for thermal units, hydro units, renewables and reservoirs
   g                "generating unit                                  "
   t    (g    )     "thermal    unit                                  "
   s    (g    )     "storage    unit                                  "
   r    (g    )     "variable renewable energy sources                "
   v    (g    )     "virtual  generators                              "
   ga   (g    )     "active   generators                              "
   facts(g    )     "FACTS for reactive power sources                 "
   tec              "generation technologies                          "
   gtec (g,tec)     "relation among generation and technologies       "

* sets for transmission network
   i                "node i                                           "
   c                "circuit c                                        "
   is    (i    )    "               slack bus                         "
   iact  (i    )    "active nodes for balance constraints             "
   la    (i,i,c)    "all       transmission lines                     "
   le    (i,i,c)    "existing  transmission lines                     "
   lc    (i,i,c)    "candidate transmission lines                     "
   isLine(i,i  )    "transmission line connecting nodes i,j           "
   isLc  (i,i  )    "transmission candidate line connecting nodes i,j "
   isLe  (i,i  )    "transmission existing  line connecting nodes i,j "
   gi    (g,i  )    "generator g connected to node i                  "

* sets for segments in the cycle aging cost function
   a                "segments in the cycle aging cost   function      "
   cdsf  (g)        "storage with a  Cycle Depth Stress Function      "

* sets for RoCoF
   m                "Blocks for linearizing integer investment variable"

* sets for demand-side management
   sec              "Sectors for DSM shifting                         "
   seg              "Segments for price-responsive DSM                "
   dsm (rp,k,k,sec) "periods within rp that are related in DSM shift  "

* sets for hydrogen
   h2sec                "Sectors of hydrogen demand              "
   h2tec                "Hydrogen generating technologies        "
   h2i                  "Node of hydrogen pipeline network       "
   h2u                  "Hydrogen units                          "
   h2g     (h2u      )  "Subset of hydrogen generating units     "
   h2f     (h2u      )  "Subset of hydrogen fuel cell unis       "
   h2s     (h2u      )  "Subset of hydrogen storage units        "
   h2gh2i  (h2u,h2i  )  "Unit h2u connected to node h2i          "
   h2gi    (h2u,  i  )  "Unit h2u connected to bus i             "
   h2line  (h2i,h2i  )  "Node of hydrogen pipeline network       "
   h2uh2tec(h2u,h2tec)  "relation among H2 units and technologies"
;
alias (i,j), (t,tt), (rp,rpp), (k,kk), (p,pp), (r,rr), (v,vv), (k,kk), (c,cc),(h2i,h2j)
;
;
$offFold

$onFold // Parameters ----------------------------------------------------------

parameters
* general parameters
   pENSCost                 "energy non-served cost         [M$/GWh]  " / 1e4  /
   p2ndResUpCost            "cost factor of up   2nd reserve[p.u.]    " / 0.2  /
   p2ndResDwCost            "cost factor of down 2nd reserve[p.u.]    " / 0.2  /
   p2ndResUp                "     needs  of up   2nd reserve[%]       " / 0.02 /
   p2ndResDw                "     needs  of down 2nd reserve[%]       " / 0.02 /
   pMinInertia              "minimum required inertia       [s]       " / 0    /
   pMinGreenProd            "minimum green production       [p.u.]    " / 0    /
   pBigM_Flow               "big-M constant                           " / 1e3  /
   pBigM_SOCP               "big-M constant                           " / 1e3  /
   pMinFirmCap              "minimum firm capacity          [p.u.]    " / 0    /
   pkWh_Mcal                "conversion factor kWh and Mcal [kWh/Mcal]" / 1.162/

* generation units parameters
   pEFOR        (g)         "EFOR                           [p.u.]    "
   pExisUnits   (g)         "existing thermal units         [0-N]     "
   pMaxProd     (g)         "maximum output                 [GW]      "
   pMinProd     (g)         "minimum output                 [GW]      "
   pRampUp      (g)         "ramp up limit                  [GW]      "
   pRampDw      (g)         "ramp dw limit                  [GW]      "
   pMaxGenQ     (g)         "maximum reactive power output  [Gvar]    "
   pMinGenQ     (g)         "minimum reactive power output  [Gvar]    "
   pMaxCons     (g)         "maximum consumption            [GW]      "
   pEffic       (g)         "efficiency of the unit         [p.u.]    "
   pInertiaConst(g)         "inertia constant H             [s]       "
   pSlopeVarCost(g)         "slope     variable cost        [M$/GWh]  "
   pInterVarCost(g)         "intercept variable cost        [M$/  h]  "
   pStartupCost (g)         "startup            cost        [M$]      "
   pStartupCons (g)         "startup            consumption [GWh]     "
   pMinReserve  (g)         "minimum reserve                [p.u.]    "
   pIniReserve  (g)         "initial reserve                [GWh]     "
   pProdFacRes  (g)         "reservoir production function  [GWh/km3] "
   pProdFunct   (g)         "hydrogen  production function  [GWh/km3] "
   pDisEffic    (g)         "discharge  efficiency          [p.u.]    "
   pChEffic     (g)         "   charge  efficiency          [p.u.]    "
   pIniUC       (g)         "initial commitment             [0-1]     "
   pIsHydro     (g)         "hydro unit identifier          [0-1]     "
   pEnabInv     (g)         "enable investment              [0-1]     "
   pInvestCost  (g)         "investment cost                [M$/GW/y] "
   pOMVarCost   (g)         "O&M variable cost              [M$/GWh]  "
   pMaxInvest   (g)         "maximum investment capacity    [GW]      "
   pE2PRatio    (g)         "energy to power ratio          [h]       "
   pFirmCapCoef (g)         "firm capacity contribution     [p.u.]    "

* parameters for modeling demand-side management
   pMaxUpDSM    (rp,k,i,sec) "Bound on demand-side man. up   [GW]      "
   pMaxDnDSM    (rp,k,i,sec) "Bound on demand-side man. down [GW]      "
   pDSMShiftCost(rp,k,i)     "Cost of shifting DSM           [M$/GWh]  "
   pDSMShedCost (seg   )     "Cost of price-responsive DSM   [M$/GWh]  "
   pDSMShedRatio(seg   )     "Percentage of shedding DSM     [p.u.]    "
   pDelayTime   (sec,rp)     "Delay time for DSM shifting    [h]       "

* parameters for cycle aging cost of batteries
   pReplaceCost (  g  )     "Battery cell replacement cost  [M$/GWh]     "
   pShelfLife   (  g  )     "Battery shelf life             [years]      "
   pCDSF_alpha  (  g  )     "Cycle Depth Stress Function - alpha         "
   pCDSF_beta   (  g  )     "Cycle Depth Stress Function - beta          "
   pCDSF_delta  (p,g  )     "Cycle Depth Stress Function - delta         "
   pCDSF_phi    (  g,a)     "Cycle Depth Stress Function - phi           "
   pCDSF_cost   (  g,a)     "Marginal aging cost of cycle depth segment a"

* parameters for inertia modeling using RoCoF
   pBaseFreq                "Base frequency [Hz]                     " /50/
   pMaxRoCoF                "Maximum permissible RoCoF [Hz/s]        " /2 /
   pUBLin                   "Upper bound needed for linearization    " /1e3/
   pDeltaP      (rp,k    )  "Size of power outage in time rp,k [p.u.]"

* representative periods parameters
   pDemandP     (rp,k,i  )  "hourly active   demand per node[GW]  "
   pDemandQ     (rp,k,i  )  "hourly reactive demand per node[GW]  "
   pPeakDemand              "active peak demand             [GW]  "
   pInflows     (rp,k,g  )  "inflows for hydro storage      [GWh] "
   pResProfile  (rp,k,i,g)  "maximum renewable production   [GW]  "
   pWeight_rp   (rp      )  "representatives periods weight [h]   "
   pWeight_k    (k       )  "hourly weight for each rp      [h]   "
   pMovWind                 "Moving window for inter-period [h]   "

* bus parameters
   pBusBaseV   (i)       "Base            voltaje at bus i   [kV  ]"
   pBusMaxV    (i)       "maximum         voltage at bus i   [p.u.]"
   pBusMinV    (i)       "minimum         voltage at bus i   [p.u.]"
   pBus_pf     (i)       "power factor            at bus i   [p.u.]"
   pBusB       (i)       "Suceptance  B connected at bus i   [p.u.]"
   pBusG       (i)       "Conductance G connected at bus i   [p.u.]"
   pRatioDemQP (i)       "tan(arccos(pf)) = Q/P   at bus i   [p.u.]"

* network parameters
   pMaxAngleDiff         "maximum voltage angle difference   [rad  ]"
   pSlackVolt            "slack bus reference voltage        [p.u. ]"
   pSBase                "base power                         [MVA  ]"
   pYBUS       (i,i    ) "susceptance matrix                 [p.u. ]"
   pYBUSInv    (i,i    ) "susceptance matrix inverse         [p.u. ]"
   pPmax       (i,i,c  ) "maximum Active   Power Transfer    [GW   ]"
   pQmax       (i,i,c  ) "maximum Reactive Power Transfer    [GWvar]"
   pISF        (i,i,c,i) "injection Shift Factors            [p.u. ]"
   pXline      (i,i,c  ) "reactance  X of line               [p.u. ]"
   pRline      (i,i,c  ) "resistance R of line               [p.u. ]"
   pZline      (i,i,c  ) "line Impedance   Z                 [p.u. ]"
   pBline      (i,i,c  ) "line Suceptance  B                 [p.u. ]"
   pGline      (i,i,c  ) "line Conductance G                 [p.u. ]"
   pBcline     (i,i,c  ) "Branch charging susceptance        [p.u. ]"
   pRatio      (i,i,c  ) "transformer ratio       on         [p.u. ]"
   pAngle      (i,i,c  ) "transformer angle shift on         [rad  ]"
   pFixedCost  (i,i,c  ) "Annual Fixed Investment Cost       [M$   ]"

* option parameters
   pRMIP                 "solve model as RMIP 0->No, 1->Yes       " /0/
   pTransNet             "option to include transmission network  " /0/
   pRegretCalc           "parameter to calculate regret           " /0/
   pEnableSOCP           "Enable SOCP constraints 1->Yes 0->DC    " /0/
   pEnableDummyModel     "Enable Dummy Model to calculate angles  " /0/
   pEnableCDSF           "Enable Cycle Depth Stress Function      " /0/
   pEnableRoCoF          "Enable RoCoF constraints and variables  " /0/
   pEnableH2             "Enable Hydrogen constraints             " /0/
   pEnableCO2            "Enable CO2      constraints             " /0/
   pRoCoFRegret          "Calcluate RoCoF regret                  " /0/
   pDSM                  "Enable demand-side management           " /0/

* hydrogen parameters
   pH2Demand    (rp,k,h2i,h2sec) "Hydrogen demand per sector                     [t      ]"
   pH2PE        (         h2u  ) "Hydrogen per unit of energy - unit efficiency  [t /GWh ]"
   pH2OMPercent (         h2u  ) "O&M variable cost percentage of CAPEX          [p.u.   ]"
   pH2OMVarCost (         h2u  ) "O&M variable cost of  hydrogen unit            [M$/GW/y]"
   pH2InvestCost(         h2u  ) "Investment   cost for hydrogen unit            [M$/GW/y]"
   pH2MaxCons   (         h2u  ) "Technical maximum consumption of hydrogen unit [   GW  ]"
   pH2MaxInvest (         h2u  ) "Maximum investment of hydrogen units           [0-N    ]"
   pH2ExisUnits (         h2u  ) "number of existing    hydrogen units           [0-N    ]"
   pH2_pf       (         h2u  ) "power factor          of hydrogen unit         [p.u.   ]"
   pH2RatioQP   (         h2u  ) "tan(arccos(pf)) = Q/P of hydrogen unit         [p.u.   ]"
   pH2Fmax      (     h2i,h2i  ) "maximum hydrogen flow                          [t      ]"
   pH2NSCost                     "cost of hydrogen not served                    [M$ /t  ]"
   
* CO2 parameters
   pCO2Emis     (g             ) "Specific CO2 emissions per generator           [MtCO2/GWh  ]"
   pCO2Price                     "CO2-price                                      [M$   /MtCO2]"
   pCO2Budget                    "Total emission budget                          [MtCO2/y    ]"
   pCO2Penalty                   "CO2-penalty for CO2 budget violation           [M$   /MtCO2]"

* parameters for ex-post calculations
   pSummary         (*             ) "Model summary results                    "
   pCommit          (p,g           ) "commitment of the unit            [0-1]  "
   pGenP            (p,g           ) "  active power of the unit        [MW]   "
   pGenQ            (p,g           ) "reactive power of the unit        [MVar] "
   pChrP            (p,g           ) "charging power of the unit        [MW]   "
   pCurtP_k         (rp,k,g        ) "curtailment    of the unit per k  [MW]   "
   pCurtP_rp        (rp,  g        ) "curtailment    of the unit per rp [MW]   "
   pTecProd         (i,*,*         ) "total production per tecnology    [GWh]  "
   pStIntra         (k,g,rp        ) "intra-period storage level        [p.u]  "
   pStLevel         (p,g           ) "storage level during the year     [p.u]  "
   pStLvMW          (p,g           ) "storage level moving window       [GWh]  "
   pSRMC            (p,i           ) "short run marginal cost           [$/MWh]"
   pMC              (      rp,k,i  ) "marginal cost                     [M$/GW]"
   pGenInvest       (*,*           ) "total generation investment       [MW]   "
   pTraInvest       (i,i,c,*       ) "total transmission investment     [MW]   "
   pLineP           (k,i,i,c,rp    ) "  active power flow               [MW]   "
   pLineQ           (k,i,i,c,rp    ) "reactive power flow               [MVar] "
   pVoltage         (k,i,rp        ) "bus voltage                       [p.u.] "
   pTheta           (k,i,rp        ) "Voltage angle of bus i            [º]    "
   pBusRes          (k,i,rp,*,*    ) "bus results                              "
   pDelVolAng       (rp,k,i,j      ) "Delta of voltage angle            [rad]  "
   pResulCDSF       (*,g           ) "Results for storage with CDSF            "
   pInertDual       (k,rp          ) "Dual variable of inertia constr   [$/s]  "
   pRevSpot         (           g  ) "Revenues on spot market           [M$]   "
   pRevReserve      (           g  ) "Revenues on reserve market        [M$]   "
   pRevRESQuota     (           g  ) "RES payments for quota            [M$]   "
   pFirmCapPay      (           g  ) "Payments for firm capacity        [M$]   "
   pInvCost         (           g  ) "Investment cost                   [M$]   "
   pOMCost          (           g  ) "O and M cost                      [M$]   "
   pReserveCost     (           g  ) "Cost for reserve provision        [M$]   "
   pCostSpot        (           g  ) "Cost for consumption on spot      [M$]   "
   pTotalProfits    (           g  ) "Total profits of storage s        [M$]   "
   pEconomicResults (*,         g  ) "Economic Results                  [M$]   "
   pTotalBESSProfits                 "Total battery tecn profits        [M$]   "
   pResultDSM       (rp,k,*,*,i    ) "Results DSM                       [GW]   "
   pActualSysInertia(      k ,rp   ) "actual system inertia             [s]    "
   pRoCoF_k         (      rp,k,g  ) "Scaled power gain factor of gen g [p.u.] "
   pRoCoF_SG_M      (      rp,k    ) "Scaled power gain factor of SG    [p.u.] "
   pRoCoF_VI_M      (      rp,k    ) "Scaled power gain factor of VI    [p.u.] "
   pH2price         (h2sec,k,h2i,rp) "Hydrogen price                    [$/kg] "
   pH2Invest        (h2u,*         ) "Hydrogen units investment         [  MW] "
   pH2ns            (h2sec,k,h2i,rp) "Hydrogen non served               [  kg] "
   pH2Prod          (h2u  ,k,    rp) "Hydrogen unit production          [  kg] "
   pH2Cons          (h2u  ,k,    rp) "Hydrogen unit consumption         [  MW] "
;

$offFold

$onFold // Variables -----------------------------------------------------------

variables
   vTotalVCost              "Total system variable cost                  [M$  ]"
   vDummyOf                 "Dummy objective function variable                 "
   vTheta    (rp,k,i      ) "Voltage angle  of bus i at time rp,k        [rad] "
   vLineP    (rp,k,i,i,c  ) "Real     power of line ijc                  [GW  ]"
   vLineQ    (rp,k,i,i,c  ) "Reactive power of line ijc                  [Gvar]"
   vGenQ     (rp,k,g      ) "Reactive power gen. of the unit             [Gvar]"
   vSOCP_sij (rp,k,i,i    ) "Auxiliary sij variable for SOCP formulation [p.u.]"
   vH2Flow   (rp,k,h2i,h2i) "Real     power of line ijc                  [GW  ]"
;
binary    variables
   vRoCoF_AuxI           (   g,m) "Binary variable used to express vGenInvest as sum of binaries "
   vCommit               (rp,k,g) "commitment of the unit                         [0-1]"
   vStartup              (rp,k,g) "startup    of the unit                         [0-1]"
   vShutdown             (rp,k,g) "shutdown   of the unit                         [0-1]"
   vLineInvest           (i ,j,c) "transmission line investment                   [0-1]"
   vSOCP_IndicConnecNodes(i ,i  ) "indicator variable of connection between nodes [0-1]"
;
integer   variables
   vGenInvest    (     g)  "Integer generation investment [0-N]"
   vH2Invest     (   h2u)  "Integer H2 investment         [0-N]"
;
positive variables
   vConsump        (rp,k,g        ) "consumption of the unit                     [GW  ]"
   vPNS            (rp,k,i        ) "power non served                            [GW  ]"
   vStInterRes     ( p,  g        ) "reserve at the end   inter-per              [GWh ]"
   vStIntraRes     (rp,k,g        ) "reserve at the end   intra-per              [GWh ]"
   vSpillag        (rp,k,g        ) "spillage                                    [GWh ]"
   vWaterSell      (rp,k,g        ) "water sell - slack var (regret)             [GWh ]"
   v2ndResUP       (rp,k,g        ) "2nd res. up   allocation                    [GW  ]"
   v2ndResDW       (rp,k,g        ) "2nd res. down allocation                    [GW  ]"
   vGenP           (rp,k,g        ) "Real power gen. of the unit                 [GW  ]"
   vGenP1          (rp,k,g        ) "Real power gen. of the unit > minload       [GW  ]"
   vDSM_Up         (rp,k,i,sec    ) "Demand-side managment Up (shifting)         [GW  ]"
   vDSM_Dn         (rp,k,i,sec    ) "Demand-side managment Down (shifting)       [GW  ]"
   vDSM_Shed       (rp,k,i,seg    ) "Price-responsiv Demand-side managment (shed)[GW  ]"
   vCDSF_ch        (rp,k,g,a      ) "   charge for Cycle Depth Stress Function   [GW  ]"
   vCDSF_dis       (rp,k,g,a      ) "discharge for Cycle Depth Stress Function   [GW  ]"
   vCDSF_SoC       (rp,k,g,a      ) "Soc       for Cycle Depth Stress Function   [GWh ]"
   vSOCP_cii       (rp,k,i        ) "Auxiliary cii variable for SOCP formulation [p.u.]"
   vSOCP_cij       (rp,k,i,i      ) "Auxiliary cij variable for SOCP formulation [p.u.]"
   vDummySlackP    (rp,k,i,j      ) "Slack variable for Dummy objective function       "
   vDummySlackN    (rp,k,i,j      ) "Slack variable for Dummy objective function       "
   vRoCoF_k        (rp,k,g        ) "Scaled power gain factor of gen g           [p.u.]"
   vRoCoF_SysM     (rp,k          ) "Global system inertia                       [s]   "
   vRoCoF_SG_M     (rp,k          ) "System inertia provided by synch. machines  [s]   "
   vRoCoF_VI_M     (rp,k          ) "System inertia provided by virtual gen.     [s]   "
   vRoCoF_AuxY     (rp,k,g,g      ) "variable representing the product of binary vu and continuous vk   "
   vRoCoF_AuxW     (rp,k,g,g,m    ) "variable representing the product of binary vb and continuous vk   "
   vRoCoF_AuxZ     (rp,k,g        ) "variable representing the product of binary vu and continuous vM-SG"
   vRoCoF_AuxV     (rp,k,g  ,m    ) "variable representing the product of binary vb and continuous vM-VI"
   vRoCoF_SysM_AuxZ(rp,k,g        ) "variable representing the product of binary vu and continuous vM   "
   vRoCoF_SysM_AuxV(rp,k,g,  m    ) "variable representing the product of binary vb and continuous vM   "
   vCO2Overshoot                    "slack variable for CO2 budget overshoot     [MtCO2]"
   vCO2Undershoot                   "slack variable for CO2 budget undershoot    [MtCO2]"
   vH2NS           (rp,k,h2i,h2sec) "Hydrogen non-served                         [t ]"
   vH2Prod         (rp,k,h2u      ) "Hydrogen generation of the unit             [t ]"
   vH2Consump      (rp,k,h2u      ) "Power consumption of hydrogen the unit      [GW]"
;

$offFold

$onFold // Equations -----------------------------------------------------------

equations
   eTotalVCost                 "total system variable cost                   [M$] "
* general system constraints
   eCleanProd                  "enforcing a minimum green production         [GWh]"
   eFirmCapCon                 "firm capacity constraint                     [GW ]"
   eSN_BalanceP  (rp,k,i    )  "load generation balance single node          [GW] "
   e2ReserveUp   (rp,k      )  "2nd reserve up   reserve                     [GW] "
   e2ReserveDw   (rp,k      )  "2nd reserve down reserve                     [GW] "
   eMinInertia   (rp,k      )  "minimum inertia running in the power system  [s ] "
* unit commitment constriants
   eUCMaxOut1    (rp,k,g    )  "output limit 1 of a committed unit           [GW] "
   eUCMaxOut2    (rp,k,g    )  "output limit 2 of a committed unit           [GW] "
   eUCMinOut     (rp,k,g    )  "output limit   of a committed unit           [GW] "
   eUCTotOut     (rp,k,g    )  "total output of a committed unit             [GW] "
   eUCStrShut    (rp,k,g    )  "relation among committment startup and shutdown   "
   eThRampUp     (rp,k,g    )  "ramp up limit for thermal units              [GW] "
   eThRampDw     (rp,k,g    )  "ramp dw limit for thermal units              [GW] "
   eThMaxUC      (rp,k,g    )  "maximum thermal units investment                  "
* energy storage constraints
   eStIntraRes   (rp,k,g    )  "intra-period storage reserve or SoC          [GWh]"
   eStInterRes   ( p,  g    )  "inter-period storage reserve or SoC          [GWh]"
   eStMaxProd    (rp,k,g    )  "maximum production  considering investment   [GWh]"
   eStMaxCons    (rp,k,g    )  "maximum consumption considering investment   [GWh]"
   eStMaxIntraRes(rp,k,g    )  "maximum storage level considering investment [GWh]"
   eStMinIntraRes(rp,k,g    )  "minimum storage level considering investment [GWh]"
   eStMaxInterRes( p,  g    )  "maximum storage level considering investment [GWh]"
   eStMinInterRes( p,  g    )  "minimum storage level considering investment [GWh]"
* renewable energy constraints
   eReMaxProd    (rp,k,g    )  "maximum production considering investment    [GW ]"
*  equations for DSM
   eTotalBalance_DSM(rp,  i,sec)  "total balance for DSM                     [GW ]"
   eShift_DSM       (rp,k,i,sec)  "relation DSM up and down                  [GW ]"
   eUB_DSM          (rp,k,i,sec)  "upper bound on hourly DSM                 [GW ]"
   eMaxUp_DSM       (rp,k,i,sec)  "maximum up shifting for DSM               [GW ]"
   eMaxDn_DSM       (rp,k,i,sec)  "maximum down shifting for DSM             [GW ]"
*  equations for DC power flow
   eDC_BalanceP   (rp,k,i    )  "load generation balance per    node          [GW] "
   eDC_ExiLinePij (rp,k,i,i,c)  "existing  lines DC power flow                [GW ]"
   eDC_CanLinePij1(rp,k,i,i,c)  "candidate lines DC power flow                [GW ]"
   eDC_CanLinePij2(rp,k,i,i,c)  "candidate lines DC power flow                [GW ]"
   eDC_LimCanLine1(rp,k,i,i,c)  "candidate lines DC power flow                [GW ]"
   eDC_LimCanLine2(rp,k,i,i,c)  "candidate lines DC power flow                [GW ]"
*  equations for second order cone programming (SOCP)
   eSOCP_QMaxOut          (rp,k,g    )  "max Reactive Power output of thermal unit    [Gvar]  "
   eSOCP_QMinOut1         (rp,k,g    )  "min Reactive Power output of thermal unit    [Gvar]  "
   eSOCP_QMinOut2         (rp,k,g    )  "min Reactive Power output of thermal unit    [Gvar]  "
   eSOCP_QMaxFACTS        (rp,k,g    )  "max Reactive Power output of facts   unit    [Gvar]  "
   eSOCP_QMinFACTS        (rp,k,g    )  "min Reactive Power output of facts   unit    [Gvar]  "
   eSOCP_BalanceP         (rp,k,i    )  "balance of real     power for bus            [GW]    "
   eSOCP_BalanceQ         (rp,k,i    )  "balance of reactive power for bus            [Gvar]  "
   eSOCP_ExiLinePij       (rp,k,i,i,c)  "existing line real     power flow            [GW]    "
   eSOCP_ExiLinePji       (rp,k,i,i,c)  "existing line real     power flow            [GW]    "
   eSOCP_ExiLineQij       (rp,k,i,i,c)  "existing line reactive power flow            [GW]    "
   eSOCP_ExiLineQji       (rp,k,i,i,c)  "existing line reactive power flow            [GW]    "
   eSOCP_CanLinePij1      (rp,k,i,i,c)  "candidate line real     power flow           [GW]    "
   eSOCP_CanLinePij2      (rp,k,i,i,c)  "candidate line real     power flow           [GW]    "
   eSOCP_CanLinePji1      (rp,k,i,i,c)  "candidate line real     power flow           [GW]    "
   eSOCP_CanLinePji2      (rp,k,i,i,c)  "candidate line real     power flow           [GW]    "
   eSOCP_CanLineQij1      (rp,k,i,i,c)  "candidate line reactive power flow           [GW]    "
   eSOCP_CanLineQij2      (rp,k,i,i,c)  "candidate line reactive power flow           [GW]    "
   eSOCP_CanLineQji1      (rp,k,i,i,c)  "candidate line reactive power flow           [GW]    "
   eSOCP_CanLineQji2      (rp,k,i,i,c)  "candidate line reactive power flow           [GW]    "
   eSOCP_LimCanLinePij1   (rp,k,i,i,c)  "limit of candidate line real     power flow  [GW]    "
   eSOCP_LimCanLinePij2   (rp,k,i,i,c)  "limit of candidate line real     power flow  [GW]    "
   eSOCP_LimCanLinePji1   (rp,k,i,i,c)  "limit of candidate line real     power flow  [GW]    "
   eSOCP_LimCanLinePji2   (rp,k,i,i,c)  "limit of candidate line real     power flow  [GW]    "
   eSOCP_LimCanLineQij1   (rp,k,i,i,c)  "limit of candidate line reactive power flow  [GW]    "
   eSOCP_LimCanLineQij2   (rp,k,i,i,c)  "limit of candidate line reactive power flow  [GW]    "
   eSOCP_LimCanLineQji1   (rp,k,i,i,c)  "limit of candidate line reactive power flow  [GW]    "
   eSOCP_LimCanLineQji2   (rp,k,i,i,c)  "limit of candidate line reactive power flow  [GW]    "
   eSOCP_ExiLine          (rp,k,i,i  )  "SOCP constraint for auxiliary variables      [GW]    "
   eSOCP_CanLine          (rp,k,i,i  )  "SOCP constraint for auxiliary variables      [GW]    "
   eSOCP_CanLine_cij      (rp,k,i,i  )  "SOCP constraint for auxiliary variables      [GW]    "
   eSOCP_CanLine_sij1     (rp,k,i,i  )  "SOCP constraint for auxiliary variables      [GW]    "
   eSOCP_CanLine_sij2     (rp,k,i,i  )  "SOCP constraint for auxiliary variables      [GW]    "
   eSOCP_IndicConnecNodes1(     i,i  )  "connection between nodes                             "
   eSOCP_IndicConnecNodes2(     i,i  )  "connection between nodes                             "
   eSOCP_CanLineCijUpLim  (rp,k,i,j  )  "Limits to SOCP variables for candidate lines [p.u.]  "
   eSOCP_CanLineCijLoLim  (rp,k,i,j  )  "Limits to SOCP variables for candidate lines [p.u.]  "
   eSOCP_CanLineSijUpLim  (rp,k,i,j  )  "Limits to SOCP variables for candidate lines [p.u.]  "
   eSOCP_CanLineSijLoLim  (rp,k,i,j  )  "Limits to SOCP variables for candidate lines [p.u.]  "
   eSOCP_ExiLineAngDif1   (rp,k,i,i  )  "limit on angle difference                    [p.u.]^2"
   eSOCP_ExiLineAngDif2   (rp,k,i,i  )  "limit on angle difference                    [p.u.]^2"
   eSOCP_CanLineAngDif1   (rp,k,i,i  )  "limit on angle difference                    [p.u.]^2"
   eSOCP_CanLineAngDif2   (rp,k,i,i  )  "limit on angle difference                    [p.u.]^2"
   eSOCP_ExiLineSLimit    (rp,k,i,j,c)  "line apparent power limit                    [GVA ]  "
   eSOCP_CanLineSLimit    (rp,k,i,j,c)  "line apparent power limit                    [GVA ]  "
*  equation for line investment
   eTranInves           (     i,j,c)  "order of circuits investment                 [N]"
*  equations for Cycle Depth Stress Function (CDSF)
   eCDSF_ch       (rp,k,g    )  "   charge    for Cycle Depth Stress Function [GW  ]  "
   eCDSF_dis      (rp,k,g    )  "discharge    for Cycle Depth Stress Function [GW  ]  "
   eCDSF_e        (rp,k,g    )  "Tot. energy  for Cycle Depth Stress Function [GW  ]  "
   eCDSF_SoC      (rp,k,g,a  )  "SoC  balance for Cycle Depth Stress Function [GWh ]  "
   eCDSF_MaxSoC   (rp,k,g,a  )  "Max energy   for Cycle Depth Stress Function [GWh ]  "
   eCDSF_EndSoC   (rp,k,g    )  "End energy   for Cycle Depth Stress Function [GWh ]  "
*  equations for Rate of Change of Frequency (RoCoF)
   eRoCoF_ThEq1   (rp,k,  g  )  "linear equation for RoCoF including investment       "
   eRoCoF_ThEq2   (rp,k,g,g  )  "linear equation for RoCoF including investment       "
   eRoCoF_ThEq3   (rp,k,g,g  )  "linear equation for RoCoF including investment       "
   eRoCoF_ThEq4   (rp,k,g,g  )  "linear equation for RoCoF including investment       "
   eRoCoF_ThEq5   (rp,k,g    )  "linear equation for RoCoF including investment       "
   eRoCoF_ThEq6   (rp,k,g    )  "linear equation for RoCoF including investment       "
   eRoCoF_ThEq7   (rp,k,g    )  "linear equation for RoCoF including investment       "
   eRoCoF_ThEq8   (rp,k,g    )  "linear equation for RoCoF including investment       "
   eRoCoF_ThEq9   (rp,k,g    )  "linear equation for RoCoF including investment       "
   eRoCoF_ThEq10  (rp,k,g    )  "linear equation for RoCoF including investment       "
   eRoCoF_ThEq11  (rp,k,g    )  "linear equation for RoCoF including investment       "
   eRoCoF_VgEq1   (rp,k,  g  )  "linear equation for RoCoF including investment       "
   eRoCoF_VgEq2   (rp,k,g,g,m)  "linear equation for RoCoF including investment       "
   eRoCoF_VgEq3   (rp,k,g,g,m)  "linear equation for RoCoF including investment       "
   eRoCoF_VgEq4   (rp,k,g,g,m)  "linear equation for RoCoF including investment       "
   eRoCoF_VgEq5   (rp,k,g  ,m)  "linear equation for RoCoF including investment       "
   eRoCoF_VgEq6   (rp,k,g  ,m)  "linear equation for RoCoF including investment       "
   eRoCoF_VgEq7   (rp,k,g  ,m)  "linear equation for RoCoF including investment       "
   eRoCoF_VgEq8   (     g    )  "linear equation for RoCoF including investment       "
   eRoCoF_VgEq9   (rp,k,g  ,m)  "linear equation for RoCoF including investment       "
   eRoCoF_VgEq10  (rp,k,g  ,m)  "linear equation for RoCoF including investment       "
   eRoCoF_VgEq11  (rp,k,g  ,m)  "linear equation for RoCoF including investment       "
   eRoCoF_SyEq1   (rp,k      )  "linear equation for RoCoF including investment       "
   eRoCoF_SyEq2   (rp,k      )  "linear equation for RoCoF including investment       "
   eRoCoF_SyEq3   (rp,k      )  "linear equation for RoCoF including investment       "
   eRoCoF_SyEq4   (rp,k      )  "linear equation for RoCoF including investment       "
   eRoCoF_SyEq5   (rp,k      )  "linear equation for RoCoF including investment       "
*  equations for hydrogen
   eH2_MaxProd    (rp,k,h2u      )  "H2 production limit of hydrogen unit   [t ]      "
   eH2_MaxCons    (rp,k,h2u      )  "H2 cosumption limit of hydrogen unit   [GW]      "
   eH2_Convers    (rp,k,h2u      )  "conversion from energy to H2           [t ]      "
   eH2_Balance    (rp,k,h2i,h2sec)  "H2 balance at each hydrogen node       [t ]      "
*  equations for CO2
   eCO2_Budget                 "CO2 Budget constraint                       [MtCO2]   "
*  equations for ex-post calculation of voltage angles in SOCP
   eDummyOf                    "Dummy objective function                              "
   eDummyAngDiff  (rp,k,i,j  ) "Dummy equation for voltage angle difference [rad]     "
;

$offFold


*-------------------------------------------------------------------------------
*                          Mathematical Formulation
*-------------------------------------------------------------------------------
$onFold // Objective Function --------------------------------------------------
eTotalVCost..
   vTotalVCost =e=
* operational costs
   + sum[(rpk(rp,k),i        ), pWeight_rp(rp)*pWeight_k(k)*pENSCost             * vPNS         (rp,k,i)    ]
   + sum[(rpk(rp,k),i,seg    ), pWeight_rp(rp)*pWeight_k(k)*pDSMShedCost(seg)    * vDSM_Shed    (rp,k,i,seg)]
   + sum[(rpk(rp,k),i,sec    ), pWeight_rp(rp)*pWeight_k(k)*pDSMShiftCost(rp,k,i)* vDSM_Dn      (rp,k,i,sec)]
   + sum[(rpk(rp,k),s        ), pWeight_rp(rp)*pWeight_k(k)*pENSCost/2           *[vSpillag     (rp,k,s)+vWaterSell(rp,k,s)$[pRegretCalc]]]
   + sum[(rpk(rp,k),t        ), pWeight_rp(rp)*pWeight_k(k)*pStartupCost (t)     * vStartup     (rp,k,t)    ]
   + sum[(rpk(rp,k),t        ), pWeight_rp(rp)*pWeight_k(k)*pInterVarCost(t)     * vCommit      (rp,k,t)    ]
   + sum[(rpk(rp,k),t        ), pWeight_rp(rp)*pWeight_k(k)*pSlopeVarCost(t)     * vGenP        (rp,k,t)    ]
   + sum[(rpk(rp,k),s        ), pWeight_rp(rp)*pWeight_k(k)*pOMVarCost   (s)     * vGenP        (rp,k,s)    ]
   + sum[(rpk(rp,k),r        ), pWeight_rp(rp)*pWeight_k(k)*pOMVarCost   (r)     * vGenP        (rp,k,r)    ]
* CO2 operational costs   
   + sum[(rpk(rp,k),t        ), pWeight_rp(rp)*pWeight_k(k)*pCO2Price*pCO2Emis(t)*pEffic(t)                 * vGenP   (rp,k,t)] $[pEnableCO2]
   + sum[(rpk(rp,k),t        ), pWeight_rp(rp)             *pCO2Price*pCO2Emis(t)*pEffic(t)*pStartupCons(t) * vStartup(rp,k,t)] $[pEnableCO2] 
   +                                                        pCO2Penalty          * vCO2Overshoot                                $[pEnableCO2]  
* hydrogen operational costs
   + sum[           h2u       ,                             pH2OMVarCost (h2u)   * vH2Invest    (     h2u      )] $[pEnableH2]
   + sum[(rpk(rp,k),h2i,h2sec), pWeight_rp(rp)*pWeight_k(k)*pH2NSCost            * vH2NS        (rp,k,h2i,h2sec)] $[pEnableH2]
* cycle aging costs
   + sum[(rpk(rp,k),s,a)$[cdsf(s)],
                        pWeight_rp(rp)*pWeight_k(k)*pCDSF_Cost(s,a)  * vCDSF_dis(rp,k,s,a)]
* reserve costs
   + sum[(rpk(rp,k),t), pWeight_rp(rp)*pWeight_k(k)*pSlopeVarCost(t) *
                                                    p2ndResUpCost    * v2ndResUP(rp,k,t)]
   + sum[(rpk(rp,k),t), pWeight_rp(rp)*pWeight_k(k)*pSlopeVarCost(t) *
                                                    p2ndResDwCost    * v2ndResDW(rp,k,t)]
   + sum[(rpk(rp,k),s), pWeight_rp(rp)*pWeight_k(k)*pOMVarCost   (s) *
                                                    p2ndResUpCost    * v2ndResUP(rp,k,s)]
   + sum[(rpk(rp,k),s), pWeight_rp(rp)*pWeight_k(k)*pOMVarCost   (s) *
                                                    p2ndResDwCost    * v2ndResDW(rp,k,s)]
* generation   investment costs
   + sum[ga(g    ), pInvestCost  (g    )* vGenInvest (g    )]
* transmission investment costs
   + sum[lc(i,j,c), pFixedCost   (i,j,c)* vLineInvest(i,j,c)]
* hydrogen investment costs
   + sum[h2u      , pH2InvestCost(h2u  )* vH2Invest  (h2u  )] $[pEnableH2]
;
$offFold

$onFold // Power System Equations ----------------------------------------------

eSN_BalanceP(rpk(rp,k),iact(i))$[not pTransNet]..
   + sum[gi (t,j)   , vGenP     (rp,k,t)]
   + sum[gi (r,j)   , vGenP     (rp,k,r)]
   + sum[gi (s,j)   , vGenP     (rp,k,s)]
   - sum[gi (s,j)   , vConsump  (rp,k,s)]
   +                  vPNS      (rp,k,i)
   + sum[     seg   , vDSM_Shed (rp,k,i,seg)] $[pDSM     ]
   + sum[     sec   , vDSM_Dn   (rp,k,i,sec)] $[pDSM     ]
  =e=
   + sum[      j    , pDemandP  (rp,k,j)]
   + sum[     sec   , vDSM_Up   (rp,k,i,sec)] $[pDSM     ]
   + sum[h2gi(h2g,i), vH2Consump(rp,k,h2g  )] $[pEnableH2]
;

e2ReserveUp(rpk(rp,k))$[p2ndResUp].. sum[t, v2ndResUP(rp,k,t)] + sum[s, v2ndResUP(rp,k,s)] =g= p2ndResUp * sum[i, pDemandP(rp,k,i)] ;
e2ReserveDw(rpk(rp,k))$[p2ndResDw].. sum[t, v2ndResDW(rp,k,t)] + sum[s, v2ndResDW(rp,k,s)] =g= p2ndResDw * sum[i, pDemandP(rp,k,i)] ;

$offFold

$onFold // Demand-side Management ----------------------------------------------

eTotalBalance_DSM(rp,iact(i),sec)$[pDSM] ..
                       + sum[k$[rpk(rp,k)], vDSM_Up(rp,k,i,sec)]
                       - sum[k$[rpk(rp,k)], vDSM_Dn(rp,k,i,sec)]
                       =e= 0;

eShift_DSM(rpk(rp,k),iact(i),sec)  $[pDSM] .. vDSM_Up(rp,k,i,sec) =l= sum[kk $[dsm(rp,k,kk,sec)], vDSM_Dn(rp,kk,i,sec)];

eUB_DSM   (rpk(rp,k),iact(i),sec)  $[pDSM] .. vDSM_Up(rp,k,i,sec) + vDSM_Dn(rp,k,i,sec)  =l=
                                                 +       max(pMaxUpDSM(rp,k,i,sec), pMaxDnDSM(rp,k,i,sec))  $[    pTransNet]
                                                 + sum[j,max(pMaxUpDSM(rp,k,j,sec), pMaxDnDSM(rp,k,j,sec))] $[not pTransNet];

eMaxUp_DSM (rpk(rp,k),iact(i),sec) $[pDSM] .. vDSM_Up(rp,k,i,sec) =l= pMaxUpDSM (rp,k,i,sec);

eMaxDn_DSM (rpk(rp,k),iact(i),sec) $[pDSM] .. vDSM_Dn(rp,k,i,sec) =l= pMaxDnDSM (rp,k,i,sec);

$offFold

$onFold // Unit Commitment Constraints -----------------------------------------

eUCMaxOut1(rpk(rp,k),t)..
   + vGenP1   (rp,k,t)
   + v2ndResUP(rp,k,t)
  =l=
   + [pMaxProd(t)-pMinProd(t)] * [vCommit (rp,k,t)
                                 -vStartup(rp,k,t)]
;

eUCMaxOut2(rpk(rp,k),t)..
   + vGenP1   (rp,k,t)
   + v2ndResUP(rp,k,t)
  =l=
   + [pMaxProd(t)-pMinProd(t)] * [vCommit  (rp,k   ,t)
                                 -vShutdown(rp,k++1,t)]
;

eUCMinOut (rpk(rp,k),t)..
   + vGenP1   (rp,k,t)
   - v2ndResDW(rp,k,t)
  =g=
   0
;

eUCTotOut(rpk(rp,k),t)..
   + vGenP   (rp,k,t)
  =e=
   + vCommit (rp,k,t) * pMinProd(t)
   + vGenP1  (rp,k,t)
;

eUCStrShut(rpk(rp,k)  ,t)..
   + vCommit  (rp,k   ,t)
   - vCommit  (rp,k--1,t)
  =e=
   + vStartup (rp,k   ,t)
   - vShutdown(rp,k   ,t)
;

eThRampUp (rpk(rp,k)  ,t)..
   + vGenP1   (rp,k   ,t)
   - vGenP1   (rp,k--1,t)
   + v2ndResUP(rp,k   ,t)
  =l=
   + vCommit  (rp,k   ,t) *  pRampUp (t)
;

eThRampDw (rpk(rp,k)  ,t)..
   + vGenP1   (rp,k   ,t)
   - vGenP1   (rp,k--1,t)
   - v2ndResDW(rp,k   ,t)
  =g=
   - vCommit  (rp,k--1,t) *  pRampDw (t)
;

eThMaxUC  (rpk(rp,k)  ,t)..
   + vCommit  (rp,k   ,t) =l= vGenInvest(t) + pExisUnits(t) ;

$offFold

$onFold // Storage Units Constraints -------------------------------------------

eStIntraRes(rpk(rp,k),   s) $[[card(rp)=1] or [card(rp)>1 and not pIsHydro(s)] and not cdsf(s)]..
   + vStIntraRes(rp,k--1,s) $[ card(rp)>1             ]
   + vStIntraRes(rp,k- 1,s) $[ card(rp)=1             ]
   + pIniReserve(        s) $[ card(rp)=1 and ord(k)=1]
   - vStIntraRes(rp,k   ,s)
   - vSpillag   (rp,k   ,s)                $[pIsHydro (s)]
   + pInflows   (rp,k   ,s) * pWeight_k(k) $[pIsHydro (s)]
   - vGenP      (rp,k   ,s) * pWeight_k(k) / pDisEffic(s)
   + vConsump   (rp,k   ,s) * pWeight_k(k) * pChEffic (s)
   + vWaterSell (rp,k   ,s) $[pRegretCalc and pIsHydro(s)]
  =e=
   0
;

eStInterRes     (p         ,s) $[[card(rp)>1] and [mod(ord(p),pMovWind)=0]]..
   + vStInterRes(p-pMovWind,s)
   + pIniReserve(           s) $[ord(p)=pMovWind]
   - vStInterRes(p         ,s)
   + sum[hindex(pp,rpk(rp,k))$[[ord(pp)>  ord(p)-pMovWind] and
                              [ ord(pp)<= ord(p)         ]],
        - vSpillag (rp,k,s)                $[pIsHydro (s)]
        + pInflows (rp,k,s) * pWeight_k(k) $[pIsHydro (s)]
        - vGenP    (rp,k,s) * pWeight_k(k) / pDisEffic(s)
        + vConsump (rp,k,s) * pWeight_k(k) * pChEffic (s)
        ]
  =e=
   0
;

eStMaxProd    (rpk(rp,k),s).. vGenP(rp,k,s) - vConsump(rp,k,s) + v2ndResUP(rp,k,s) =l=  pMaxProd(s)*[vGenInvest(s)+ pExisUnits(s)] ;
eStMaxCons    (rpk(rp,k),s).. vGenP(rp,k,s) - vConsump(rp,k,s) - v2ndResDW(rp,k,s) =g= -pMaxCons(s)*[vGenInvest(s)+ pExisUnits(s)] ;

eStMaxIntraRes(rpk(rp,k),s).. vStIntraRes(rp,k,s) =l= pMaxProd(s)*[vGenInvest(s)+pExisUnits(s)] * pE2PRatio(s)                  - [v2ndResDW(rp,k,s)+v2ndResDW(rp,k--1,s)] * pWeight_k(k) ;
eStMinIntraRes(rpk(rp,k),s).. vStIntraRes(rp,k,s) =g= pMaxProd(s)*[vGenInvest(s)+pExisUnits(s)] * pE2PRatio(s) * pMinReserve(s) + [v2ndResUP(rp,k,s)+v2ndResUP(rp,k--1,s)] * pWeight_k(k) ;

eStMaxInterRes(p,s)$[mod(ord(p),pMovWind)=0].. vStInterRes(p,s) =l= pMaxProd(s)*[vGenInvest(s)+pExisUnits(s)] * pE2PRatio(s)                 ;
eStMinInterRes(p,s)$[mod(ord(p),pMovWind)=0].. vStInterRes(p,s) =g= pMaxProd(s)*[vGenInvest(s)+pExisUnits(s)] * pE2PRatio(s) * pMinReserve(s);

$offFold

$onFold // Renewable Energy Constraints ----------------------------------------

eReMaxProd(rpk(rp,k),r)..
   + vGenP(rp,k,r) =l= sum[gi(r,i),[pMaxProd(r)*[vGenInvest(r)+pExisUnits(r)]]*pResProfile(rp,k,i,r)]
;
eCleanProd..
   + sum[rpk(rp,k),pWeight_rp(rp)*pWeight_k(k)*sum[gi(t,j), vGenP   (rp,k,t)]]
  =l=
   + [1-pMinGreenProd]
   * sum[rpk(rp,k),pWeight_rp(rp)*pWeight_k(k)*sum[     j , pDemandP(rp,k,j)]]
;
eFirmCapCon..
   + sum[g$ga(g), pFirmCapCoef(g)*pMaxProd(g)*[vGenInvest(g)+pExisUnits(g)]]
   =g= pMinFirmCap*pPeakDemand
;
$offFold

$onFold // Rate of Change of Frequency (RoCoF) ---------------------------------

* default constraints when we are not using RoCoF contraints
eMinInertia(rpk(rp,k))$[not pEnableRoCoF and pMinInertia].. sum[t, vCommit(rp,k,t)*pInertiaConst(t)] =g= pMinInertia ;

* Linear constraints to consider RoCoF inertia constraints including investment
eRoCoF_ThEq1 (rpk(rp,k),   t  )$[pEnableRoCoF]..sum[tt,pMaxProd(tt)*vRoCoF_AuxY(rp,k,tt,t)] =e= vCommit    (rp,k,t )* pMaxProd(t)                ;
eRoCoF_ThEq2 (rpk(rp,k),tt,t  )$[pEnableRoCoF]..                    vRoCoF_AuxY(rp,k,tt,t)  =l= vCommit    (rp,k,tt)                             ;
eRoCoF_ThEq3 (rpk(rp,k),tt,t  )$[pEnableRoCoF]..                    vRoCoF_AuxY(rp,k,tt,t)  =l= vRoCoF_k   (rp,k,t )                             ;
eRoCoF_ThEq4 (rpk(rp,k),tt,t  )$[pEnableRoCoF]..                    vRoCoF_AuxY(rp,k,tt,t)  =g= vRoCoF_k   (rp,k,t )-       [1-vCommit(rp,k,tt)] ;
eRoCoF_ThEq5 (rpk(rp,k),tt    )$[pEnableRoCoF]..                    vRoCoF_AuxZ(rp,k,tt  )  =l= vCommit    (rp,k,tt)*pUBLin                      ;
eRoCoF_ThEq6 (rpk(rp,k),tt    )$[pEnableRoCoF]..                    vRoCoF_AuxZ(rp,k,tt  )  =l= vRoCoF_SG_M(rp,k   )                             ;
eRoCoF_ThEq7 (rpk(rp,k),tt    )$[pEnableRoCoF]..                    vRoCoF_AuxZ(rp,k,tt  )  =g= vRoCoF_SG_M(rp,k   )-pUBLin*[1-vCommit(rp,k,tt)] ;
eRoCoF_ThEq8 (rpk(rp,k),tt    )$[pEnableRoCoF]..                    vRoCoF_k   (rp,k,tt  )  =l= vCommit    (rp,k,tt)                             ;
eRoCoF_ThEq9 (rpk(rp,k),tt    )$[pEnableRoCoF]..               vRoCoF_SysM_AuxZ(rp,k,tt  )  =l= vCommit    (rp,k,tt)*pUBLin                      ;
eRoCoF_ThEq10(rpk(rp,k),tt    )$[pEnableRoCoF]..               vRoCoF_SysM_AuxZ(rp,k,tt  )  =l= vRoCoF_SysM(rp,k   )                             ;
eRoCoF_ThEq11(rpk(rp,k),tt    )$[pEnableRoCoF]..               vRoCoF_SysM_AuxZ(rp,k,tt  )  =g= vRoCoF_SysM(rp,k   )-pUBLin*[1-vCommit(rp,k,tt)] ;

eRoCoF_VgEq1 (rpk(rp,k),   v  )$[pEnableRoCoF].. vGenP      (rp,k,   v  ) =e= sum[gi(vv,i),[pMaxProd(vv)*[sum[m,2**[ord(m)-1]*vRoCoF_AuxW(rp,k,vv,v,m)]+pExisUnits(vv)*vRoCoF_k(rp,k,v)]]*pResProfile(rp,k,i,vv)] ;
eRoCoF_VgEq2 (rpk(rp,k),vv,v,m)$[pEnableRoCoF].. vRoCoF_AuxW(rp,k,vv,v,m) =l=               vRoCoF_AuxI(vv,m   )                              ;
eRoCoF_VgEq3 (rpk(rp,k),vv,v,m)$[pEnableRoCoF].. vRoCoF_AuxW(rp,k,vv,v,m) =l=               vRoCoF_k   (rp,k,v )                              ;
eRoCoF_VgEq4 (rpk(rp,k),vv,v,m)$[pEnableRoCoF].. vRoCoF_AuxW(rp,k,vv,v,m) =g=               vRoCoF_k   (rp,k,v )-       [1-vRoCoF_AuxI(vv,m)] ;
eRoCoF_VgEq5 (rpk(rp,k),vv,  m)$[pEnableRoCoF].. vRoCoF_AuxV(rp,k,vv,  m) =l=               vRoCoF_AuxI(vv,m   )*pUBLin                       ;
eRoCoF_VgEq6 (rpk(rp,k),vv,  m)$[pEnableRoCoF].. vRoCoF_AuxV(rp,k,vv,  m) =l=               vRoCoF_VI_M(rp,k   )                              ;
eRoCoF_VgEq7 (rpk(rp,k),vv,  m)$[pEnableRoCoF].. vRoCoF_AuxV(rp,k,vv,  m) =g=               vRoCoF_VI_M(rp,k   )-pUBLin*[1-vRoCoF_AuxI(vv,m)] ;
eRoCoF_VgEq8 (             v  )$[pEnableRoCoF].. vGenInvest    (        v  ) =e= sum[m       , vRoCoF_AuxI(    v,m)*2**[ord(m)-1]              ] ;
eRoCoF_VgEq9 (rpk(rp,k),vv,  m)$[pEnableRoCoF].. vRoCoF_SysM_AuxV(rp,k,vv,m) =l=            vRoCoF_AuxI(vv,m   )*pUBLin                       ;
eRoCoF_VgEq10(rpk(rp,k),vv,  m)$[pEnableRoCoF].. vRoCoF_SysM_AuxV(rp,k,vv,m) =l=            vRoCoF_SysM(rp,k   )                              ;
eRoCoF_VgEq11(rpk(rp,k),vv,  m)$[pEnableRoCoF].. vRoCoF_SysM_AuxV(rp,k,vv,m) =g=            vRoCoF_SysM(rp,k   )-pUBLin*[1-vRoCoF_AuxI(vv,m)] ;

eRoCoF_SyEq1(rpk(rp,k))$[pEnableRoCoF]..pDeltaP(rp,k)     =l= [pMaxRoCoF/pBaseFreq]*vRoCoF_SysM(rp,k);
eRoCoF_SyEq2(rpk(rp,k))$[pEnableRoCoF]..vRoCoF_SG_M(rp,k) =e= sum[t,2*pInertiaConst(t)*                     vRoCoF_k   (rp,k,t     )] ;
eRoCoF_SyEq3(rpk(rp,k))$[pEnableRoCoF]..vRoCoF_VI_M(rp,k) =e= sum[v,2*pInertiaConst(v)*sum[m, 2**(ord(m)-1)*vRoCoF_AuxW(rp,k,v,v,m)]] ;
eRoCoF_SyEq4(rpk(rp,k))$[pEnableRoCoF]..vRoCoF_SysM(rp,k) =l= pUBLin * [+sum[t          ,pMaxProd(t)*vCommit    (rp,k,t  )                            ]
                                                                        +sum[(gi(v,i),m),pMaxProd(v)*pResProfile(rp,k,i,v)*vGenInvest   (v)*2**[ord(m)-1]]
                                                                        +sum[ gi(v,i)   ,pMaxProd(v)*pResProfile(rp,k,i,v)*pExisUnits(v)              ]
                                                                        ] ;
eRoCoF_SyEq5(rpk(rp,k))$[pEnableRoCoF]..
   +sum[t          ,pMaxProd(t)*vRoCoF_SysM_AuxZ(rp,k,t  )                                    ]
   +sum[(gi(v,i),m),pMaxProd(v)*vRoCoF_SysM_AuxV(rp,k,v,m)*pResProfile(rp,k,i,v)*2**[ord(m)-1]]
   +sum[ gi(v,i)   ,pMaxProd(v)*vRoCoF_SysM     (rp,k    )*pResProfile(rp,k,i,v)*pExisUnits(v)]
  =e=
   +sum[t          ,pMaxProd(t)*vRoCoF_AuxZ     (rp,k,t  )                                    ]
   +sum[(gi(v,i),m),pMaxProd(v)*vRoCoF_AuxV     (rp,k,v,m)*pResProfile(rp,k,i,v)*2**[ord(m)-1]]
   +sum[ gi(v,i)   ,pMaxProd(v)*vRoCoF_VI_M     (rp,k    )*pResProfile(rp,k,i,v)*pExisUnits(v)]
;
$offFold

$onFold // Cycle Depth Stress Function (CDSF) ----------------------------------

eCDSF_dis(rpk(rp,k),s)$[cdsf(s)].. vGenP      (rp,k,s) =e= sum[a, vCDSF_dis(rp,k,s,a)] ;
eCDSF_ch (rpk(rp,k),s)$[cdsf(s)].. vConsump   (rp,k,s) =e= sum[a, vCDSF_ch (rp,k,s,a)] ;
eCDSF_e  (rpk(rp,k),s)$[cdsf(s)].. vStIntraRes(rp,k,s) =e= sum[a, vCDSF_SoC(rp,k,s,a)] ;

eCDSF_SoC   (rpk(rp,k),  s,a) $[ cdsf(s )]..
   + vCDSF_SoC  (rp,k--1,s,a) $[ card(rp)>1             ]
   + vCDSF_SoC  (rp,k- 1,s,a) $[ card(rp)=1             ]
   + pIniReserve(        s  ) $[ card(rp)=1 and ord(k)=1]
   - vCDSF_SoC  (rp,k   ,s,a)
   - vCDSF_dis  (rp,k   ,s,a) * pWeight_k(k) / pDisEffic(s)
   + vCDSF_ch   (rp,k   ,s,a) * pWeight_k(k) * pChEffic (s)
  =e=
   0
;

eCDSF_MaxSoC(rpk(rp,k),s,a)$[cdsf(s)].. vCDSF_SoC(rp,k,s,a) =l= pMaxProd(s)*[vGenInvest(s)+pExisUnits(s)]*pE2PRatio(s)/card(a);
eCDSF_EndSoC(rpk(rp,k),s  )$[cdsf(s) and card(rp)=1 and ord(k)=card(k)]..
   + sum[a,vCDSF_SoC(rp,k,s,a)] =g= pIniReserve(s)
;

$offFold

$onFold // DC Power Flow Formulation (DC) --------------------------------------

eDC_BalanceP(rpk(rp,k),iact(i))$[pTransNet and not pEnableSOCP]..
   + sum[gi(t,i  ),   vGenP     (rp,k,t    )]
   + sum[gi(r,i  ),   vGenP     (rp,k,r    )]
   + sum[gi(s,i  ),   vGenP     (rp,k,s    )]
   - sum[gi(s,i  ),   vConsump  (rp,k,s    )]
   + sum[la(j,i,c),   vLineP    (rp,k,j,i,c)]
   - sum[la(i,j,c),   vLineP    (rp,k,i,j,c)]
   +                  vPNS      (rp,k,i    )
   + sum[      seg,   vDSM_Shed (rp,k,i,seg)] $[pDSM     ]
   + sum[      sec,   vDSM_Dn   (rp,k,i,sec)] $[pDSM     ]
  =e=
   +                  pDemandP  (rp,k,i    )
   + sum[      sec  , vDSM_Up   (rp,k,i,sec)] $[pDSM     ]
   + sum[h2gi(h2g,i), vH2Consump(rp,k,h2g  )] $[pEnableH2]
;
* power flow existing lines
eDC_ExiLinePij(rpk(rp,k),le(i,j,c)) $[pTransNet and not pEnableSOCP]..
   + vLineP(       rp,k ,   i,j,c) =e= [vTheta(rp,k,i)-vTheta(rp,k,j)+pAngle(i,j,c)] * pSBase / [pXline(i,j,c)*pRatio(i,j,c)]
;
* power flow candidate lines
eDC_CanLinePij1(rpk(rp,k),lc(i,j,c)) $[pTransNet and not pEnableSOCP].. vLineP(rp,k,i,j,c)/ [pBigM_Flow*pPmax(i,j,c)] =g= [vTheta(rp,k,i) - vTheta(rp,k,j)+ pAngle(i,j,c)] * pSbase / [pXline(i,j,c)*pRatio(i,j,c)] / [pBigM_Flow*pPmax(i,j,c)] - 1 + vLineInvest(i,j,c) ;
eDC_CanLinePij2(rpk(rp,k),lc(i,j,c)) $[pTransNet and not pEnableSOCP].. vLineP(rp,k,i,j,c)/ [pBigM_Flow*pPmax(i,j,c)] =l= [vTheta(rp,k,i) - vTheta(rp,k,j)+ pAngle(i,j,c)] * pSbase / [pXline(i,j,c)*pRatio(i,j,c)] / [pBigM_Flow*pPmax(i,j,c)] + 1 - vLineInvest(i,j,c) ;

* power flow limit on candidate lines
eDC_LimCanLine1(rpk(rp,k),lc(i,j,c)) $[pTransNet and not pEnableSOCP].. vLineP(rp,k,i,j,c)/             pPmax(i,j,c)  =g=   - vLineInvest(i,j,c) ;
eDC_LimCanLine2(rpk(rp,k),lc(i,j,c)) $[pTransNet and not pEnableSOCP].. vLineP(rp,k,i,j,c)/             pPmax(i,j,c)  =l=     vLineInvest(i,j,c) ;

$offFold

$onFold // Second Order Cone Programming (SOCP) --------------------------------

eSOCP_BalanceP(rpk(rp,k),i) $[pTransNet and pEnableSOCP] ..
   + sum[gi   (t,i), vGenP    (rp,k,t    )]
   + sum[gi   (r,i), vGenP    (rp,k,r    )]
   + sum[gi   (s,i), vGenP    (rp,k,s    )]
   - sum[gi   (s,i), vConsump (rp,k,s    )]
   +                 vPNS     (rp,k,i    )
   + sum[       seg, vDSM_Shed(rp,k,i,seg)]   $[pDSM     ]
   + sum[       sec, vDSM_Dn  (rp,k,i,sec)]   $[pDSM     ]
  =e=
   + sum[(j,c) $la(i,j,c), vLineP(rp,k,i,j,c)]
   + sum[(j,c) $la(j,i,c), vLineP(rp,k,i,j,c)]
   + vSOCP_cii (rp,k,i) * pBusG(i) * pSBase
   + pDemandP  (rp,k,i)
   + sum[       sec , vDSM_Up   (rp,k,i,sec)] $[pDSM     ]
   + sum[h2gi(h2g,i), vH2Consump(rp,k,h2g  )] $[pEnableH2]
;

eSOCP_BalanceQ(rpk(rp,k),i) $[pTransNet and pEnableSOCP] ..
   + sum[gi(t    ,i), vGenQ    (rp,k,t    )]
   + sum[gi(r    ,i), vGenQ    (rp,k,r    )]
   + sum[gi(s    ,i), vGenQ    (rp,k,s    )]
   + sum[gi(facts,i), vGenQ    (rp,k,facts)]
   +                  vPNS     (rp,k,i    )  * pRatioDemQP(i)
   + sum[       seg,  vDSM_Shed(rp,k,i,seg)] * pRatioDemQP(i) $[pDSM]
   + sum[       sec,  vDSM_Dn  (rp,k,i,sec)] * pRatioDemQP(i) $[pDSM]
  =e=
   + sum[(j,c) $la(i,j,c), vLineQ(rp,k,i,j,c)]
   + sum[(j,c) $la(j,i,c), vLineQ(rp,k,i,j,c)]
   - vSOCP_cii (rp,k,i) * pBusB(i) * pSBase
   + pDemandQ  (rp,k,i)
   + sum[       sec , vDSM_Up   (rp,k,i,sec)] * pRatioDemQP(i  )  $[pDSM]
   + sum[h2gi(h2g,i), vH2Consump(rp,k,h2g  )  * pH2RatioQP (h2g)] $[pEnableH2]
;

eSOCP_QMaxOut (rpk(rp,k),t) $[pTransNet and pEnableSOCP and pMaxGenQ(t)  ].. vGenQ(rp,k,t) / pMaxGenQ(t) =l= vCommit(rp,k,t) ;
eSOCP_QMinOut1(rpk(rp,k),t) $[pTransNet and pEnableSOCP and pMinGenQ(t)>0].. vGenQ(rp,k,t) / pMinGenQ(t) =g= vCommit(rp,k,t) ;
eSOCP_QMinOut2(rpk(rp,k),t) $[pTransNet and pEnableSOCP and pMinGenQ(t)<0].. vGenQ(rp,k,t) / pMinGenQ(t) =l= vCommit(rp,k,t) ;

eSOCP_QMaxFACTS(rpk(rp,k),facts) $[pTransNet and pEnableSOCP].. vGenQ(rp,k,facts) =l= pMaxGenQ(facts) * [pExisUnits(facts) + vGenInvest(facts)] ;
eSOCP_QMinFACTS(rpk(rp,k),facts) $[pTransNet and pEnableSOCP].. vGenQ(rp,k,facts) =g= pMinGenQ(facts) * [pExisUnits(facts) + vGenInvest(facts)] ;

* active and reactive power flow on existing lines
eSOCP_ExiLinePij(rpk(rp,k),i,j,c) $[le (i,j,c) and pTransNet and pEnableSOCP]..
  vLineP        (rp,k ,i,j,c)  =e= pSBase * [
      + [   pGline    (     i,j,c)  * [vSOCP_cii(rp,k,i)] / sqr[pRatio(i,j,c)]]
      - [1/ pRatio    (     i,j,c)] *
           [pGline    (     i,j,c)  * cos[pAngle(i,j,c)] - pBline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_cij(rp,k,i,j  )]
      - [1/ pRatio    (     i,j,c)] *
           [pBline    (     i,j,c)  * cos[pAngle(i,j,c)] + pGline(i,j,c) * sin[pAngle(i,j,c)]] *
           [-vSOCP_sij(rp,k,i,j  )] ]
;

eSOCP_ExiLinePji(rpk(rp,k),i,j,c) $[le (i,j,c) and pTransNet and pEnableSOCP]..
   vLineP       (rp,k ,j,i,c) =e= pSBase * [
      + [   pGline    (     i,j,c)  * [vSOCP_cii(rp,k,j)]]
      - [1/ pRatio    (     i,j,c)] *
           [pGline    (     i,j,c)  * cos[pAngle(i,j,c)] + pBline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_cij(rp,k,i,j  )]
      - [1/ pRatio    (     i,j,c)] *
           [pBline    (     i,j,c)  * cos[pAngle(i,j,c)] - pGline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_sij(rp,k,i,j  )] ]
;

eSOCP_ExiLineQij(rpk(rp,k),i,j,c) $[le (i,j,c) and pTransNet and pEnableSOCP]..
   vLineQ       (rp,k ,i,j,c)  =e= pSBase * [
      - [[   vSOCP_cii(rp,k,i    )] * [pBline(i,j,c) + pBcline(i,j,c)/2] / sqr[pRatio(i,j,c)]]
      - [1/  pRatio   (     i,j,c)] *
           [ pGline   (     i,j,c)  * cos[pAngle(i,j,c)] - pBline(i,j,c) * sin[pAngle(i,j,c)]] *
           [-vSOCP_sij(rp,k,i,j  )]
      + [1/  pRatio   (     i,j,c)] *
           [ pBline   (     i,j,c)  * cos[pAngle(i,j,c)] + pGline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_cij(rp,k,i,j  )] ]
;

eSOCP_ExiLineQji(rpk(rp,k),i,j,c) $[le (i,j,c) and pTransNet and pEnableSOCP]..
   vLineQ       (rp,k ,j,i,c) =e= pSBase * [
      - [    vSOCP_cii(rp,k,  j  )] * [pBline(i,j,c) + pBcline(i,j,c)/2]
      - [1/  pRatio   (     i,j,c)] *
           [ pGline   (     i,j,c)  * cos[pAngle(i,j,c)] + pBline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_sij(rp,k,i,j  )]
      + [1/  pRatio   (     i,j,c)] *
           [ pBline   (     i,j,c)  * cos[pAngle(i,j,c)] - pGline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_cij(rp,k,i,j  )] ]
;

* active and reactive power flow on candidates lines
eSOCP_CanLinePij1(rpk(rp,k),i,j,c) $[lc (i,j,c) and pTransNet and pEnableSOCP]..
  vLineP        (rp,k ,i,j,c)  =g= pSBase * [
      + [   pGline    (     i,j,c)  * [vSOCP_cii(rp,k,i)] / sqr[pRatio(i,j,c)]]
      - [1/ pRatio    (     i,j,c)] *
           [pGline    (     i,j,c)  * cos[pAngle(i,j,c)] - pBline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_cij(rp,k,i,j  )]
      - [1/ pRatio    (     i,j,c)] *
           [pBline    (     i,j,c)  * cos[pAngle(i,j,c)] + pGline(i,j,c) * sin[pAngle(i,j,c)]] *
           [-vSOCP_sij(rp,k,i,j  )] ]
      - pBigM_Flow * [1 - vLineInvest(i,j,c)]
;

eSOCP_CanLinePij2(rpk(rp,k),i,j,c) $[lc (i,j,c) and pTransNet and pEnableSOCP]..
  vLineP        (rp,k ,i,j,c)  =l= pSBase * [
      + [   pGline    (     i,j,c)  * [vSOCP_cii(rp,k,i)] / sqr[pRatio(i,j,c)]]
      - [1/ pRatio    (     i,j,c)] *
           [pGline    (     i,j,c)  * cos[pAngle(i,j,c)] - pBline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_cij(rp,k,i,j  )]
      - [1/ pRatio    (     i,j,c)] *
           [pBline    (     i,j,c)  * cos[pAngle(i,j,c)] + pGline(i,j,c) * sin[pAngle(i,j,c)]] *
           [-vSOCP_sij(rp,k,i,j  )] ]
      + pBigM_Flow * [1 - vLineInvest(i,j,c)]
;

eSOCP_CanLinePji1(rpk(rp,k),i,j,c) $[lc (i,j,c) and pTransNet and pEnableSOCP]..
   vLineP       (rp,k ,j,i,c) =g= pSBase * [
      + [   pGline    (     i,j,c)  * [vSOCP_cii(rp,k,j)]]
      - [1/ pRatio    (     i,j,c)] *
           [pGline    (     i,j,c)  * cos[pAngle(i,j,c)] + pBline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_cij(rp,k,i,j  )]
      - [1/ pRatio    (     i,j,c)] *
           [pBline    (     i,j,c)  * cos[pAngle(i,j,c)] - pGline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_sij(rp,k,i,j  )] ]
      - pBigM_Flow * [1 - vLineInvest(i,j,c)]
;

eSOCP_CanLinePji2(rpk(rp,k),i,j,c) $[lc (i,j,c) and pTransNet and pEnableSOCP]..
   vLineP       (rp,k ,j,i,c) =l= pSBase * [
      + [   pGline    (     i,j,c)  * [vSOCP_cii(rp,k,j)]]
      - [1/ pRatio    (     i,j,c)] *
           [pGline    (     i,j,c)  * cos[pAngle(i,j,c)] + pBline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_cij(rp,k,i,j  )]
      - [1/ pRatio    (     i,j,c)] *
           [pBline    (     i,j,c)  * cos[pAngle(i,j,c)] - pGline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_sij(rp,k,i,j  )] ]
      + pBigM_Flow * [1 - vLineInvest(i,j,c)]
;

eSOCP_CanLineQij1(rpk(rp,k),i,j,c) $[lc (i,j,c) and pTransNet and pEnableSOCP]..
   vLineQ       (rp,k ,i,j,c)  =g= pSBase * [
      - [[   vSOCP_cii(rp,k,i    )] * [pBline(i,j,c) + pBcline(i,j,c)/2] / sqr[pRatio(i,j,c)]]
      - [1/  pRatio   (     i,j,c)] *
           [ pGline   (     i,j,c)  * cos[pAngle(i,j,c)] - pBline(i,j,c) * sin[pAngle(i,j,c)]] *
           [-vSOCP_sij(rp,k,i,j  )]
      + [1/  pRatio   (     i,j,c)] *
           [ pBline   (     i,j,c)  * cos[pAngle(i,j,c)] + pGline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_cij(rp,k,i,j  )] ]
      - pBigM_Flow * [1 - vLineInvest(i,j,c)]
;

eSOCP_CanLineQij2(rpk(rp,k),i,j,c) $[lc (i,j,c) and pTransNet and pEnableSOCP]..
   vLineQ       (rp,k ,i,j,c)  =l= pSBase * [
      - [[   vSOCP_cii(rp,k,i    )] * [pBline(i,j,c) + pBcline(i,j,c)/2] / sqr[pRatio(i,j,c)]]
      - [1/  pRatio   (     i,j,c)] *
           [ pGline   (     i,j,c)  * cos[pAngle(i,j,c)] - pBline(i,j,c) * sin[pAngle(i,j,c)]] *
           [-vSOCP_sij(rp,k,i,j  )]
      + [1/  pRatio   (     i,j,c)] *
           [ pBline   (     i,j,c)  * cos[pAngle(i,j,c)] + pGline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_cij(rp,k,i,j  )] ]
      + pBigM_Flow * [1 - vLineInvest(i,j,c)]
;

eSOCP_CanLineQji1(rpk(rp,k),i,j,c) $[lc (i,j,c) and pTransNet and pEnableSOCP]..
   vLineQ       (rp,k ,j,i,c) =g= pSBase * [
      - [    vSOCP_cii(rp,k,  j  )] * [pBline(i,j,c) + pBcline(i,j,c)/2]
      - [1/  pRatio   (     i,j,c)] *
           [ pGline   (     i,j,c)  * cos[pAngle(i,j,c)] + pBline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_sij(rp,k,i,j  )]
      + [1/  pRatio   (     i,j,c)] *
           [ pBline   (     i,j,c)  * cos[pAngle(i,j,c)] - pGline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_cij(rp,k,i,j  )] ]
      - pBigM_Flow * [1 - vLineInvest(i,j,c)]
;

eSOCP_CanLineQji2(rpk(rp,k),i,j,c) $[lc (i,j,c) and pTransNet and pEnableSOCP]..
   vLineQ       (rp,k ,j,i,c) =l= pSBase * [
      - [    vSOCP_cii(rp,k,  j  )] * [pBline(i,j,c) + pBcline(i,j,c)/2]
      - [1/  pRatio   (     i,j,c)] *
           [ pGline   (     i,j,c)  * cos[pAngle(i,j,c)] + pBline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_sij(rp,k,i,j  )]
      + [1/  pRatio   (     i,j,c)] *
           [ pBline   (     i,j,c)  * cos[pAngle(i,j,c)] - pGline(i,j,c) * sin[pAngle(i,j,c)]] *
           [ vSOCP_cij(rp,k,i,j  )] ]
      + pBigM_Flow * [1 - vLineInvest(i,j,c)]
;

* active and reactive power flow limit on candidates lines
eSOCP_LimCanLinePij1(rpk(rp,k),i,j,c) $[lc(i,j,c) and pTransNet and pEnableSOCP]..vLineP(rp,k,i,j,c)/ pPmax(i,j,c) =g= -vLineInvest(i,j,c) ;
eSOCP_LimCanLinePij2(rpk(rp,k),i,j,c) $[lc(i,j,c) and pTransNet and pEnableSOCP]..vLineP(rp,k,i,j,c)/ pPmax(i,j,c) =l=  vLineInvest(i,j,c) ;
eSOCP_LimCanLinePji1(rpk(rp,k),i,j,c) $[lc(i,j,c) and pTransNet and pEnableSOCP]..vLineP(rp,k,j,i,c)/ pPmax(i,j,c) =g= -vLineInvest(i,j,c) ;
eSOCP_LimCanLinePji2(rpk(rp,k),i,j,c) $[lc(i,j,c) and pTransNet and pEnableSOCP]..vLineP(rp,k,j,i,c)/ pPmax(i,j,c) =l=  vLineInvest(i,j,c) ;

eSOCP_LimCanLineQij1(rpk(rp,k),i,j,c) $[lc(i,j,c) and pTransNet and pEnableSOCP]..vLineQ(rp,k,i,j,c)/ pQmax(i,j,c) =g= -vLineInvest(i,j,c) ;
eSOCP_LimCanLineQij2(rpk(rp,k),i,j,c) $[lc(i,j,c) and pTransNet and pEnableSOCP]..vLineQ(rp,k,i,j,c)/ pQmax(i,j,c) =l=  vLineInvest(i,j,c) ;
eSOCP_LimCanLineQji1(rpk(rp,k),i,j,c) $[lc(i,j,c) and pTransNet and pEnableSOCP]..vLineQ(rp,k,j,i,c)/ pQmax(i,j,c) =g= -vLineInvest(i,j,c) ;
eSOCP_LimCanLineQji2(rpk(rp,k),i,j,c) $[lc(i,j,c) and pTransNet and pEnableSOCP]..vLineQ(rp,k,j,i,c)/ pQmax(i,j,c) =l=  vLineInvest(i,j,c) ;

* SOCP constraint for existing and candidate lines
eSOCP_ExiLine(rpk(rp,k),i,j) $[isLe(i,j) and pTransNet and pEnableSOCP]..
   +  vSOCP_cij  (rp,k ,i,j) * vSOCP_cij(rp,k,i,j)
   +  vSOCP_sij  (rp,k ,i,j) * vSOCP_sij(rp,k,i,j)
  =l= vSOCP_cii  (rp,k ,i  ) * vSOCP_cii(rp,k,j  )
;

eSOCP_CanLine(rpk(rp,k),i,j) $[[1-sum[le(i,j,c)$[ord(c)=1],1]] and isLc(i,j) and pTransNet and pEnableSOCP]..
   +  vSOCP_cij  (rp,k ,i,j) * vSOCP_cij(rp,k,i,j)
   +  vSOCP_sij  (rp,k ,i,j) * vSOCP_sij(rp,k,i,j)
  =l= vSOCP_cii  (rp,k ,i  ) * vSOCP_cii(rp,k,j  )
;

eSOCP_CanLine_cij (rpk(rp,k),i,j)$[   sum[le(i,j,c)$[ord(c)=1],1]  and isLc(i,j) and pTransNet and pEnableSOCP].. vSOCP_cij(rp,k,i,j) =L=  pBigM_SOCP * vSOCP_IndicConnecNodes(i,j);
eSOCP_CanLine_sij1(rpk(rp,k),i,j)$[   sum[le(i,j,c)$[ord(c)=1],1]  and isLc(i,j) and pTransNet and pEnableSOCP].. vSOCP_sij(rp,k,i,j) =L=  pBigM_SOCP * vSOCP_IndicConnecNodes(i,j);
eSOCP_CanLine_sij2(rpk(rp,k),i,j)$[   sum[le(i,j,c)$[ord(c)=1],1]  and isLc(i,j) and pTransNet and pEnableSOCP].. vSOCP_sij(rp,k,i,j) =g= -pBigM_SOCP * vSOCP_IndicConnecNodes(i,j);

eSOCP_IndicConnecNodes1     (i,j)$[[  sum[le(i,j,c)$[ord(c)=1],1]] and isLc(i,j) and pTransNet and pEnableSOCP].. vSOCP_IndicConnecNodes(i,j) =E= 1;
eSOCP_IndicConnecNodes2     (i,j)$[[1-sum[le(i,j,c)$[ord(c)=1],1]] and isLc(i,j) and pTransNet and pEnableSOCP].. vSOCP_IndicConnecNodes(i,j) =E= [sum[c$[ord(c)=1], vLineInvest(i,j,c)]];

* Limits for SOCP variables of candidates lines
eSOCP_CanLineCijUpLim(rpk(rp,k),i,j) $[[1-sum[le(i,j,c)$[ord(c)=1],1]] and isLc(i,j)and pTransNet and pEnableSOCP].. vSOCP_cij(rp,k,i,j) =l=         sqr[pBusMaxV(i)]  + pBigM_SOCP * [1-vSOCP_IndicConnecNodes(i,j)] ;
eSOCP_CanLineCijLoLim(rpk(rp,k),i,j) $[[1-sum[le(i,j,c)$[ord(c)=1],1]] and isLc(i,j)and pTransNet and pEnableSOCP].. vSOCP_cij(rp,k,i,j) =g= max[0.1,sqr[pBusMinV(i)]] - pBigM_SOCP * [1-vSOCP_IndicConnecNodes(i,j)] ;
eSOCP_CanLineSijUpLim(rpk(rp,k),i,j) $[[1-sum[le(i,j,c)$[ord(c)=1],1]] and isLc(i,j)and pTransNet and pEnableSOCP].. vSOCP_sij(rp,k,i,j) =l=         sqr[pBusMaxV(i)]  + pBigM_SOCP * [1-vSOCP_IndicConnecNodes(i,j)] ;
eSOCP_CanLineSijLoLim(rpk(rp,k),i,j) $[[1-sum[le(i,j,c)$[ord(c)=1],1]] and isLc(i,j)and pTransNet and pEnableSOCP].. vSOCP_sij(rp,k,i,j) =g=        -sqr[pBusMaxV(i)]  - pBigM_SOCP * [1-vSOCP_IndicConnecNodes(i,j)] ;

* angles limits for existing and candidate lines
eSOCP_ExiLineAngDif1(rpk(rp,k),i,j) $[isLe(i,j) and pTransNet and pEnableSOCP]..
   +   vSOCP_sij (rp,k ,i,j)
  =l= +vSOCP_cij (rp,k ,i,j)* tan(pMaxAngleDiff)
;

eSOCP_ExiLineAngDif2(rpk(rp,k),i,j) $[isLe(i,j) and pTransNet and pEnableSOCP]..
   +   vSOCP_sij (rp,k ,i,j)
  =g= -vSOCP_cij (rp,k ,i,j)* tan(pMaxAngleDiff)
;

eSOCP_CanLineAngDif1(rpk(rp,k),i,j) $[[1-sum[le(i,j,c)$[ord(c)=1],1]] and isLc(i,j) and pTransNet and pEnableSOCP]..
   +   vSOCP_sij (rp,k ,i,j)
  =l= +vSOCP_cij (rp,k ,i,j)* tan(pMaxAngleDiff)
   +   pBigM_SOCP * [1-vSOCP_IndicConnecNodes(i,j)]
;

eSOCP_CanLineAngDif2(rpk(rp,k),i,j) $[[1-sum[le(i,j,c)$[ord(c)=1],1]] and isLc(i,j) and pTransNet and pEnableSOCP]..
   +   vSOCP_sij (rp,k ,i,j)
  =g= -vSOCP_cij (rp,k ,i,j)* tan(pMaxAngleDiff)
   -   pBigM_SOCP * [1-vSOCP_IndicConnecNodes(i,j)]
;

* It is disabled (even without investment) because it increases the time to solve
eSOCP_ExiLineSLimit(rpk(rp,k),i,j,c) $[[le(i,j,c) or  le(j,i,c)] and [pTransNet and pEnableSOCP=9999]]..
   +  vLineP(    rp,k ,i,j,c) * vLineP(rp,k,i,j,c)
   +  vLineQ(    rp,k ,i,j,c) * vLineQ(rp,k,i,j,c)
  =l=[pPmax (          i,j,c) * pPmax (     i,j,c)
   +  pQmax (          i,j,c) * pQmax (     i,j,c)]**(1/2)
;

eSOCP_CanLineSLimit(rpk(rp,k),i,j,c) $[[lc(i,j,c) or  lc(j,i,c)] and [pTransNet and pEnableSOCP=9999]]..
   +  vLineP(    rp,k ,i,j,c) * vLineP(rp,k,i,j,c)
   +  vLineQ(    rp,k ,i,j,c) * vLineQ(rp,k,i,j,c)
  =l=[pPmax (          i,j,c) * pPmax (     i,j,c)
   +  pQmax (          i,j,c) * pQmax (     i,j,c)]**(1/2)
   *  vLineInvest     (i,j,c)
;
$offFold

$onFold // Equation Transmission LineInvestment Order of Circuits --------------

eTranInves (i,j,c) $[lc(i,j,c) and pTransNet and ord(c)>1]..
    vLineInvest(i,j,c) =l= vLineInvest(i,j,c-1) + sum[le(i,j,c-1),1];
    
*------- equation CO2 budget -------

eCO2_Budget$[pEnableCO2]..
   + sum[(rpk(rp,k),t), pWeight_rp(rp)*pWeight_k(k) * pCO2Emis(t) * vGenP(rp,k,t)] + vCO2Undershoot - vCO2Overshoot
  =e=
   pCO2Budget
;
$offFold

$onFold // Equation CO2 Budget -------------------------------------------------


eH2_MaxCons(rpk(rp,k),h2g) $[pEnableH2].. vH2Consump(rp,k,h2g) =l=                pH2MaxCons(h2g) *              [vH2Invest (     h2g) + pH2ExisUnits(h2g)] ;
eH2_MaxProd(rpk(rp,k),h2g) $[pEnableH2].. vH2Prod   (rp,k,h2g) =l= pWeight_k(k) * pH2MaxCons(h2g) * pH2PE(h2g) * [vH2Invest (     h2g) + pH2ExisUnits(h2g)] ;
eH2_Convers(rpk(rp,k),h2g) $[pEnableH2].. vH2Prod   (rp,k,h2g) =e= pWeight_k(k) *                   pH2PE(h2g) *  vH2Consump(rp,k,h2g)                      ;

eH2_Balance(rpk(rp,k),h2i,h2sec) $[pEnableH2]..
   + sum[h2gh2i(h2g  ,h2i), vH2Prod(rp,k,h2g      )]
   + sum[h2line(h2j  ,h2i), vH2Flow(rp,k,h2j,h2i  )]
   - sum[h2line(h2i  ,h2j), vH2Flow(rp,k,h2i,h2j  )]
   +                        vH2NS  (rp,k,h2i,h2sec)
  =e=
   + pH2Demand (rp,k,h2i,h2sec)
;
$offFold

$onFold // Equation for Ex-Post Calculation of Voltage Angles in DC and SOCP ---

eDummyOf $[pEnableDummyModel]..
   vDummyOf =e= sum[(rp,k,isLine(i,j)), vDummySlackP(rp,k,i,j) + vDummySlackN(rp,k,i,j)] ;

eDummyAngDiff(rpk(rp,k),i,j) $[isLine(i,j) and pEnableDummyModel]..
   + vTheta      (rp,k,j  )
   - vTheta      (rp,k,i  )
   + vDummySlackP(rp,k,i,j)
   - vDummySlackN(rp,k,i,j)
  =e=
   + pDelVolAng  (rp,k,i,j) ;

$offFold


*-------------------------------------------------------------------------------
*                                Models
*-------------------------------------------------------------------------------
$onFold // Model LEGO ----------------------------------------------------------

model LEGO / all / ;
LEGO.HoldFixed = 1 ; LEGO.optfile = 1; LEGO.TryLinear = 1 ;

$offFold

$onFold // Model mDummy --------------------------------------------------------

model mDummy   /eDummyOf  eDummyAngDiff/ ;
mDummy.holdfixed     = 1 ;

$offFold


*-------------------------------------------------------------------------------
*                            Options for Solvers
*-------------------------------------------------------------------------------
$onFold // Options for Solvers -------------------------------------------------

file     GOPT / gurobi.opt /               ;
put      GOPT / 'IIS 1'    / 'rins 1000' / ;
putclose GOPT
;
file     COPT / cplex.opt  /                   ;
put      COPT / 'IIS yes'  / 'rinsheur 1000' / ;
putclose COPT
;
$offFold


*-------------------------------------------------------------------------------
*             Read Input Data from Excel and Include into the Model
*-------------------------------------------------------------------------------
$onFold // Read input data from Excel and include into the model ---------------

file TMP / tmp_%gams.user1%.txt /
$OnEcho  > tmp_%gams.user1%.txt
   r1=     indices
   o1 =tmp_indices.txt
   r2 =    param
   o2 =tmp_param.txt
   r3 =    demand
   o3 =tmp_demand.txt
   r4 =    weight_rp
   o4 =tmp_weight_rp.txt
   r5 =    weight_k
   o5 =tmp_weight_k.txt
   r6 =    resprofile
   o6 =tmp_resprofile.txt
   r7 =    thermalgen
   o7 =tmp_thermalgen.txt
   r8 =    storage
   o8 =tmp_storage.txt
   r9 =    renewable
   o9 =tmp_renewable.txt
   r10=    inflows
   o10=tmp_inflows.txt
   r11=    network
   o11=tmp_network.txt
   r12=    hindex
   o12=tmp_hindex.txt
   r13=    businfo
   o13=tmp_businfo.txt
   r14=    facts
   o14=tmp_facts.txt
   r15=    dsmdelaytime
   o15=tmp_dsmdelaytime.txt
   r16=    dsmprofiles
   o16=tmp_dsmprofiles.txt
   r17=    dsmshed
   o17=tmp_dsmshed.txt
   r18=    dsmshiftcost
   o18=tmp_dsmshiftcost.txt
   r19=    h2_indices
   o19=tmp_h2_indices.txt
   r20=    h2_demand
   o20=tmp_h2_demand.txt
   r21=    h2_genunits
   o21=tmp_h2_genunits.txt
   r22=    h2network
   o22=tmp_h2network.txt
$OffEcho

$call xls2gms m i="%gams.user1%.xlsm" @"tmp_%gams.user1%.txt"
;
sets
$include tmp_indices.txt
$include tmp_hindex.txt
$include tmp_h2_indices.txt
;

parameters
$include tmp_weight_rp.txt
$include tmp_weight_k.txt
;

* general parameters
$include tmp_param.txt
;
* information from tables
table    tDemand      (k,rp,i  )
$include tmp_demand.txt
;
table    tResProfile  (k,rp,i,g)
$include tmp_resprofile.txt
;
table    tThermalGen  (g,*     )
$include tmp_thermalgen.txt
;
table    tStorage     (g,*     )
$include tmp_storage.txt
;
table    tRenewable   (g,*     )
$include tmp_renewable.txt
;
table    tInflows     (k,rp,i  )
$include tmp_inflows.txt
;
table    tNetwork     (i,j,c,* )
$include tmp_network.txt
;
table    tBusInfo     (i,    * )
$include tmp_businfo.txt
;
table    tFACTS       (g,*     )
$include tmp_facts.txt
;
table    tDelayTime   (sec,rp    )
$include tmp_dsmdelaytime.txt
;
table    tDSMprofile  (k,rp,sec,*)
$include tmp_dsmprofiles.txt
;
table    tDSMshed     (seg,*     )
$include tmp_dsmshed.txt
;
table    tDSMshiftcost (k,rp,i   )
$include tmp_dsmshiftcost.txt
;
table    tH2Demand     (h2sec,k,rp,h2i)
$include tmp_h2_demand.txt
;
table    tH2GenUnits   (h2u,*)
$include tmp_h2_genunits.txt
;
table    tH2Network    (h2i,h2j,*)
$include tmp_h2network.txt
;

* Delete the loaded ranges from memory
execute 'del tmp_"%gams.user1%".txt tmp_indices.txt      tmp_hindex.txt       tmp_param.txt       '
execute 'del tmp_thermalgen.txt     tmp_weight_rp.txt    tmp_resprofile.txt   tmp_inflows.txt     '
execute 'del tmp_storage.txt        tmp_weight_k.txt     tmp_renewable.txt    tmp_network.txt     '
execute 'del tmp_demand.txt         tmp_businfo.txt      tmp_facts.txt        tmp_dsmprofiles.txt '
execute 'del tmp_dsmshed.txt        tmp_dsmdelaytime.txt tmp_dsmshiftcost.txt tmp_h2_indices.txt  '
execute 'del tmp_h2_demand.txt      tmp_h2_genunits.txt  tmp_h2network.txt                        '
;
$offFold


*-------------------------------------------------------------------------------
*                        Update Option by Batch File
*-------------------------------------------------------------------------------
$onFold // Update Option by Batch File -----------------------------------------

if(%BatchUpdate%=1,
   if(%RelaxedMIP%=0, pRMIP      =0);
   if(%RelaxedMIP%=1, pRMIP      =1);
   if(%EnableSOCP%=0, pEnableSOCP=0);
   if(%EnableSOCP%=1, pEnableSOCP=1);
);

pEnableSOCP $[pTransNet=0] = 0 ;

$offFold


*-------------------------------------------------------------------------------
*                  Subsets Activation and Scaling Parameters
*-------------------------------------------------------------------------------
$onFold // Subsets activation and scaling parameters ---------------------------

* active representative periods
rpk(rp,k)$[pWeight_rp(rp) and pWeight_k(k)] = yes ;

* assignment of thermal units, storage units, and renewables
t    (g) $[ tThermalGen(g,'MaxProd'     )  and
           [tThermalGen(g,'ExisUnits'   )  or
            tThermalGen(g,'EnableInvest')] and
            tThermalGen(g,'FuelCost'    )]     = yes ;

s    (g) $[ tStorage   (g,'MaxProd'     )  and
           [tStorage   (g,'ExisUnits'   )  or
            tStorage   (g,'EnableInvest')  *
            tStorage   (g,'MaxInvest'   )]]   = yes ;

r    (g) $[ tRenewable (g,'MaxProd'     )  and
           [tRenewable (g,'ExisUnits'   )  or
            tRenewable (g,'EnableInvest')  *
            tRenewable (g,'MaxInvest'   )]]   = yes ;

v    (r) $[ tRenewable (r,'InertiaConst') ]   = yes ;
v    (s) $[ tStorage   (s,'InertiaConst') ]   = yes ;

facts(g) $[ tFACTS     (g,'QMax'        )  and
           [tFACTS     (g,'ExisUnits'   )  or
            tFACTS     (g,'EnableInvest')] and
            pEnableSOCP           ]          = yes ;

ga   (g) $[t(g) or s(g) or r(g) or facts(g)] = yes ;

* assigment of hydrogen units
h2g  (h2u)$[ tH2GenUnits(h2u,'MaxCons'     )  and
            [tH2GenUnits(h2u,'ExisUnits'   )  or
             tH2GenUnits(h2u,'EnableInvest')  *
             tH2GenUnits(h2u,'MaxInvest'   )] and
             pEnableH2                       ] = yes ;

* future subsets for hydrogen fuel cell and storage units
h2f  (h2u) = no ;
h2s  (h2u) = no ;

* Hydrogen pipeline network
h2line(h2i,h2j) $[tH2Network(h2i,h2j,'InService') and pEnableH2] = yes ;

* network subsets
if(card(i) =1, pTransNet = 0)                                        ;
la    (i,j,c) $[    tNetwork(i,j,c,'InService')              ] = yes ;
lc    (i,j,c) $[    tNetwork(i,j,c,'FixedCost') and la(i,j,c)] = yes ;
le    (i,j,c) $[not tNetwork(i,j,c,'FixedCost') and la(i,j,c)] = yes ;
isLc  (i,j  )                               = sum[c,lc(i,j,c)]       ;
isLe  (i,j  )                               = sum[c,le(i,j,c)]       ;
isLine(i,j  )                               = sum[c,le(i,j,c)]       ;
iact  (i    ) $[pTransNet = 0 and is(i)]    = yes                    ;
iact  (i    ) $[pTransNet = 1          ]    = yes                    ;

* scaling of parameters
pENSCost                    =             pENSCost               * 1e-3 ;
pDSMShiftCost(rpk(rp,k),i)  =             tDSMshiftcost(k,rp,i)  * 1e-3 ;
pInflows    (rpk(rp,k),s  ) = sum[gi(s,i),tInflows   (k,rp,i  )] * 1e-3 ;
pResProfile (rpk(rp,k),i,r) =             tResProfile(k,rp,i,r)         ;
pResProfile (rpk(rp,k),i,s) =                                      1    ;

* Thermal generation parameters
pEFOR        (t) = tThermalGen(t,'EFOR'        ) ;
pEnabInv     (t) = tThermalGen(t,'EnableInvest') ;
pInertiaConst(t) = tThermalGen(t,'InertiaConst') ;
pMaxProd     (t) = tThermalGen(t,'MaxProd'     ) * 1e-3 * [1-pEFOR(t)] ;
pMinProd     (t) = tThermalGen(t,'MinProd'     ) * 1e-3 * [1-pEFOR(t)] ;
pRampUp      (t) = tThermalGen(t,'RampUp'      ) * 1e-3                ;
pRampDw      (t) = tThermalGen(t,'RampDw'      ) * 1e-3                ;
pMaxGenQ     (t) = tThermalGen(t,'Qmax'        ) * 1e-3 ;
pMinGenQ     (t) = tThermalGen(t,'Qmin'        ) * 1e-3 ;
pEffic       (t) = tThermalGen(t,'InterVarCost') * 1e-3 * pkWh_Mcal ;
pSlopeVarCost(t) = tThermalGen(t,'OMVarCost'   ) * 1e-3 +
                   tThermalGen(t,'SlopeVarCost') * 1e-3 * tThermalGen(t,'FuelCost') ;
pInterVarCost(t) = tThermalGen(t,'InterVarCost') * 1e-6 * tThermalGen(t,'FuelCost') ;
pStartupCost (t) = tThermalGen(t,'StartupCost' ) * 1e-6 * tThermalGen(t,'FuelCost') ;
pStartupCons (t) = tThermalGen(t,'StartupCost' ) * 1e-6 * pkWh_Mcal ;
pInvestCost  (t) = tThermalGen(t,'InvestCost'  ) * 1e-3 *
                   pMaxProd   (t               ) ;
pFirmCapCoef (t) = tThermalGen(t,'FirmCapCoef' ) ;
pCO2Emis     (t) = tThermalGen(t,'CO2Emis'     ) * 1e-3 ;
* For the linearization of the RoCoF, the UC variables must have a limit of 1
pExisUnits   (t) = min[1,tThermalGen(t,'ExisUnits')] ;
pMaxInvest   (t) $[pExisUnits(t)=1] = 0              ;
pMaxInvest   (t) $[pExisUnits(t)=0] = 1              ;

* Storage units parameters
pExisUnits   (s) = tStorage   (s,'ExisUnits'   )        ;
pMaxInvest   (s) = tStorage   (s,'MaxInvest'   )        ;
pMaxProd     (s) = tStorage   (s,'MaxProd'     ) * 1e-3 ;
pMinProd     (s) = tStorage   (s,'MinProd'     ) * 1e-3 ;
pMaxCons     (s) = tStorage   (s,'MaxCons'     ) * 1e-3 ;
pOMVarCost   (s) = tStorage   (s,'OMVarCost'   ) * 1e-3 ;
pMaxGenQ     (s) = tStorage   (s,'Qmax'        ) * 1e-3 ;
pMinGenQ     (s) = tStorage   (s,'Qmin'        ) * 1e-3 ;
pReplaceCost (s) = tStorage   (s,'ReplaceCost' ) * 1e-3 ;
pInertiaConst(s) = tStorage   (s,'InertiaConst')        ;
pDisEffic    (s) = tStorage   (s,'DisEffic'    )        ;
pChEffic     (s) = tStorage   (s,'ChEffic'     )        ;
pIsHydro     (s) = tStorage   (s,'IsHydro'     )        ;
pEnabInv     (s) = tStorage   (s,'EnableInvest')        ;
pE2PRatio    (s) = tStorage   (s,'Ene2PowRatio')        ;
pShelfLife   (s) = tStorage   (s,'ShelfLife'   )        ;
pCDSF_alpha  (s) = tStorage   (s,'CDSF_alpha'  )        ;
pCDSF_beta   (s) = tStorage   (s,'CDSF_beta '  )        ;
pMinReserve  (s) = tStorage   (s,'MinReserve'  )        ;
pIniReserve  (s) = tStorage   (s,'IniReserve'  )        *
                   pMaxProd   (s               )        *
                   pE2PRatio  (s               )        ;
pFirmCapCoef (s) = tStorage   (s,'FirmCapCoef' )        ;

pInvestCost  (s) = tStorage   (s,'MaxProd'         ) * 1e-3 *
                  [tStorage   (s,'InvestCostPerMW' ) * 1e-3 +
                   tStorage   (s,'InvestCostPerMWh') * 1e-3 *
                   pE2PRatio  (s                   ) ]      ;

pDisEffic(s) $[pDisEffic(s) = 0] = 1 ; // if the efficiency of a storage unit is 0, it is changed to 1

cdsf      (s  ) $[pCDSF_alpha (s) and [not pIsHydro(s)] and pEnableCDSF] = yes ;
pCDSF_phi (s,a) $[ cdsf       (s)]= pCDSF_alpha (s  )*rPower[ord(a)     /card(a),pCDSF_beta(s)] ;
pCDSF_cost(s,a) $[ cdsf       (s)]=[pReplaceCost(s  )/pDisEffic (s    )]*card(a)*
                                   [pCDSF_phi   (s,a)-pCDSF_phi (s,a-1)] ;

* Renewable parameters
pExisUnits   (r) = tRenewable (r,'ExisUnits'   )        ;
pMaxInvest   (r) = tRenewable (r,'MaxInvest'   )        ;
pEnabInv     (r) = tRenewable (r,'EnableInvest')        ;
pInertiaConst(r) = tRenewable (r,'InertiaConst')        ;
pMaxProd     (r) = tRenewable (r,'MaxProd'     ) * 1e-3 ;
pMaxGenQ     (r) = tRenewable (r,'Qmax'        ) * 1e-3 ;
pMinGenQ     (r) = tRenewable (r,'Qmin'        ) * 1e-3 ;
pOMVarCost   (r) = tRenewable (r,'OMVarCost'   ) * 1e-3 ;
pInvestCost  (r) = tRenewable (r,'InvestCost'  ) * 1e-3 *
                   tRenewable (r,'MaxProd'     ) * 1e-3 ;
pFirmCapCoef (r) = tRenewable (r,'FirmCapCoef' )        ;

*Network parameters
pMaxAngleDiff = pMaxAngleDiff                * pi/180 ;
pSBase        = pSBase                       * 1e-3   ;
pRline    (la)= tNetwork (la,'R'           )          ;
pXline    (la)= tNetwork (la,'X'           )          ;
pPmax     (la)= tNetwork (la,'Pmax'        ) * 1e-3   ;
pQmax     (la)= tNetwork (la,'Pmax'        ) * 1e-3   ; //assumption: it is equal to active limit
pBcline   (la)= tNetwork (la,'Bc'          )          ;
pAngle    (la)= tNetwork (la,'TapAngle'    ) * pi/180 ;
pRatio    (la)= tNetwork (la,'TapRatio'    )          ;
pFixedCost(la)= tNetwork (la,'FixedCost'   ) *
                tNetwork (la,'FxChargeRate')          ;
pBline    (la)= -pXline  (la)/[sqr[pRline(la)]+sqr[pXline(la)]] ;
pGline    (la)=  pRline  (la)/[sqr[pRline(la)]+sqr[pXline(la)]] ;

*Bus parameters
pBusBaseV  (i) = tBusInfo(i,'BaseVolt'   ) ;
pBusMaxV   (i) = tBusInfo(i,'maxVolt'    ) ;
pBusMinV   (i) = tBusInfo(i,'minVolt'    ) ;
pBusB      (i) = tBusInfo(i,'Bs'         ) ;
pBusG      (i) = tBusInfo(i,'Gs'         ) ;
pBus_pf    (i) = tBusInfo(i,'PowerFactor') ;
pRatioDemQP(i) = tan(arccos(pBus_pf(i))  ) ;

* FACTS for reactive power enery
pExisUnits (facts) = tFACTS  (facts,'ExisUnits'   )        ;
pEnabInv   (facts) = tFACTS  (facts,'EnableInvest')        ;
pMaxGenQ   (facts) = tFACTS  (facts,'Qmax'        ) * 1e-3 ;
pMinGenQ   (facts) = tFACTS  (facts,'Qmin'        ) * 1e-3 ;
pMaxInvest (facts) = tFACTS  (facts,'MaxInvest'   )        ;
pInvestCost(facts) = tFACTS  (facts,'InvestCost'  ) * 1e-3 *
                     pMaxGenQ(facts               )        ;

* active, reactive and peak demand
pDemandP(rpk(rp,k),i) = tDemand(k,rp,i)                  * 1e-3 ;
pDemandQ(rpk(rp,k),i) = tDemand(k,rp,i) * pRatioDemQP(i) * 1e-3 ;
pPeakDemand           = smax((rp,k)$rpk(rp,k),sum(i,pDemandP(rp,k,i)));

* demand-side management
pMaxUpDSM(rpk(rp,k),i,sec) = tDSMprofile(k,rp,sec,'Up')   * tDemand(k,rp,i) * 1e-3 ;
pMaxDnDSM(rpk(rp,k),i,sec) = tDSMprofile(k,rp,sec,'Down') * tDemand(k,rp,i) * 1e-3 ;
pDSMShedCost (seg)         = tDSMshed(seg,'ShedPenalty'   )                 * 1e-3 ;
pDSMShedRatio(seg)         = tDSMshed(seg,'ShedPercentage')                        ;
pDelayTime   (sec,rp     ) = tDelayTime(sec,rp)                                    ;

* DSM subset
dsm(rp,k,kk,sec) = no ;

loop[(rp,k,kk,sec),
    if [ord(k) <> ord(kk),
        if   [ord(k) - ord(kk) > 0,
                if[ord(k) - ord(kk) <= pDelayTime(sec,rp),
                    dsm(rp,k,kk,sec) = yes];
        else
             if[ord(k) - ord(kk) <= -12,
                if[24 - (ord(kk) - ord(k)) <= pDelayTime(sec,rp),
                    dsm(rp,k,kk,sec) = yes];
             else
                if[ord(kk) - ord(k) <= pDelayTime(sec,rp),
                    dsm(rp,k,kk,sec) = yes];
                ]
             ]
       ]
    ]
;

* hydrogen parameters
pH2NSCost = pH2NSCost * 1e-3 ;

pH2Demand(rpk(rp,k),h2i,h2sec) = tH2Demand(h2sec,k,rp,h2i) * 1e-3 ;

pH2ExisUnits (h2g   ) = tH2GenUnits(h2g   ,'ExisUnits'   )        ;
pH2MaxInvest (h2g   ) = tH2GenUnits(h2g   ,'MaxInvest'   )        ;
pH2PE        (h2g   ) = tH2GenUnits(h2g   ,'H2Effic'     )        ;
pH2_pf       (h2g   ) = tH2GenUnits(h2g   ,'PowerFactor' )        ;
pH2MaxCons   (h2g   ) = tH2GenUnits(h2g   ,'MaxCons'     ) * 1e-3 ;
pH2OMPercent (h2g   ) = tH2GenUnits(h2g   ,'OMVarCost'   )        ;
pH2InvestCost(h2g   ) = tH2GenUnits(h2g   ,'InvestCost'  ) * 1e-3 *
                        tH2GenUnits(h2g   ,'MaxCons'     ) * 1e-3 ;

pH2OMVarCost (h2g   ) = pH2InvestCost(h2g) * pH2OMPercent (h2g)   ;

pH2Fmax      (h2line) = tH2Network (h2line,'Fmax'        ) * 1e-3 ;

pH2RatioQP   (h2g   ) = tan(arccos(pH2_pf(h2g))  ) ;

* update parameter to calculate regret
pRegretCalc $[%RegretCalc%=0 or  card(p)>card(k)] = 0 ;
pRegretCalc $[%RegretCalc%=1 and card(p)=card(k)] = 1 ;

* initializing parameter for SOCP ex-post calculations
pDelVolAng  (rpk(rp,k),i,j) $[isLine(i,j)] = 0;

* parameters for RoCoF
*pDeltaP(rpk(rp,k)) = pMinInertia * [pMaxRoCoF/pBaseFreq] ;
pDeltaP(rpk(rp,k)) = 0.3 ;

$offFold


*-------------------------------------------------------------------------------
*                          Bounds for Variables
*-------------------------------------------------------------------------------
$onFold // Bounds for variables ------------------------------------------------

vGenP.up      (rpk(rp,k),t) =  pMaxProd  (t)                  *
                              [pMaxInvest(t) + pExisUnits(t)] ;
vGenP1.up     (rpk(rp,k),t) = [pMaxProd  (t) - pMinProd  (t)] *
                              [pMaxInvest(t) + pExisUnits(t)] ;
v2ndResUP.up  (rpk(rp,k),t) = [pMaxProd  (t) - pMinProd  (t)] *
                              [pMaxInvest(t) + pExisUnits(t)] ;
v2ndResDW.up  (rpk(rp,k),t) = [pMaxProd  (t) - pMinProd  (t)] *
                              [pMaxInvest(t) + pExisUnits(t)] ;

vGenQ.up      (rpk(rp,k),ga(g)) =  pMaxGenQ  (g)              ;
vGenQ.lo      (rpk(rp,k),ga(g)) =  pMinGenQ  (g)              ;

vGenP.up      (rpk(rp,k),s) =  pMaxProd  (s) *[pMaxInvest(s)+pExisUnits(s)];
v2ndResUP.up  (rpk(rp,k),s) =  pMaxProd  (s) *[pMaxInvest(s)+pExisUnits(s)];
vConsump.up   (rpk(rp,k),s) =  pMaxProd  (s) *[pMaxInvest(s)+pExisUnits(s)];
v2ndResDW.up  (rpk(rp,k),s) =  pMaxProd  (s) *[pMaxInvest(s)+pExisUnits(s)];

vDSM_Up.up    (rpk(rp,k),i,sec)$[    pDSM] =  pMaxUpDSM (rp,k,i,sec);
vDSM_Dn.up    (rpk(rp,k),i,sec)$[    pDSM] =  pMaxDnDSM (rp,k,i,sec);
vDSM_Shed.up  (rpk(rp,k),i,seg)$[    pDSM] =  pDSMShedRatio(seg) * pDemandP(rp,k,i);
vDSM_Up.fx    (rpk(rp,k),i,sec)$[not pDSM] =  0;
vDSM_Dn.fx    (rpk(rp,k),i,sec)$[not pDSM] =  0;
vDSM_Shed.fx  (rpk(rp,k),i,seg)$[not pDSM] =  0;

vStIntraRes.up(rpk(rp,k),s) =  pE2PRatio (s) *
                               pMaxProd  (s) *[pMaxInvest (s)+pExisUnits(s)] ;
vStIntraRes.lo(rpk(rp,k),s) =  pE2PRatio (s) * pMinReserve(s)*
                               pMaxProd  (s) *[pMaxInvest (s)+pExisUnits(s)] ;

vCDSF_dis.up  (rpk(rp,k),s,a) $[cdsf(s)] = pMaxProd (s) *[pMaxInvest(s)+pExisUnits(s)] ;
vCDSF_ch.up   (rpk(rp,k),s,a) $[cdsf(s)] = pMaxCons (s) *[pMaxInvest(s)+pExisUnits(s)] ;
vCDSF_SoC.up  (rpk(rp,k),s,a) $[cdsf(s)] = pE2PRatio(s) *
                                           pMaxCons (s) *[pMaxInvest(s)+pExisUnits(s)] ;

vSpillag.up   (rpk(rp,k),s) =  vStIntraRes.up(rp,k,s) -
                               vStIntraRes.lo(rp,k,s) ;
vWaterSell.up (rpk(rp,k),s) =  vStIntraRes.up(rp,k,s) -
                               vStIntraRes.lo(rp,k,s) ;

vStInterRes.up(p,s) $[mod(ord(p),pMovWind)=0] = pMaxProd(s)*[pMaxInvest(s)+pExisUnits(s)]*pE2PRatio(s)                ;
vStInterRes.lo(p,s) $[mod(ord(p),pMovWind)=0] = pMaxProd(s)*[pMaxInvest(s)+pExisUnits(s)]*pE2PRatio(s)*pMinReserve(s) ;

vLineP.up   (rpk(rp,k),i,j,c) $[le(i,j,c)]  =  pPmax (i,j,c) ;
vLineP.lo   (rpk(rp,k),i,j,c) $[le(i,j,c)]  = -pPmax (i,j,c) ;
vLineP.up   (rpk(rp,k),j,i,c) $[le(i,j,c)]  =  pPmax (i,j,c) ;
vLineP.lo   (rpk(rp,k),j,i,c) $[le(i,j,c)]  = -pPmax (i,j,c) ;

vLineQ.up   (rpk(rp,k),i,j,c) $[le(i,j,c)]  =  pQmax (i,j,c) ;
vLineQ.lo   (rpk(rp,k),i,j,c) $[le(i,j,c)]  = -pQmax (i,j,c) ;
vLineQ.up   (rpk(rp,k),j,i,c) $[le(i,j,c)]  =  pQmax (i,j,c) ;
vLineQ.lo   (rpk(rp,k),j,i,c) $[le(i,j,c)]  = -pQmax (i,j,c) ;

vSOCP_cii.up(rpk(rp,k),i    )              =         sqr[pBusMaxV(i)]  ;
vSOCP_cii.lo(rpk(rp,k),i    )              =         sqr[pBusMinV(i)]  ;
vSOCP_cij.up(rpk(rp,k),i,j  ) $[isLe(i,j)] =         sqr[pBusMaxV(i)]  ;
vSOCP_cij.lo(rpk(rp,k),i,j  ) $[isLe(i,j)] = max[0.1,sqr[pBusMinV(i)]] ; // This lower bound is always > 0
vSOCP_sij.up(rpk(rp,k),i,j  ) $[isLe(i,j)] =         sqr[pBusMaxV(i)]  ;
vSOCP_sij.lo(rpk(rp,k),i,j  ) $[isLe(i,j)] =        -sqr[pBusMaxV(i)]  ;

* slack bus voltage and angle
vSOCP_cii.fx(rpk(rp,k),is)$[    pEnableSOCP] = sqr[pSlackVolt] ;
vTheta.fx   (rpk(rp,k),is)$[not pEnableSOCP] = 0   ;

vPNS.up     (rpk(rp,k),i  ) =  pDemandP   (rp,k,i)   ;


vGenInvest.up(ga(g))                    = floor[pMaxInvest(g)] ;
vGenInvest.fx(ga(g)) $[not pEnabInv(g)] = 0                    ;

vLineInvest.fx(i,j,c)$[isLc(i,j) and le(i,j,c)]=0;

vRoCoF_AuxY.up(rpk(rp,k),tt,t  )$[pEnableRoCoF] =  1       ;
vRoCoF_AuxW.up(rpk(rp,k),vv,v,m)$[pEnableRoCoF] =  1       ;
vRoCoF_k.up   (rpk(rp,k),t     )$[pEnableRoCoF] =  1       ;
vRoCoF_k.up   (rpk(rp,k),v     )$[pEnableRoCoF] =  1       ;
vRoCoF_SG_M.up(rpk(rp,k)       )$[pEnableRoCoF] =  pUBLin  ;
vRoCoF_VI_M.up(rpk(rp,k)       )$[pEnableRoCoF] =  pUBLin  ;
vRoCoF_AuxZ.up(rpk(rp,k),t     )$[pEnableRoCoF] =  pUBLin  ;
vRoCoF_AuxV.up(rpk(rp,k),v,   m)$[pEnableRoCoF] =  pUBLin  ;

* last hour condition for storage
vStIntraRes.fx(rpk(rp,k),s) $[card(rp)=1 and ord(k)=card(k)] = pIniReserve(s) ;
vStInterRes.fx( p       ,s) $[card(rp)>1 and ord(p)=card(p)] = pIniReserve(s) ;

* spillage variable only for hydro units
vSpillag.fx(rpk(rp,k),s) $[pIsHydro(s)=0] = 0 ;

* bounds on variables for single node case
if(card(i)=1,
   vPNS.up     (rpk(rp,k),is)             = sum[j, pDemandP(rp,k,j)] ;
   vPNS.fx     (rpk(rp,k),i ) $[not is(i)]= 0                        ;

   if(pDSM,
   vDSM_Up.up  (rpk(rp,k),is,sec)$[pDSM]      =  sum[j, pMaxUpDSM (rp,k,j,sec)];
   vDSM_Dn.up  (rpk(rp,k),is,sec)$[pDSM]      =  sum[j, pMaxDnDSM (rp,k,j,sec)];
   vDSM_Shed.up(rpk(rp,k),is,seg)$[pDSM]      =  sum[j, pDemandP  (rp,k,j)] * pDSMShedRatio(seg);
   vDSM_Up.fx  (rpk(rp,k),i ,sec)$[not is(i)] =  0;
   vDSM_Dn.fx  (rpk(rp,k),i ,sec)$[not is(i)] =  0;
   vDSM_Shed.fx(rpk(rp,k),i ,seg)$[not is(i)] =  0;
   );
);

* bounds for hydrogen variables
vH2NS.up    (rpk(rp,k),       h2i,h2sec)$[pEnableH2] =  pH2Demand   (rp,k,h2i,h2sec) ;
vH2Flow.up  (rpk(rp,k),h2line(h2i,h2j) )$[pEnableH2] =  pH2Fmax     (     h2i,h2j  ) ;
vH2Flow.lo  (rpk(rp,k),h2line(h2i,h2j) )$[pEnableH2] = -pH2Fmax     (     h2i,h2j  ) ;
vH2Invest.up(          h2g             )$[pEnableH2] =  pH2MaxInvest(     h2g      ) ;

$offFold


*-------------------------------------------------------------------------------
*                                    Solve
*-------------------------------------------------------------------------------
$onFold // Solve ---------------------------------------------------------------

* update info depending on UC.gdx file
$if not exist "./UC.gdx" pRegretCalc =0                       ;
$if not exist "./UC.gdx" pCommit(p,t)=0                       ;
$if not exist "./UC.gdx" pStLvMW(p,s)=0                       ;
$if     exist "./UC.gdx" execute_load 'UC.gdx' pCommit pStLvMW;

* solve depending on options
if    (pRMIP=1 and pRegretCalc=0,
   solve LEGO using RMIQCP minimizing vTotalVCost ;

elseif(pRMIP=1 and pRegretCalc=1),
   vCommit.fx    (rpk(rp,k),t) $[sum[hindex(p,rp,k), pCommit(p,t)]=1] = sum[hindex(p,rp,k), pCommit(p,t)];
   vStIntraRes.fx(rpk(rp,k),s) $[sum[hindex(p,rp,k), pStLvMW(p,s)]>0] = sum[hindex(p,rp,k), pStLvMW(p,s)];
   solve LEGO using RMIQCP minimizing vTotalVCost ;

elseif(pRMIP=0 and pRegretCalc=0),
   solve LEGO using  MIQCP minimizing vTotalVCost ;

elseif(pRMIP=0 and pRegretCalc=1),
   vCommit.fx    (rpk(rp,k),t) $[sum[hindex(p,rp,k), pCommit(p,t)]=1] = sum[hindex(p,rp,k), pCommit(p,t)];
   vStIntraRes.fx(rpk(rp,k),s) $[sum[hindex(p,rp,k), pStLvMW(p,s)]>0] = sum[hindex(p,rp,k), pStLvMW(p,s)];
   solve LEGO using  MIQCP minimizing vTotalVCost ;
);

if(pEnableSOCP,
   vTheta.fx (rpk(rp,k),is ) = 0 ;
   isLine(i,j) = sum[c,le(i,j,c)+lc(i,j,c)$vLineInvest.l(i,j,c)];
   pDelVolAng(rpk(rp,k),i,j) $[isLine(i,j)] =  arctan2[vSOCP_sij.l(rp,k,i,j), vSOCP_cij.l(rp,k,i,j)] ;
   pEnableDummyModel = 1
   solve mDummy min vDummyOf using lp;  // in order to find vTheta values
   pEnableDummyModel = 0
);

$offFold


*-------------------------------------------------------------------------------
*                  Calculating Ex Post Parameters for Results
*-------------------------------------------------------------------------------
$onFold // Calculating Ex Post Parameters for Results --------------------------
pSummary('------------- MODEL STATISTICS -------------  ') = eps ;
pSummary('Obj Func  Model                      [M$   ]  ') = LEGO.objVal  + eps ;
pSummary('CAPEX (GEP, TEP, H2GEP)              [M$   ]  ') = + sum[ga(g    ), pInvestCost  (g    )* vGenInvest.l (g    )]
                                                             + sum[lc(i,j,c), pFixedCost   (i,j,c)* vLineInvest.l(i,j,c)]
                                                             + sum[h2u      , pH2InvestCost(h2u  )* vH2Invest.l  (h2u  )] $[pEnableH2]
                                                             + eps;
pSummary('OPEX                                 [M$   ]  ') = vTotalVCost.l
                                                             - sum[ga(g    ), pInvestCost  (g    )* vGenInvest.l (g    )]
                                                             - sum[lc(i,j,c), pFixedCost   (i,j,c)* vLineInvest.l(i,j,c)]
                                                             - sum[h2u      , pH2InvestCost(h2u  )* vH2Invest.l  (h2u  )] $[pEnableH2]
                                                             - eps;

pSummary('CPU Time  Model generation           [s    ]  ') = LEGO.resGen  + eps ;
pSummary('CPU Time  Model solution             [s    ]  ') = LEGO.resUsd  + eps ;
pSummary('Number of variables                           ') = LEGO.numVar  + eps ;
pSummary('Number of discrete variables                  ') = LEGO.numDVar + eps ;
pSummary('Number of equations                           ') = LEGO.numEqu  + eps ;
pSummary('Number of nonzero elements                    ') = LEGO.numNZ   + eps ;
pSummary('Best possible solution for MIP                ') = LEGO.objest  + eps ;
pSummary('Results for regret calculation                ') = pRegretCalc  + eps ;
pSummary('Network Constraints 1->yes                    ') = pTransNet    + eps ;
pSummary('1->SOCP , 0->DC                               ') = pEnableSOCP  + eps ;
pSummary('1->RoCoF, 0->MinInert                         ') = pEnableRoCoF + eps ;

pSummary('SOCP Mean Error') $[not pEnableSOCP] = eps ;
pSummary('SOCP Mean Error') $[    pEnableSOCP] =
 sum[(rpk(rp,k),i,j)$isLine(i,j),
   + vSOCP_cii.l(rp,k,i  ) * vSOCP_cii.l(rp,k,j  )
   - vSOCP_cij.l(rp,k,i,j) * vSOCP_cij.l(rp,k,i,j)
   - vSOCP_sij.l(rp,k,i,j) * vSOCP_sij.l(rp,k,i,j)] /
 sum[(rpk(rp,k),i,j)$isLine(i,j),
   + vSOCP_cii.l(rp,k,i  ) * vSOCP_cii.l(rp,k,j  )]
;

pSummary('--------------- POWER SYSTEM ---------------') = eps ;
pSummary('Total system demand                  [GWh  ]') = sum[(rp,k)        ,pWeight_rp(rp)*pWeight_k(k)*sum[j, pDemandP (rp,k,j)]] + eps;
pSummary('Total renewable + storage production [GWh  ]') = sum[(rp,k)        ,pWeight_rp(rp)*pWeight_k(k)*[+ sum[gi(r,j), vGenP.L(rp,k,r)]
                                                                                                           + sum[gi(s,j), vGenP.L(rp,k,s)]]] + eps;
pSummary('Total renewable curtailment          [GWh  ]') = sum[(rp,k,gi(r,i)),[pResProfile(rp,k,i,r)*pMaxProd(r)*[vGenInvest.l(r)+pExisUnits(r)] - vGenP.l(rp,k,r)]*1e3] + eps ;                                                                                                
pSummary('Total thermal production             [GWh  ]') = sum[(rp,k)        ,pWeight_rp(rp)*pWeight_k(k)*[+ sum[gi(t,j), vGenP.L(rp,k,t)]]] + eps;
pSummary('Actual green  production             [p.u. ]') = pSummary('Total renewable + storage production [GWh  ]') / pSummary('Total system demand                  [GWh  ]') + eps;
pSummary('Actual thermal production            [p.u. ]') = pSummary('Total thermal production             [GWh  ]') / pSummary('Total system demand                  [GWh  ]') + eps;
pSummary('Actual CO2 emissions                 [MtCO2]') = sum[(rp,k,t)      ,pWeight_rp(rp)*pWeight_k(k)*  pCO2Emis(t) * vGenP.L(rp,k,t)] + eps;

pSummary('Thermal            Investment        [GW   ]') = sum[t        , vGenInvest.l (t    ) * pMaxProd(t    )] + eps;
pSummary('Renewable          Investment        [GW   ]') = sum[r        , vGenInvest.l (r    ) * pMaxProd(r    )] + eps;
pSummary('Storage            Investment        [GW   ]') = sum[s        , vGenInvest.l (s    ) * pMaxProd(s    )] + eps; 
pSummary('Transmission lines Investment        [GW   ]') = sum[lc(i,j,c), vLineInvest.l(i,j,c) * pPmax   (i,j,c)] + eps;

pSummary('Energy non-supplied                  [GWh  ]') = sum[(rp,k),pWeight_rp(rp)*pWeight_k(k)*sum[j          , vPNS.l (rp,k,j        )]] + eps;

pSummary('-------------- HYDROGEN SYSTEM -------------') = eps ;
pSummary('H2     non-supplied                  [t    ]') = sum[(rp,k),pWeight_rp(rp)*pWeight_k(k)*sum[(h2i,h2sec), vH2NS.l(rp,k,h2i,h2sec)]] + eps;

pSummary('-------------- CO2 EMISSIONS ---------------') = eps ;
pSummary('Budget CO2 emissions                 [MtCO2]') = pCO2Budget + eps ;
pSummary('Actual CO2 emissions                 [MtCO2]') = sum[(rp,k,t), pWeight_rp(rp)* pCO2Emis(t)*pEffic(t) * [[pStartupCons(t)*vStartup.l(rp,k,t)] + [pWeight_k(k)*vGenP.l(rp,k,t)]]]$[pEnableCO2] + eps ;
pSummary('CO2-target overshoot                 [MtCO2]') = vCO2Overshoot.l + eps;

pSummary('----------------- POLICIES -----------------') = eps ;
pSummary('Cost renewable quota                 [$/MWh]') = - eCleanProd.m  * 1e3 + eps;
pSummary('Payment firm capacity                [$/MW ]') =   eFirmCapCon.m * 1e3 + eps;
*calculated later with H2 results:   pSummary('Levelized cost of H2            [$/kg ]')

$offFold

$onFold // Investment Results --------------------------------------------------

pGenInvest (ga(g)    ,'[MW]  ') = pMaxProd(    g)*vGenInvest.l (    g) * 1e3 + eps ;
pGenInvest (ga(g)    ,'[MVar]') = pMaxGenQ(    g)*vGenInvest.l (    g) * 1e3 + eps ;
pTraInvest (lc(i,j,c),'[MW]  ') = pPmax   (i,j,c)*vLineInvest.l(i,j,c) * 1e3 + eps ;

$offFold

$onFold // Operating Dispatch Results ------------------------------------------

pCommit  (p,t    ) = sum[hindex(p,rpk(rp,k)), vCommit.l (rp,k,t)    ]   + eps ;
pGenP    (p,ga(g)) = sum[hindex(p,rpk(rp,k)), vGenP.l   (rp,k,g)*1e3]   + eps ;
pGenQ    (p,ga(g)) = sum[hindex(p,rpk(rp,k)), vGenQ.l   (rp,k,g)*1e3]   + eps ;
pChrP    (p,   s ) = sum[hindex(p,rpk(rp,k)), vConsump.l(rp,k,s)*1e3]   + eps ;
pCurtP_k (rp,k,r ) = sum[   gi(r,i)         ,[pResProfile(rp,k,i,r)*pMaxProd(r)*[vGenInvest.l(r)+pExisUnits(r)] - vGenP.l(rp,k,r)]*1e3] + eps ;
pCurtP_rp(rp,  r ) = sum[(k,gi(r,i))        ,[pResProfile(rp,k,i,r)*pMaxProd(r)*[vGenInvest.l(r)+pExisUnits(r)] - vGenP.l(rp,k,r)]*1e3] + eps ;


pStIntra (k,s,rp) $[rpk(rp,k) and [card(rp)=1]                      ] = vStIntraRes.l(rp,k,s) / [pMaxProd(s)*[vGenInvest.l(s)+pExisUnits(s)]*pE2PRatio(s) + 1e-6] + eps ;
pStIntra (k,s,rp) $[rpk(rp,k) and [card(rp)>1] and [not pIsHydro(s)]] = vStIntraRes.l(rp,k,s) / [pMaxProd(s)*[vGenInvest.l(s)+pExisUnits(s)]*pE2PRatio(s) + 1e-6] + eps ;

pStLevel (p,s   ) $[[card(rp)=1]                      ] = sum[hindex   (p,rpk(rp,k)) , pStIntra(k,s,rp)]    ;
pStLevel (p,s   ) $[[card(rp)>1] and [not pIsHydro(s)]] = sum[hindex   (p,rpk(rp,k)) , pStIntra(k,s,rp)]    ;
pStLevel (p,s   ) $[[card(rp)>1] and [    pIsHydro(s)]] = vStInterRes.l(p   ,s) / [pMaxProd(s)*[vGenInvest.l(s)+pExisUnits(s)]*pE2PRatio(s) + 1e-6] + eps ;

pStLvMW  (p,s   ) $[[card(rp)=1] and [    pIsHydro(s)] and [mod(ord(p),pMovWind)=0]] = sum[hindex(p,rpk(rp,k)), vStIntraRes.l(rp,k,s)] + eps ;
pStLvMW  (p,s   ) $[[card(rp)>1] and [    pIsHydro(s)] and [mod(ord(p),pMovWind)=0]] =                          vStInterRes.l( p  ,s)  + eps ;

pLineP(k,i,j,c,rp) $[rpk(rp,k) and la(i,j,c) and not pTransNet                    ] =                               eps ;
pLineP(k,i,j,c,rp) $[rpk(rp,k) and la(i,j,c) and     pTransNet                    ] =  vLineP.l(rp,k,i,j,c) * 1e3 + eps ;
pLineP(k,j,i,c,rp) $[rpk(rp,k) and la(i,j,c) and     pTransNet and not pEnableSOCP] = -vLineP.l(rp,k,i,j,c) * 1e3 + eps ;
pLineP(k,j,i,c,rp) $[rpk(rp,k) and la(i,j,c) and     pTransNet and     pEnableSOCP] =  vLineP.l(rp,k,j,i,c) * 1e3 + eps ;
pLineQ(k,i,j,c,rp) $[rpk(rp,k) and la(i,j,c) and not pTransNet                    ] =                               eps ;
pLineQ(k,i,j,c,rp) $[rpk(rp,k) and la(i,j,c) and     pTransNet and not pEnableSOCP] =                               eps ;
pLineQ(k,i,j,c,rp) $[rpk(rp,k) and la(i,j,c) and     pTransNet and     pEnableSOCP] =  vLineQ.l(rp,k,i,j,c) * 1e3 + eps ;
pLineQ(k,j,i,c,rp) $[rpk(rp,k) and la(i,j,c) and     pTransNet and     pEnableSOCP] =  vLineQ.l(rp,k,j,i,c) * 1e3 + eps ;

pTecProd (i,tec         ,'Total [GWh]'  )                =  sum[(rpk(rp,k),ga(g))$[gtec(g,tec) and gi(g,i)], pWeight_rp(rp)*pWeight_k(k)* vGenP.l    (rp,k,g    )               ] + eps ;
pTecProd (i,'Sto_Charge','Total [GWh]'  )                = -sum[(rpk(rp,k),   s )$[                gi(s,i)], pWeight_rp(rp)*pWeight_k(k)* vConsump.l (rp,k,s    )               ] + eps ;
pTecProd (i,'ENS'       ,'Total [GWh]'  )                =  sum[ rpk(rp,k)                                 , pWeight_rp(rp)*pWeight_k(k)* vPNS.l     (rp,k,i    )               ] + eps ;
pTecProd (i,'P_Demand'  ,'Total [GWh]'  )                = -sum[ rpk(rp,k)                                 , pWeight_rp(rp)*pWeight_k(k)* pDemandP   (rp,k,i    )               ] + eps ;
pTecProd (i,'P_DSM_Shed','Total [GWh]'  ) $[pDSM       ] =  sum[(rpk(rp,k),seg)                            , pWeight_rp(rp)*pWeight_k(k)* vDSM_Shed.l(rp,k,i,seg)               ] + eps ;
pTecProd (i,'P_NetFlo'  ,'Total [GWh]'  )                = -sum[(rpk(rp,k),j,c  )$[la (i,j,c)             ], pWeight_rp(rp)*pWeight_k(k)* vLineP.l   (rp,k,i,j,c)               ]
                                                           +sum[(rpk(rp,k),j,c  )$[la (j,i,c)             ], pWeight_rp(rp)*pWeight_k(k)* vLineP.l   (rp,k,j,i,c)               ] + eps ;
pTecProd (i,'P_NetFlo'  ,'Total [GWh]'  ) $[pEnableSOCP] = -sum[(rpk(rp,k),j,c  )$[la (i,j,c)             ], pWeight_rp(rp)*pWeight_k(k)* vLineP.l   (rp,k,i,j,c)               ]
                                                           -sum[(rpk(rp,k),j,c  )$[la (j,i,c)             ], pWeight_rp(rp)*pWeight_k(k)* vLineP.l   (rp,k,i,j,c)               ] + eps ;

pTecProd (i,tec         ,'Total [GVarh]') $[pEnableSOCP] =  sum[(rpk(rp,k),ga(g))$[gtec(g,tec) and gi(g,i)], pWeight_rp(rp)*pWeight_k(k)* vGenQ.l    (rp,k,g    )               ] + eps ;
pTecProd (i,'QNS'       ,'Total [GVarh]') $[pEnableSOCP] =  sum[ rpk(rp,k)                                 , pWeight_rp(rp)*pWeight_k(k)* vPNS.l     (rp,k,i    )*pRatioDemQP(i)] + eps ;
pTecProd (i,'Q_Demand'  ,'Total [GVarh]') $[pEnableSOCP] = -sum[ rpk(rp,k)                                 , pWeight_rp(rp)*pWeight_k(k)* pDemandQ   (rp,k,i    )*pEnableSOCP   ] + eps ;
pTecProd (i,'Q_NetFlo'  ,'Total [GVarh]') $[pEnableSOCP] = -sum[(rpk(rp,k),j,c  )$[la (i,j,c)             ], pWeight_rp(rp)*pWeight_k(k)* vLineQ.l   (rp,k,i,j,c)               ]
                                                           -sum[(rpk(rp,k),j,c  )$[la (j,i,c)             ], pWeight_rp(rp)*pWeight_k(k)* vLineQ.l   (rp,k,i,j,c)               ] + eps ;
pTecProd (i,'Q_DSM_Shed','Total [GVarh]') $[pEnableSOCP
                                            and    pDSM] =  sum[(rpk(rp,k),seg)                            , pWeight_rp(rp)*pWeight_k(k)* vDSM_Shed.l(rp,k,i,seg)*pRatioDemQP(i)] + eps ;

pVoltage(k,i,rp)$[rpk(rp,k) and not pTransNet                    ] = 1                         + eps ;
pVoltage(k,i,rp)$[rpk(rp,k) and     pTransNet and not pEnableSOCP] = 1                         + eps ;
pVoltage(k,i,rp)$[rpk(rp,k) and     pTransNet and     pEnableSOCP] = sqrt[vSOCP_cii.l(rp,k,i)] + eps ;

pTheta  (k,i,rp)$[rpk(rp,k) and not pTransNet] =                             eps ;
pTheta  (k,i,rp)$[rpk(rp,k) and     pTransNet] = vTheta.l(rp,k,i) * 180/pi + eps ;

pBusRes (k,i,rp,'Qs','[Mvar]') $[rpk(rp,k) and pBusB(i)] = - [sqr[pVoltage(k,i,rp)] * pBusB(i) * pSBase] * 1e3 + eps ;
pBusRes (k,i,rp,'Ps','[MW]'  ) $[rpk(rp,k) and pBusG(i)] = + [sqr[pVoltage(k,i,rp)] * pBusG(i) * pSBase] * 1e3 + eps ;

pResulCDSF('obj. fun. cycle aging costs [M$]',s)$[not pIsHydro(s)] =
 sum[(rpk(rp,k),a), pWeight_rp(rp)*pWeight_k(k)*pCDSF_Cost(s,a)*vCDSF_dis.l(rp,k,s,a)] + eps
;

pCDSF_delta (p,s) = 0 ;
pCDSF_delta (p,s)        $[pDisEffic(s)*pMaxProd(s)*[vGenInvest.l(s)+pExisUnits(s)]*pE2PRatio(s)]
     = pGenP(p,s) * 1E-3 /[pDisEffic(s)*pMaxProd(s)*[vGenInvest.l(s)+pExisUnits(s)]*pE2PRatio(s)]
     + pCDSF_delta (p-1,s)$[ord(p)>1]
;
pResulCDSF('Annual life loss from cycling [%]',s)$[not pIsHydro(s)] =
  sum[p, pCDSF_alpha(s)*rPower[pCDSF_delta (p,s),pCDSF_beta(s)]] + eps;
;

pResulCDSF('Annual prorated cycle aging cost [M$]',s)$[not pIsHydro(s)] =
  pReplaceCost(s) *[pMaxProd(s)*[vGenInvest.l(s)+pExisUnits(s)] * pE2PRatio(s)] *
  pResulCDSF('Annual life loss from cycling [%]',s)
;

pResulCDSF('Battery life expectancy [year]',s)$[not pIsHydro(s) and pShelfLife(s)] =
* assuming proportional annual self life loss
  1 /[1/pShelfLife(s) + pResulCDSF('Annual life loss from cycling [%]',s)]
;

$offFold

$onFold // Economic Results Calculation ----------------------------------------

* electricity prices [$/MWh]
pSRMC(p,i)$[not pTransNet                    ] = sum[hindex(p,rpk(rp,k)), eSN_BalanceP.m  (rp,k,i) * 1e3 / [pWeight_rp(rp)*pWeight_k(k)]] + eps ;
pSRMC(p,i)$[    pTransNet and not pEnableSOCP] = sum[hindex(p,rpk(rp,k)), eDC_BalanceP.m  (rp,k,i) * 1e3 / [pWeight_rp(rp)*pWeight_k(k)]] + eps ;
pSRMC(p,i)$[    pTransNet and     pEnableSOCP] = sum[hindex(p,rpk(rp,k)), eSOCP_BalanceP.m(rp,k,i) * 1e3 / [pWeight_rp(rp)*pWeight_k(k)]] + eps ;

* electricity prices in rp and k [M$/GW]
pMC(rp,k,i)$[not pTransNet                    ] = eSN_BalanceP.m  (rp,k,i) + eps ;
pMC(rp,k,i)$[    pTransNet and not pEnableSOCP] = eDC_BalanceP.m  (rp,k,i) + eps ;
pMC(rp,k,i)$[    pTransNet and     pEnableSOCP] = eSOCP_BalanceP.m(rp,k,i) + eps ;

* dual variables of inertia constraints
pInertDual(k,rp) $[rpk(rp,k) and     pEnableRoCoF] = eRoCoF_SyEq1.m(rp,k) * 1e6 + eps ;
pInertDual(k,rp) $[rpk(rp,k) and not pEnableRoCoF] = eMinInertia.m (rp,k) * 1e6 + eps ;

* new calculations for economic results (revenues, costs, profits, etc)
pRevSpot (g)$[not pTransNet                    ]  = + sum[(rpk(rp,k)), vGenP.l   (rp,k,g) * sum[i$gi(g,i), eSN_BalanceP.m(rp,k,i)]];
pRevSpot (g)$[    pTransNet and not pEnableSOCP]  = + sum[(rpk(rp,k)), vGenP.l   (rp,k,g) * sum[i$gi(g,i), eDC_BalanceP.m(rp,k,i)]];
pRevSpot (g)$[    pTransNet and     pEnableSOCP]  = + sum[(rpk(rp,k)), vGenP.l   (rp,k,g) * sum[i$gi(g,i), eSOCP_BalanceP.m(rp,k,i)]];

* only storage units can buy energy on spot market
pCostSpot (s)$[not pTransNet                    ] = + sum[(rpk(rp,k)), vConsump.l(rp,k,s) * sum[i$gi(s,i), eSN_BalanceP.m(rp,k,i)]];
pCostSpot (s)$[    pTransNet and not pEnableSOCP] = + sum[(rpk(rp,k)), vConsump.l(rp,k,s) * sum[i$gi(s,i), eDC_BalanceP.m(rp,k,i)]];
pCostSpot (s)$[    pTransNet and     pEnableSOCP] = + sum[(rpk(rp,k)), vConsump.l(rp,k,s) * sum[i$gi(s,i), eSOCP_BalanceP.m(rp,k,i)]];


pRevReserve (g)   = + sum[(rpk(rp,k)), v2ndResUP.l(rp,k,g) * e2ReserveUp.m(rp,k)]
                    + sum[(rpk(rp,k)), v2ndResDW.l(rp,k,g) * e2ReserveDw.m(rp,k)];

pReserveCost(s)   = + sum[(rpk(rp,k)), pWeight_rp(rp)*pWeight_k(k)*pOMVarCost   (s)  *
                                                    p2ndResUpCost     * v2ndResUP.l(rp,k,s)]
                    + sum[(rpk(rp,k)), pWeight_rp(rp)*pWeight_k(k)*pOMVarCost   (s)  *
                                                    p2ndResDwCost     * v2ndResDW.l(rp,k,s)] ;
pReserveCost(t)   = + sum[(rpk(rp,k)), pWeight_rp(rp)*pWeight_k(k)*pSlopeVarCost(t) *
                                                    p2ndResUpCost  * v2ndResUP.l(rp,k,t)]
                    + sum[(rpk(rp,k)), pWeight_rp(rp)*pWeight_k(k)*pSlopeVarCost(t)  *
                                                    p2ndResDwCost     * v2ndResDW.l(rp,k,t)] ;

pRevRESQuota(t)   =    eCleanProd.m  * sum[(rpk(rp,k)), pWeight_rp(rp)*pWeight_k(k) * vGenP.l    (rp,k,t)] ;
pFirmCapPay (g)   =    eFirmCapCon.m * pFirmCapCoef(g)*pMaxProd(g)*[vGenInvest.l(g)+pExisUnits(g)];

pInvCost(g)$ga(g) = pInvestCost(g)* vGenInvest.l(g);
pOMCost       (s) = + sum[(rpk(rp,k)),             pWeight_rp(rp)*pWeight_k(k)*pOMVarCost(s  )*vGenP.l    (rp,k,s  )]
                    + sum[(rpk(rp,k),a)$[cdsf(s)], pWeight_rp(rp)*pWeight_k(k)*pCDSF_Cost(s,a)*vCDSF_dis.l(rp,k,s,a)] ;
pOMCost       (r) = + sum[(rpk(rp,k)), pWeight_rp(rp)*pWeight_k(k)*pOMVarCost   (r) * vGenP.l    (rp,k,r)] ;
pOMCost       (t) = + sum[(rpk(rp,k)), pWeight_rp(rp)*pWeight_k(k)*pSlopeVarCost(t) * vGenP.l    (rp,k,t)]
                    + sum[(rpk(rp,k)), pWeight_rp(rp)*pWeight_k(k)*pStartupCost (t) * vStartup.l (rp,k,t)]
                    + sum[(rpk(rp,k)), pWeight_rp(rp)*pWeight_k(k)*pInterVarCost(t) * vCommit.l  (rp,k,t)] ;

pTotalProfits (g) =   pRevSpot    (g)
                    - pCostSpot   (g)
                    + pRevReserve (g)
                    - pReserveCost(g)
                    + pFirmCapPay (g)
                    + pRevRESQuota(g)
                    - pInvCost    (g)
                    - pOMCost     (g)
;

pEconomicResults('Spot market revenues    [M$]',g) =    pRevSpot     (g) + eps;
pEconomicResults('Spot market costs       [M$]',g) =  - pCostSpot    (g) + eps;
pEconomicResults('Reserve market revenues [M$]',g) =    pRevReserve  (g) + eps;
pEconomicResults('Reserve market costs    [M$]',g) =  - pReserveCost (g) + eps;
pEconomicResults('O&M costs               [M$]',g) =  - pOMCost      (g) + eps;
pEconomicResults('Investment costs        [M$]',g) =  - pInvCost     (g) + eps;
pEconomicResults('RES quota payments/cost [M$]',g) =    pRevRESQuota (g) + eps;
pEconomicResults('Firm capacity payments  [M$]',g) =    pFirmCapPay  (g) + eps;
pEconomicResults('Total profits           [M$]',g) =    pTotalProfits(g) + eps;

$offFold

$onFold // RoCoF results -------------------------------------------------------

pRoCoF_k   (rp,k,t)$[pEnableRoCoF] = [vCommit.L(rp,k,t )*pMaxProd(t)/sum[tt,vCommit.L(rp,k,tt )* pMaxProd(tt)]
                                                                  ]$[sum[tt,vCommit.L(rp,k,tt )* pMaxProd(tt)]>0];

pRoCoF_k   (rp,k,v)$[pEnableRoCoF] = [vGenP.L(rp,k,v) / sum[gi(vv,i), pMaxProd(vv)*pResProfile(rp,k,i,vv)*[vGenInvest.L(vv)+pExisUnits(vv)] ]
                                                     ]$[sum[gi(vv,i), pMaxProd(vv)*pResProfile(rp,k,i,vv)*[vGenInvest.L(vv)+pExisUnits(vv)] ]>0];

pRoCoF_SG_M(rp,k  )$[pEnableRoCoF] = sum[t,2*pInertiaConst(t)*                 pRoCoF_k(rp,k,t)] ;
pRoCoF_VI_M(rp,k  )$[pEnableRoCoF] = sum[v,2*pInertiaConst(v)* vGenInvest.L(v)*pRoCoF_k(rp,k,v)] ;

pActualSysInertia(k,rp) $[pEnableRoCoF] =[[
   +pRoCoF_SG_M(rp,k) * sum[t      ,pMaxProd(t)*vCommit.L       (rp,k,t)                                    ]
   +pRoCoF_VI_M(rp,k) * sum[gi(v,i),pMaxProd(v)*vGenInvest.L    (     v)*pResProfile(rp,k,i,v)              ]
   +pRoCoF_VI_M(rp,k) * sum[gi(v,i),pMaxProd(v)*                         pResProfile(rp,k,i,v)*pExisUnits(v)]
                          ]
                         /
                          [
   +sum[t      ,pMaxProd(t)*vCommit.L    (rp,k,t)                                    ]
   +sum[gi(v,i),pMaxProd(v)*vGenInvest.L (     v)*pResProfile(rp,k,i,v)              ]
   +sum[gi(v,i),pMaxProd(v)*                      pResProfile(rp,k,i,v)*pExisUnits(v)]
                          ]]$[[
   +sum[t      ,pMaxProd(t)*vCommit.L    (rp,k,t)                                    ]
   +sum[gi(v,i),pMaxProd(v)*vGenInvest.L (     v)*pResProfile(rp,k,i,v)              ]
   +sum[gi(v,i),pMaxProd(v)*                      pResProfile(rp,k,i,v)*pExisUnits(v)]
                          ]>0]
;

$offFold

$onFold // DSM results ---------------------------------------------------------

pResultDSM(rp,k,'Up  ',sec,i) = vDSM_Up.l  (rp,k,i,sec) + eps;
pResultDSM(rp,k,'Down',sec,i) = vDSM_Dn.l  (rp,k,i,sec) + eps;
pResultDSM(rp,k,'Shed',seg,i) = vDSM_Shed.l(rp,k,i,seg) + eps;

$offFold

$onFold // H2 results ----------------------------------------------------------

pH2price (h2sec,k,h2i,rp) $[rpk(rp,k) and pEnableH2] = eH2_Balance.m(rp,k,h2i,h2sec) * 1e3 / [pWeight_rp(rp)*pWeight_k(k)] + eps ;
pH2Prod  (h2g  ,k,    rp) $[rpk(rp,k) and pEnableH2] = vH2Prod.l    (rp,k,h2g      ) * 1e3                                 + eps ;
pH2Cons  (h2g  ,k,    rp) $[rpk(rp,k) and pEnableH2] = vH2Consump.l (rp,k,h2g      ) * 1e3                                 + eps ;
pH2ns    (h2sec,k,h2i,rp) $[rpk(rp,k) and pEnableH2] = vH2NS.l      (rp,k,h2i,h2sec) * 1e3                                 + eps ;
pH2Invest(h2g  ,'MW'    ) $[              pEnableH2] = vH2Invest.l  (h2g           ) * 1e3 *  pH2MaxCons(h2g)              + eps ;

pSummary('Levelized cost of H2                 [$/kg ]') $[pEnableH2 and sum[(rpk(rp,k),h2u      )  , pWeight_rp(rp)*pWeight_k(k)                           * vH2Prod.l   (rp,k,h2u)]] =
                                                                      [+ sum[           h2u         ,                             pH2InvestCost(h2u)        * vH2Invest.l (     h2u)]
                                                                       + sum[           h2u         ,                             pH2OMVarCost (h2u)        * vH2Invest.l (     h2u)]
                                                                       + sum[(rpk(rp,k),h2gi(h2g,i)),                             pMC          (    rp,k,i) * vH2Consump.l(rp,k,h2g)]] * 1e3
                                                                       / sum[(rpk(rp,k),h2u        ), pWeight_rp(rp)*pWeight_k(k)                           * vH2Prod.l   (rp,k,h2u)]
                                                                       + eps ;

display pSummary;

$offFold


*-------------------------------------------------------------------------------
*                          Export Results to Excel File
*-------------------------------------------------------------------------------
$onFold // Export results to Excel file ----------------------------------------

* data output to xls file
put TMP putclose 'par=pSummary          rdim=1 rng=Summary!a1' / 'par=pCommit    rdim=1 rng=UC!a1'          / 'par=pGenP      rdim=1 rng=GenP!a1'        / 'par=pTecProd   rdim=1 rng=TotalEn!a1'  /
                 'par=pStIntra          rdim=1 rng=StIntra!a1' / 'par=pStLevel   rdim=1 rng=StLevel!a1'     / 'par=pSRMC      rdim=1 rng=MC!a1'          / 'par=pGenInvest rdim=1 rng=GenInvest!a1'/
                 'par=pLineP            rdim=1 rng=LineP!a1'   / 'par=pLineQ     rdim=1 rng=LineQ!a1'       / 'par=pVoltage   rdim=1 rng=Volt!a1'        / 'par=pGenQ      rdim=1 rng=GenQ!a1'     /
                 'par=pTheta            rdim=1 rng=Angle!a1'   / 'par=pBusRes    rdim=1 rng=BusRes!a1'      / 'par=pResulCDSF rdim=1 rng=CDSF!a1'        / 'par=pInertDual rdim=1 rng=InertDual!a1'/
                 'par=pEconomicResults  rdim=1 rng=Profits!a1' / 'par=pTraInvest rdim=3 rng=TranInvest!a1'  / 'par=pResultDSM rdim=3 rng=DSM!a1'         / 'par=pChrP      rdim=1 rng=Charge!a1'   /
                 'par=pCurtP_k          rdim=2 rng=Curtail!a1' / 'par=pCurtP_rp  rdim=1 rng=Curtail!p1'     / 'par=pActualSysInertia rdim=1 rng=RoCoF!a1'/ 'par=pH2price   rdim=2 rng=H2price!a1'  / 'par=pH2Prod    rdim=2 rng=H2Prod!a1'   /
                 'par=pH2Cons           rdim=2 rng=H2Cons!a1'  / 'par=pH2ns      rdim=2 rng=H2ns!a1'        / 'par=pH2Invest  rdim=1 rng=H2Invest!a1'    /
execute_unload   'tmp_%gams.user1%.gdx' pSummary pCommit pGenP pTecProd pStIntra pStLevel pSRMC pGenInvest pLineP pLineQ pVoltage pGenQ pTheta pBusRes pResulCDSF pInertDual pEconomicResults pTraInvest pResultDSM pChrP pCurtP_k pCurtP_rp pActualSysInertia pH2price pH2Prod pH2Cons pH2ns pH2Invest

execute          'gdxxrw tmp_"%gams.user1%".gdx SQ=n EpsOut=0 O=tmp_"%gams.user1%".xlsx @tmp_"%gams.user1%".txt'
execute          'del    tmp_"%gams.user1%".gdx                                                                '
execute          'del                                                                    tmp_"%gams.user1%".txt'

* gdx with all information
execute_unload 'LEGO_%gams.user1%.gdx'

$offFold


*-------------------------------------------------------------------------------
*                           Saving UC Decisions
*-------------------------------------------------------------------------------
$onFold // Saving UC decisions -------------------------------------------------

if(%BatchUpdate%=1,
   execute_unload 'UC_%gams.user1%.gdx' pCommit pStLvMW;
elseif(card(p)>card(k)),
   execute_unload 'UC.gdx' pCommit pStLvMW;
);

$OnListing
$offFold
