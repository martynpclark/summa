pro make_monthly_forcing

; define the number of stations
nSta = 58

; define variable names
varname = ['ppta','tmp3','dpt3']
vardesc = ['monthly precipitation total','monthly air temperature','monthly dewpoint temperature']
varunit = ['mm/month','degrees C','degrees C']

; define the number of years and months
nyears = 49
nmonths = nyears*12

; *****
; (1) DEFINE THE FILE...
; **********************

; define the monthly data
xMonth = dblarr(nsta,nmonths)

; define file
file_path = '/home/mclark/summa/input/tollgate/stationData/'
file_name = file_path + 'tollgate_forcing_monthly.nc'

; open netcdf file for reading
nc_file = ncdf_open(file_name, /write)

 ; get time units
 ivar_id = ncdf_varid(nc_file,'time')
 ncdf_attget, nc_file, ivar_id, 'units', bunits
 cunits = string(bunits)

 ; get the base julian day
 tunit_words  = strsplit(string(cunits),' ',/extract)
 tunit_idate  = fix(strsplit(tunit_words[2],'-',/extract))
 tunit_ihour  = fix(strsplit(tunit_words[3],':',/extract))
 bjulian      = julday(tunit_idate[1],tunit_idate[2],tunit_idate[0],tunit_ihour[0],tunit_ihour[1],tunit_ihour[2])

 ; read the time vector (convert to units of days)
 if(strtrim(tunit_words[0],2) eq 'seconds') then aoff=1.d/86400.d else stop, 'unknown time units'  ; get offset in days
 ncdf_varget, nc_file, ivar_id, atime
 djulian = bjulian + atime*aoff
 ntime = n_elements(dJulian)

 ; get the year, month, day
 caldat, djulian, im, id, iyyy

 ; get the dimension id for station
 stn_id  = ncdf_dimid(nc_file, 'station')

 ; get into control mode (in order to make a new variable)
 ncdf_control, nc_file, /redef

  ; define new dimension for the months
  if(ncdf_dimid(nc_file,'month') eq -1)then begin
   month_id = ncdf_dimdef(nc_file, 'month', nmonths)
  endif else begin
   month_id = ncdf_dimid(nc_file,'month')
  endelse

  ; define the time variable
  if(ncdf_varid(nc_file, 'month') eq -1) then begin
   ivarid = ncdf_vardef(nc_file, 'month', month_id, /double)
   ncdf_attput, nc_file, ivarid, 'units', cunits, /char
  endif

  ; loop through variables
  for ivar=0,n_elements(varname)-1 do begin

   ; make a new variable for the monthly precip data
   if(ncdf_varid(nc_file, varname[ivar]+'_monthly') eq -1)then begin
    ivarid = ncdf_vardef(nc_file, varname[ivar]+'_monthly', [stn_id, month_id], /float)
    ncdf_attput, nc_file, ivarid, 'long_name', vardesc[ivar], /char
    ncdf_attput, nc_file, ivarid, 'units', varunit[ivar], /char
    ncdf_attput, nc_file, ivarid, '_FillValue', -9999., /float
   endif

   ; make a new variable to identify serially complete data
   if(ncdf_varid(nc_file, varname[ivar]+'_monthly_flag') eq -1)then begin
    ivarid = ncdf_vardef(nc_file, varname[ivar]+'_monthly_flag', [stn_id, month_id], /short)
    ncdf_attput, nc_file, ivarid, 'long_name', 'flag=1 denotes estimated data point', /char
    ncdf_attput, nc_file, ivarid, '_FillValue', 0, /short
   endif

   ; make a new variable to store the number of filled data points
   if(ncdf_varid(nc_file, varname[ivar]+'__number_filled_months') eq -1)then begin
    ivarid = ncdf_vardef(nc_file, varname[ivar]+'__number_filled_months', stn_id, /short)
    ncdf_attput, nc_file, ivarid, 'long_name', 'number of months when data estimated based on regression from another station', /char
    ncdf_attput, nc_file, ivarid, '_FillValue', 0, /short
   endif

   ; make a new variable to store the mean correlation of filled data
   if(ncdf_varid(nc_file, varname[ivar]+'__correlation_filled_data') eq -1)then begin
    ivarid = ncdf_vardef(nc_file, varname[ivar]+'__correlation_filled_data', stn_id, /float)
    ncdf_attput, nc_file, ivarid, 'long_name', 'mean correlation with station used for filling', /char
    ncdf_attput, nc_file, ivarid, '_FillValue', -9999., /float
   endif

  endfor  ; looping through variables

 ; exit control mode
 ncdf_control, nc_file, /endef

 ; *****
 ; (2) COMPUTE MONTHLY DATA...
 ; ***************************

 ; define if we have the data already
 got_data=1

 ; define arrays for metadata
 ckey  = strarr(nsta)
 cname = strarr(nsta)

 ; read in metadata
 for iSta=0,nSta-1 do begin

  ; read in the station name
  ivar_id = ncdf_varid(nc_file,'station_name')
  ncdf_varget, nc_file, ivar_id, bname, offset=[0,iSta], count=[90,1]
  cName[ista] = string(reform(bName))

  ; read in the station key
  ivar_id = ncdf_varid(nc_file,'station_key')
  ncdf_varget, nc_file, ivar_id, bkey, offset=[0,iSta], count=[90,1]
  cKey[ista] = string(reform(bkey))

 endfor

 ; skip if we have the data already
 if(got_data eq 1)then goto, got_data_already

 ; loop through variables
 for ivar=0,n_elements(varname)-1 do begin

  ; loop through stations
  for iSta=0,nSta-1 do begin

   ; print progress
   print, varname[ivar], ista+1, nsta, ' : ', strtrim(cName[ista],2)

   ; read in the data
   ivar_id = ncdf_varid(nc_file,varname[ivar])
   ncdf_varget, nc_file, ivar_id, xData, offset=[iSta,0], count=[1,ntime]
   xData = reform(xData)

   ; define month counter
   jmonth = 0

   ; loop through months
   for iyear=1962,2010 do begin
    for imonth=1,12 do begin

     ; write time at the middle of the month -- convert to seconds since bjulian
     if(ivar eq n_elements(varname)-1)then begin
      ivarid = ncdf_varid(nc_file, 'month')
      ncdf_varput, nc_file, ivarid, (julday(imonth,15,iyear) - bjulian) * 86400.d, offset=jMonth, count=1
     endif

     ; initialize monthly precip
     xMonth[ista,jmonth] = -9999.d

     ; identify data subset
     iSubset = where(imonth eq im and iyear eq iyyy, nSubset)
     if(nSubset gt 0)then begin

      ; identify valid data
      iValid = where(xData[iSubset] gt -998.d, nValid)
      fValid = float(nValid)/float(nSubset)

      ; get monthly data
      if(fValid gt 0.99d)then begin
       if(varname[ivar] eq 'ppta')then begin
        xMonth[ista,jmonth] = total(xData[iSubset[iValid]])
       endif else begin
        xMonth[ista,jmonth] = mean(xData[iSubset[iValid]])
       endelse
      endif  ; if the month is effectively complete

     ; no data within range
     endif else begin
      nValid = 0
      fValid = 0.
     endelse

     ; write data
     ivarid = ncdf_varid(nc_file, varname[ivar]+'_monthly')
     ncdf_varput, nc_file, ivarid, xMonth[ista,jmonth], offset=[ista,jmonth], count=[1,1]

     ; print progress
     ;print, iyear, imonth, nValid, nSubset, fValid, xMonth[ista,jmonth], format='(i4,1x,i2,1x,2(i6,1x),2(f11.5,1x))'

     ; increment month index
     jMonth = jMonth+1

    endfor  ; looping through months
   endfor  ; looping through years

  endfor  ; looping through stations

  ; save data
  save, xMonth, filename=varname[ivar]+'_monthly.sav'

 endfor  ; looping through variables

 ; jump point if we already have the data
 got_data_already:

 ; *****
 ; (3) COMPUTE SERIALLY-COMPLETE DATA...
 ; *************************************

 ; loop through variables
 for ivar=0,n_elements(varname)-1 do begin

  ; restore data
  restore, varname[ivar]+'_monthly.sav'

  ; compute serially-complete data
  for ista=0,nsta-1 do begin

   ; only look at a single station
   ;if(strtrim(cKey[ista],2) ne 'rc.usc-138031')then continue

   ; define vector of correlations
   xCorr = dblarr(nsta)
   xCorr[*] = -9999.d

   ; define vector of filled data
   xFill = dblarr(nsta,nmonths)
   xFill[*,*] = -9999.d

   ; loop through candidate stations
   for jsta=0,nsta-1 do begin

    ; can't use the same station
    if(ista eq jsta)then continue
 
    ; identify matching data
    iMatch = where(xMonth[ista,*] ge -50.d and xMonth[jsta,*] ge -50.d, nMatch)
    if(nMatch gt 50)then begin

     ; compute regression relationship
     xBeta = regress(xMonth[jSta,iMatch], reform(xMonth[iSta,iMatch]), const=xConst, correlation=r)

     ; identify valid data at the target station
     jMatch = where(xMonth[jsta,*] ge -50.d, nMatch)

     ; save the data
     xCorr[jsta] = r
     xFill[jSta,jMatch] = xConst + xBeta[0]*xMonth[jsta,jMatch]
     ;print, ista, jsta, r

     ; give an artifically low correlation to the quonset (means we only use it if we have to)
     ;if(cKey[jsta] eq 'rc-076')then xCorr[jsta] = 0.d

    endif  ; if there is enough data to make the regression

   endfor  ; candidate stations

   ; test
   ;if(ista eq 5)then stop, 'test correlation'

   ; get mean correlation
   zCorr = fltarr(nmonths)
   iFill = intarr(nMonths)

   ; initialize variables
   iFill[*] = 0
   zCorr[*] = -9999.d

   ; loop through time series
   for iData=0,nmonths-1 do begin

    ; check if there is missing data
    if(xMonth[ista,iData] lt -50.)then begin

     ; identify the stations with valid data for that month
     iValid = where(xFill[*,iData] ge -50.d, nValid)
     if(nValid gt 0)then begin

      ; identify the valid station with the highest correlation
      xMax = max(xCorr[iValid], iMax)
      jMax = iValid[iMax]
      ;print, iData, xmax, xCorr[jMax]

      ; save maximum correlation
      zCorr[iData] = xMax

      ; fill the data
      xMonth[ista,iData] = xFill[jMax,iData]

      ; set the flag
      iFill[iData] = 1

      ; write the filled data
      ivarid = ncdf_varid(nc_file, varname[ivar]+'_monthly')
      ncdf_varput, nc_file, ivarid, xMonth[ista,iData], offset=[ista,iData], count=[1,1]
    
     endif else begin   ; no stations with valid data
      iFill[iData] = -1
     endelse

    endif   ; data is valid

    ; write the flag
    ivarid = ncdf_varid(nc_file, varname[ivar]+'_monthly_flag')
    ncdf_varput, nc_file, ivarid, iFill[iData], offset=[ista,iData], count=[1,1]

   endfor ; loop through the time series

   ; save statistics
   mFill = where(iFill eq  0, nGoodData)
   nFill = where(iFill eq -1, nMissing)
   jFill = where(iFill eq  1, nFill)
   if(nFill gt 0)then begin
    yCorr = mean(zCorr[jFill])
   endif else begin
    if(nMissing eq nMonths)then yCorr = -9999.d
    if(nGoodData eq nmonths)then yCorr = 1.d
   endelse

   ; write the number of filled months
   ivarid = ncdf_varid(nc_file, varname[ivar]+'__number_filled_months')
   ncdf_varput, nc_file, ivarid, nFill, offset=ista, count=1  

   ; write the mean correlation
   ivarid = ncdf_varid(nc_file, varname[ivar]+'__correlation_filled_data')
   ncdf_varput, nc_file, ivarid, yCorr, offset=ista, count=1                      

   ; print progress
   print, varname[ivar], ista, strtrim(cKey[ista],2), strtrim(cName[ista],2), nFill, nMissing, nGoodData, yCorr, $
    format='(a4,1x,i4,1x,a15,1x,a90,1x,3(i4,1x),f9.3)'

  endfor  ; looping through stations
  ;stop, 'looping through variables'

 endfor  ; looping through variables

; close the NetCDF file
ncdf_close, nc_file

stop
end
