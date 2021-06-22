C     NICHEMAPR: SOFTWARE FOR BIOPHYSICAL MECHANISTIC NICHE MODELLING

C     COPYRIGHT (C) 2020 MICHAEL R. KEARNEY AND WARREN P. PORTER

C     THIS PROGRAM IS FREE SOFTWARE: YOU CAN REDISTRIBUTE IT AND/OR MODIFY
C     IT UNDER THE TERMS OF THE GNU GENERAL PUBLIC LICENSE AS PUBLISHED BY
C     THE FREE SOFTWARE FOUNDATION, EITHER VERSION 3 OF THE LICENSE, OR (AT
C      YOUR OPTION) ANY LATER VERSION.

C     THIS PROGRAM IS DISTRIBUTED IN THE HOPE THAT IT WILL BE USEFUL, BUT
C     WITHOUT ANY WARRANTY; WITHOUT EVEN THE IMPLIED WARRANTY OF
C     MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. SEE THE GNU
C     GENERAL PUBLIC LICENSE FOR MORE DETAILS.

C     YOU SHOULD HAVE RECEIVED A COPY OF THE GNU GENERAL PUBLIC LICENSE
C     ALONG WITH THIS PROGRAM. IF NOT, SEE HTTP://WWW.GNU.ORG/LICENSES/.

C     THIS SUBROUTINE IS A MOLAR BALANCE FOR COMPUTING WATER LOSS FROM
C     BREATHING. IT USES THE OXYGEN DEMAND FOR MAINTAINING A CORE
C     TEMPERATURE TO COMPUTE THE AMOUNT OF AIR IN AND OUT OF THE LUNGS.
C     THE RELATIVE HUMIDITY OF THE AMBIENT AIR IS ASSUMED TO BE EXHALED
C     AT ANY SPECIFIED VALUE (DEFAULT IS 100%).

      SUBROUTINE RESPFUN(TAIREF,X,O2GAS,N2GAS,CO2GAS,BARPRS,QMIN,RQ,
     &TLUNG,GMASS,EXTREF,RELHUM,RELXIT,TIMACT,TAEXIT,PANT,QSUM,RP_CO2,
     &RESULTS)

      IMPLICIT NONE
      
      DOUBLE PRECISION AIRATO,AIRML1,AIRML2,AIRVOL,BARPRS,CO2GAS,CO2MOL
      DOUBLE PRECISION CP,DENAIR,DP,E,ESAT,EVPMOL,EXTREF,GEN,GEVAP,GMASS
      DOUBLE PRECISION GPERHR,HTOVPR,KGEVAP,MSLOPE,N2GAS,N2MOL1,N2MOL2
      DOUBLE PRECISION NTRCPT,O2GAS,O2MOL1,O2MOL2,O2MOLC,O2STP,PANT
      DOUBLE PRECISION P_CO2,P_N2,P_O2,PO2,QAIR,QMIN,QNETCHK,QRESP
      DOUBLE PRECISION QSUM,REFPO2,RELHUM,RELXIT,RESPFN,RESPGEN,RESULTS
      DOUBLE PRECISION RGC,RHSAT,RP_CO2,RP_N2,RP_O2,RQ,RW,SOLTYP
      DOUBLE PRECISION STDPRS,TAEXIT,TAIR,TAIREF,TC,TESVAL,TIMACT,TLUNG
      DOUBLE PRECISION TVINC,TVIR,VD,VO2CON,WB,WMOL1,WMOL2,WTRPOT,X

      DIMENSION RESULTS(15)
      
      TAIR = TAIREF
      GEN=X
      TC = 0. ! NO INSECTS FOR NOW
      SOLTYP = 1. ! NO INSECTS FOR NOW
      MSLOPE = 0. ! NO INSECTS FOR NOW
      NTRCPT = 0. ! NO INSECTS FOR NOW
      
