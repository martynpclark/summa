pro test_enthalpy

; define constants
LH_fus   = 334000.     ; J kg-1
Tfreeze  =    273.16d  ; K
gravity  =      9.81d  ; m s-2

; define heat capacities
Cp_air   =    1005.d   ; specific heat of air                 (J kg-1 K-1)
Cp_ice   =    2114.d   ; specific heat of ice                 (J kg-1 K-1)
Cp_soil  =     850.d   ; specific heat of soil                (J kg-1 K-1)
Cp_water =    4181.d   ; specific heat of liquid water        (J kg-1 K-1)

; define intrinsic densities
iden_air   =     1.293d    ; intrinsic density of air             (kg m-3)
iden_ice   =   917.0d      ; intrinsic density of ice             (kg m-3)
iden_soil  =  2700.0d      ; intrinsic density of soil            (kg m-3)
iden_water =  1000.0d      ; intrinsic density of liquid water    (kg m-3)

; define parameters
alpha     = -0.45d
vGn_n     =  2.d
vGn_m     =  0.71d
theta_sat =  0.368
theta_res =  0.102
k_sat     =  0.0000922d  ; m/s

; define the volumetric fraction of air and soil
volFracSoil = 1.d - theta_sat

; define the number of variables in the integration
nIntegr8 = 100

; define the number of trial values
nTrial = 101

; define the matric head
psi = -0.45d

; define the temperature
xTemp = Tfreeze - 5.d*dindgen(nTrial)/double(nTrial-1)

; loop through trial values
;for iTrial=0,nTrial-1 do begin
for iTrial=5,5 do begin
 
 ; get the volumetric fraction of liquid water and ice
 updateLiqFrac, psi, xTemp[iTrial], alpha, theta_res, theta_sat, vGn_n, vGn_m, volFracLiq, volFracIce 
 volFracAir  = theta_sat - volFracLiq - volFracIce

 ; define the volumetric heat capacities
 Cv_air   = iden_air*volFracAir*Cp_air
 Cv_ice   = iden_ice*volFracIce*Cp_ice
 Cv_soil  = iden_soil*volFracSoil*Cp_soil
 Cv_water = iden_water*volFracLiq*Cp_water

 ; define the temperature component of enthalpy
 ; NOTE: need to integrate over ice and water
 Hv = 0.d
 dT = (Tfreeze - xTemp[iTrial])/double(nIntegr8)
 Tm = xTemp[iTrial] + dT/2.d
 for integr8=0,nIntegr8-1 do begin

  ; get volumetric fraction of liquid water
  xConst     = LH_fus/(gravity*Tfreeze)  ; m K-1 (NOTE: J = kg m2 s-2)
  psiLiq     = xConst*(Tm - Tfreeze)
  volFracLiq = call_function('volFracLiq', psiLiq, alpha, theta_res, theta_sat, vGn_n, vGn_m)

  ; compute enthalpy
  Hi = volFracLiq*iden_water*Cp_water*dT
  Hv = Hv + Hi
  print, 'T0, T1, Tm, volFracLiq, Hi, Hv = ', Tm - dT/2.d, Tm + dT/2.d, Tm, volFracLiq, Hi, Hv, format='(a,1x,10(f12.3,1x))'

  ; update Tm
  Tm = Tm + dT

 endfor  ; integrating
 stop
 

 print, xTemp[iTrial], volFracLiq, volFracIce, format='(10(f9.3,1x))'

endfor  ; looping through trial values




stop
end

; **********************************************************************************************
; **********************************************************************************************

; compute volumetric fraction of liquid water and ice based on matric head and temperature
pro updateLiqFrac, psi, xTemp, alpha, theta_res, theta_sat, vGn_n, vGn_m, volFracLiq, volFracIce

; input (states)
; psi     = matric head (m)
; xTemp   = temperature (K)

; input (parameters)
; alpha     = van Genuchten scaling parameter (m-1)
; theta_res = residual volumetric water content (-)
; theta_sat = porosity (-)
; vGn_n     = van Genuchten "n" parameter
; vGn_m     = van Genuchten "m" parameter

; output (diagnostic variables)
; volFracLiq = volumetric fraction of liquid water (-)
; volFracIce = volumetric fraction of ice (-)

; define constants
LH_fus  = 334000.     ; J kg-1
Tfreeze =    273.16d  ; K
gravity =      9.81d  ; m s-2

; compute fractional **volume** of total water (liquid plus ice)
vTheta = call_function('volFracLiq', psi, alpha, theta_res, theta_sat, vGn_n, vGn_m)

; compute the critical soil temperature where all water is unfrozen (K)
; (NOTE: J = kg m2 s-2, so LH_fus is in units of m2 s-2)
; (eq 17 in Dall'Amico 2011)
TcSoil = Tfreeze + min([psi,0.d])*gravity*Tfreeze/LH_fus  

; compute volumetric fraction of liquid water and ice for partially frozen soil
if(xTemp lt TcSoil)then begin

 ; - volumetric liquid water content (-)
 xConst     = LH_fus/(gravity*Tfreeze)                            ; m K-1 (NOTE: J = kg m2 s-2)
 psiLiq     = xConst*(xTemp - Tfreeze)
 volFracLiq = call_function('volFracLiq', psiLiq, alpha, theta_res, theta_sat, vGn_n, vGn_m)

 ; - volumetric ice content (-)
 volFracIce = vTheta - volFracLiq

; compute volumetric fraction of liquid water and ice for unfrozen soil
endif else begin
 
 ; - all water is unfrozen
 psiLiq     = psi
 volFracLiq = vTheta
 volFracIce = 0.d

endelse

end

; compute the volumetric liquid water content given psi and soil hydraulic parameters theta_res, theta_sat, alpha, n, and m
function volFracLiq, psi, alpha, theta_res, theta_sat, vGn_n, vGn_m
 if(psi lt 0.d)then begin
  return, theta_res + (theta_sat - theta_res)*(1.d + (alpha*psi)^vGn_n)^(-vGn_m)
 endif else begin
  return, theta_sat
 endelse
end