C     DEFINING VARIABLES
C     BARPRS = BAROMETRIC PRESSURE (PA)
C     EXTREF = EXTRACTION EFFICIENCY (PER CENT)
C     GEVAP = GRAMS OF WATER EVAPORATED FROM RESPIRATORY TRACT/S
C     QRESP = HEAT LOSS DUE TO RESPIRATORY EVAPORATION (W)
C     RGC = UNIVERSAL GAS CONSTANT (PA-M3/MOL-K) = (J/MOL-K)
C     RELHUM = RELATIVE HUMIDITY (PER CENT)
C     RQ = RESPIRATORY QUOTIENT (MOL CO2 / MOL O2)
C     TC = ANIMAL CORE TEMPERATURE(C)
C     TLUNG = AVERAGE LUNG TEMPERATURE (C)
C     TMAXPR = PREFERRED MAX. TCORE
C     TMINPR = PREFERRED MIN. TCORE
C     ACTLVL = ACTIVITY LEVEL ABOVE BASAL METABOLISM

C     ASSIGNING VALUES TO VARIABLES
C     AIR FRACTIONS FROM SCHMIDT-NIELSEN, 2ND ED. ANIMAL PHYSIOLOGY CITING
C     OTIS, 1964 **** REFERENCE VALUES ****
      RP_O2 = 0.2095
      RP_N2 = 0.7902
C      RPCTCO2 = 0.0003 ! NOW MAKE USER-DEFINED (NO LONGER THIS LOW!)
      P_O2 = RP_O2
      P_N2 = RP_N2
      P_CO2 = RP_CO2
C     ALLOWING USER TO MODIFY GAS VALUES FOR BURROW, ETC. CONDITIONS
      IF (P_O2 .NE. (O2GAS/100.))THEN
       P_O2 = O2GAS/100.
      ELSE
       P_O2 = RP_O2
      ENDIF
      IF (P_N2 .NE. (N2GAS/100.))THEN
       P_N2 = N2GAS/100.
      ELSE
       P_N2 = RP_N2
      ENDIF
      IF (P_CO2 .NE. (CO2GAS/100.))THEN
       P_CO2 = CO2GAS/100.
      ELSE
       P_CO2 = RP_CO2
      ENDIF

C     UNIVERSAL GAS CONSTANT (PA - LITERS)/(MOL - K)
      RGC = 8314.46
C     INITIALIZING FOR SUB. WETAIR
      WB = 0.0
      DP = 999.

      STDPRS = 101325.
      PO2 = BARPRS*P_O2
      REFPO2 = 101325.*RP_O2

C     OXYGEN CONSUMPTION FROM GEN IN FUNCTION SIMULSOL THE TOTAL HEAT PRODUCTION
C     NEEDED TO MAINTAIN CORE TEMPERATURE, GIVEN THE CURRENT ENVIRONMENT &
C     THE ANIMAL'S PROPERTIES.
      RESPGEN = MAX(GEN,QMIN)
C     OXYGEN CONSUMPTION BASED ON HEAT GENERATION ESTIMATE TO MAINTAIN
C     BODY TEMPERATURE, CORRECTED FOR SUBSTRATE UTILIZED.
C     LITERS OF O2/S @ STP: (DATA FOR EQUIVALENCIES FROM KLEIBER, 1961)
      IF (RQ .EQ. 1.0) THEN
C      CARBOHYDRATE: (ASIDE) CARBOHYDRATES WORTH 4193 CAL/G
C      LITER(STP)/S = J/S*(CAL/J)*(KCAL/CAL)*(LITER O2/KCAL))
       O2STP = RESPGEN*TIMACT*(1./4.185)*(1./1000.)*(1.0/5.057)
      ENDIF
      IF (RQ .LE. 0.7) THEN
C      FAT;  FATS WORTH 9400 CAL/G
       O2STP = RESPGEN*TIMACT*(1./4.185)*(1./1000.)*(1.0/4.7)
      ELSE
C      PROTEIN (RQ=0.8); PROTEINS WORTH 4300 CAL/G ON AVERAGE
       O2STP = RESPGEN*TIMACT*(1./4.185)*(1./1000.)*(1.0/4.5)
      ENDIF

C     IF A RESTING INSECT, LN(ML O2/G_THORAX/HOUR) = SLOPE * TC + INTERCEPT
C      IF(INT(SOLTYP).EQ.0)THEN !INSECT
C      COMPUTING LITERS O2/S
C       O2STP = ((EXP(MSLOPE*TC + NTRCPT))*GMASS)/(3600.*1000.)
C      ENDIF

C     CONVERTING STP -> VOL. OF O2 AT ANIMAL TCORE, ATM. PRESS.
      VO2CON = ((O2STP*STDPRS)/273.15)*((TAIR+273.15)/BARPRS)

C     O2 MOLES CONSUMED/S
C     N = PV/RT (IDEAL GAS LAW: NUMBER OF MOLES FROM PRESS,VOL,TEMP)
C     R = (P*V)/(N*T)= (101325PA*22.414L)/(1 MOL*273.15K)
C     HERE WE HAVE TO USE THE PARTIAL PRESSURE OF O2 TO GET MOLES OF O2
      O2MOLC = BARPRS*VO2CON/(RGC*(TAIR+273.15))

C     MOLES/S O2, N2, & DRY AIR AT 1: (ENTRANCE) (AIR FLOW = F(O2 CONSUMPTION)
      O2MOL1 = O2MOLC/(EXTREF/100.)
      N2MOL1 = O2MOL1*(P_N2/P_O2)
C     DEMAND FOR AIR = F(%O2 IN THE AIR AND ELEVATION)
C     NOTE THAT AS LONG AS ALL 3 PERCENTAGES ADD TO 100%, NO CHANGE IN AIR FLOW,
C     UNLESS YOU CORRECT FOR CHANGE IN %O2 IN THE AIR AND ELEVATION CHANGES
C     RELATIVE TO SEA LEVEL.
      AIRATO = (P_N2+P_O2+P_CO2)/P_O2
      AIRML1 = O2MOL1*AIRATO*(RP_O2/P_O2)*(REFPO2/PO2)*PANT
C     AIR VOLUME @ STP (LITERS/S)
      AIRVOL = (AIRML1*RGC*273.15/101325.)

C     COMPUTING THE VAPOR PRESSURE AT SATURATION FOR THE SUBSEQUENT
C     CALCULATION OF ACTUAL MOLES OF WATER BASED ON ACTUAL RELATIVE
C     HUMIDITY.
      RHSAT = 100.
      CALL WETAIR(TAIR,WB,RHSAT,DP,BARPRS,E,ESAT,VD,RW,TVIR,TVINC,
     * DENAIR,CP,WTRPOT)
C     MOLES WATER/S IN AT 1 (ENTRANCE) BASED ON RELATIVE HUMIDITY.
C     NOTE THAT HUMIDITY IS SET TO 99% IN MAIN IF ANIMAL IS IN BURROW
C     FOR THE CURRENT HOUR.
      WMOL1 = AIRML1*(ESAT*(RELHUM/100.))/(BARPRS-ESAT*(RELHUM/100.))

C     MOLES/S OF DRY AIR AT 2: (EXIT)
      O2MOL2 = O2MOL1 - O2MOLC
      N2MOL2 = N2MOL1
      CO2MOL = RQ*O2MOLC

C     TOTAL MOLES OF AIR AT 2 (EXIT) WILL BE APPROXIMATELY THE SAME
C     AS AT 1, SINCE THE MOLES OF O2 REMOVED = APPROX. THE # MOLES OF CO2
C     ADDED.  AVOGADRO'S # SPECIFIES THE # MOLECULES/MOLE.
      AIRML2 = (O2MOL2+CO2MOL)*((P_N2+P_O2)/P_O2)*(RP_O2/P_O2)*
     &    (REFPO2/PO2)*PANT

C     CALCULATING SATURATION VAPOR PRESSURE, ESAT, AT EXIT TEMPERATURE.
      CALL WETAIR(TAEXIT,WB,RELXIT,DP,BARPRS,E,ESAT,VD,RW,TVIR,
     * TVINC,DENAIR,CP,WTRPOT)
      WMOL2 = AIRML2*(ESAT/(BARPRS-ESAT))
C     ENTHALPY = U2-U1, INTERNAL ENERGY ONLY, I.E. LAT. HEAT OF VAP.
C     ONLY INVOLVED, SINCE ASSUME P,V,T CONSTANT, SO NOT SIGNIFICANT
C     FLOW ENERGY, PV. (H = U + PV), I.E. ENTHALPY = INTERNAL ENERGY + FLOW ENERGY

C     MOLES/S LOST BY BREATHING:
      EVPMOL = WMOL2-WMOL1
C     GRAMS/S LOST BY BREATHING = MOLES LOST * GRAM MOLECULAR WEIGHT OF WATER:
      GEVAP = EVPMOL*18.

C     PUTTING A CAP ON WATER LOSS FOR SMALL ANIMALS IN VERY COLD CONDITIONS
C     BY ASSUMING THEY WILL SEEK MORE MODERATE CONDITIONS IF THEY EXCEED
C     THIS CAP. THIS WILL IMPROVE STABILITY FOR SOLUTION METHOD.
C     BASED ON DATA FROM W.R. WELCH. 1980. EVAPORATIVE WATER LOSS FROM
C     ENDOTHERMS IN THERMALLY AND HYGRICALLY COMPLEX ENVIRONMENTS: AN
C     EMPIRICAL APPROACH FOR INTERSPECIFIC COMPARISONS.
C     J. COMP. PHYSIOL. 139: 135-143.  MAXIMUM VALUE RECORDED FOR PRAIRIE
C     DOGS WAS 0.6 G/(KG-H) = 1.667 X 10**-4 G/(KG-S)
C     HIGHEST RECORDED RATE WAS A RESTING DEER MOUSE AT 8 G/KG-H =
C     2.22E-03*
C     (EDWARDS & HAINES.1978. J. COMP. PHYSIOL. 128: 177-184 IN WELCH, 1980)
C     FOR A 0.01 KG ANIMAL, THE MAX. RATE WOULD BE 1.67**10^-6 G/S
      TESVAL = 2.22E-03*TIMACT*GMASS/1000.*15
      IF (GEVAP .GT. TESVAL) THEN
       GEVAP = TESVAL
      ELSE
      ENDIF

C     KG/S LOST BY BREATHING
      GPERHR = GEVAP * 3600.
      KGEVAP = GEVAP/1000.
C     LATENT HEAT OF VAPORIZATION FROM SUB. DRYAIR (J/KG)
      HTOVPR = 2.5012E+06 - 2.3787E+03*TLUNG
C     HEAT EXCHANGE DUE TO TEMPERATURE AIR THAT ENTERS THE LUNG
      CALL WETAIR(TAIR,WB,RELHUM,DP,BARPRS,E,ESAT,VD,RW,TVIR,TVINC,
     * DENAIR,CP,WTRPOT)
      ! HEAT CAPCITY (J/KG/K) * MOLES AIR (MOL / S) * MOLAR MASS OF AIR (KG/MOL) * DELTA TEMPERATURE
      QAIR = CP*AIRML1*0.0289647*(TAIR-TLUNG)

C     HEAT LOSS BY BREATHING (J/S)=(J/KG)*(KG/S)
      QRESP = HTOVPR*KGEVAP-QAIR

C     ** NOTE THAT THERE IS NO RECOVERY OF HEAT OR MOISTURE ASSUMED IN
C     THE NOSE **
      QNETCHK = X-QRESP
      RESPFN = QNETCHK - QSUM

      RESULTS = (/RESPFN,QRESP,GEVAP,P_O2,P_N2,P_CO2,GEN,O2STP,
     & O2MOL1,N2MOL1,AIRML1,O2MOL2,N2MOL2,AIRML2,AIRVOL/)

      RETURN
      END