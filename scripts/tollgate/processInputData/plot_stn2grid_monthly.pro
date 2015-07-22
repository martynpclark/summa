pro plot_stn2grid_monthly

; define plotting parameters
window, 0, xs=1350, ys=500, retain=2
device, decomposed=0
LOADCT, 39
!P.BACKGROUND=255
!P.CHARSIZE=3
!P.COLOR=0
erase, color=255
!P.MULTI=[0,3,1]

; *****
; (0) GET THE DAYMET GRID...
; **************************

; define the file path
daymet_path = '/home/mclark/summa/input/tollgate/DayMet_Tile_11912/'

; define the filename (just an example file -- only need the coordinates)
daymet_name = daymet_path + 'dayl_1980.nc'

; open netcdf file for reading
file_id = ncdf_open(daymet_name, /nowrite)

 ; read the x coordinate
 ivarid = ncdf_varid(file_id,'x')
 ncdf_varget, file_id, ivarid, tile_x

 ; read the y coordinate
 ivarid = ncdf_varid(file_id,'y')
 ncdf_varget, file_id, ivarid, tile_y

 ; read the latitude
 ivarid = ncdf_varid(file_id,'lat')
 ncdf_varget, file_id, ivarid, tile_lat

 ; read the longitude
 ivarid = ncdf_varid(file_id,'lon')
 ncdf_varget, file_id, ivarid, tile_lon

; close the file
ncdf_close, file_id

; *****
; (1) GET THE DAYMET ELEVATION...
; *******************************

; define the header
cHead=''
nHead=6

; define the file
filenm = '/home/mclark/summa/ancillary_data/tollgate/daymet_avgelev_from_nhdplus_lcc.txt'

; open file for reading
openr, in_unit, filenm, /get_lun

 ; loop through header lines
 for iHead=0,nHead-1 do begin
  ; read header
  readf, in_unit, cHead
  cData = strsplit(cHead,' ',/extract)
  ; extract grid info
  case cData[0] of
   'ncols':        nCols     = long(cData[1])
   'nrows':        nRows     = long(cData[1])
   'xllcorner':    xll       = float(cData[1])
   'yllcorner':    yll       = float(cData[1])
   'cellsize':     cSize     = float(cData[1])
   'NODATA_value': ixMissing = long(cData[1])
   else: stop, 'unable to find header value'
  endcase
 endfor  ; end looping through header

 ; extract grid
 daymetElev = fltarr(nCols,nRows)
 readf, in_unit, daymetElev
 ;daymetElev = temporary(reverse(daymetElev,2))

; close file
free_lun, in_unit

; define x and y coordinates
daymet_x = xll + dindgen(nCols)*cSize + cSize/2.d
daymet_y = yll + dindgen(nRows)*cSize + cSize/2.d
daymet_yy = reverse(daymet_y)

; define x range
;xmin = xll
;xmax = xll + double(nCols)*cSize
xmin = daymet_x[110] - cSize/2.d
xmax = daymet_x[110+19] + cSize/2.d
print, 'xmin, xmax = ', xmin, xmax

; define y range
;ymin = yll
;ymax = yll + double(nRows)*cSize
ymin = daymet_yy[100] - cSize/2.d
ymax = daymet_yy[100+19] + cSize/2.d
print, 'ymin, ymax = ', ymin, ymax

; *****
; (2) IDENTIFY DESIRED GRID POINTS...
; ***********************************

; define the mask file
imask = intarr(nCols,nRows)
imask[*,*] = 0

; define the file path to the correspondence file
cros_path = '/home/mclark/summa/ancillary_data/tollgate/'

; define the filename (just an example file -- only need the coordinates)
cros_name = cros_path + 'Correspondence.nc'

; open netcdf file for reading
file_id = ncdf_open(cros_name, /nowrite)

 ; read the polygon ID
 ivarid = ncdf_varid(file_id,'polyid')
 ncdf_varget, file_id, ivarid, polyid

 ; read the number of overlaps
 ivarid = ncdf_varid(file_id,'overlaps')
 ncdf_varget, file_id, ivarid, nOverlap

 ; read the i-index
 ivarid = ncdf_varid(file_id,'i_index')
 ncdf_varget, file_id, ivarid, i_index

 ; read the j-index
 ivarid = ncdf_varid(file_id,'j_index')
 ncdf_varget, file_id, ivarid, j_index

; close the NetCDF file
ncdf_close, file_id

; get file dimensions
cros_dims = size(i_index, /dimensions)

; loop through file and identify the i and j index
for jx=0,cros_dims[1] -1 do begin
 for ix=0,nOverlap[jx]-1 do begin
  imask[i_index[ix,jx]-1,j_index[ix,jx]-1] = 1
 endfor
endfor

; *****
; (3) GET THE STATION METADATA... 
; *******************************

; define filename
file_stn = '/home/mclark/summa/input/tollgate/stationData/tollgate_forcing_monthly.nc'

; open the NetCDF file
nc_file = ncdf_open(file_stn, /nowrite)

 ; read in the station name
 ivar_id = ncdf_varid(nc_file,'station_name')
 ncdf_varget, nc_file, ivar_id, bname
 cName = string(reform(bName))

 ; read in the station key
 ivar_id = ncdf_varid(nc_file,'station_key')
 ncdf_varget, nc_file, ivar_id, bkey
 cKey = string(reform(bkey))

 ; read in the time vector
 ; NOTE: will copy time to the new file
 ivar_id = ncdf_varid(nc_file,'month')
 ncdf_varget, nc_file, ivar_id, stnTime
 ncdf_attget, nc_file, ivar_id, 'units', bunits
 cTimeUnits = string(bunits)

 ; read in the station x-coordinate
 ivar_id = ncdf_varid(nc_file,'LCC_x')
 ncdf_varget, nc_file, ivar_id, xCoord

 ; read in the station y-coordinate
 ivar_id = ncdf_varid(nc_file,'LCC_y')
 ncdf_varget, nc_file, ivar_id, yCoord

 ; read in the station elevation
 ivar_id = ncdf_varid(nc_file,'elevation')
 ncdf_varget, nc_file, ivar_id, zCoord

 ; read in the station sheltering index
 ivar_id = ncdf_varid(nc_file,'maximum_upwind_slope_parameter')
 ncdf_varget, nc_file, ivar_id, zShelt

; close the NetCDF file
ncdf_close, nc_file

; get the base julian day
tunit_words  = strsplit(string(cTimeUnits),' ',/extract)
tunit_idate  = fix(strsplit(tunit_words[2],'-',/extract))
tunit_ihour  = fix(strsplit(tunit_words[3],':',/extract))
bjulian      = julday(tunit_idate[1],tunit_idate[2],tunit_idate[0],tunit_ihour[0],tunit_ihour[1],tunit_ihour[2])

; convert the time to julian days
if(strtrim(tunit_words[0],2) eq 'seconds') then aoff=1.d/86400.d else stop, 'unknown time units'  ; get offset in days
djulian = bjulian + stnTime*aoff

; compute the year/month/day
caldat, djulian, stnMonth, stnDay, stnYear

; *****
; (4) DEFINE THE NEW NETCDF FILE...
; *********************************

; define number of values in the subset
nx_subset = 20
ny_subset = 20

; define the file path
grid_path = '/home/mclark/summa/input/tollgate/'

; define the filename (just an example file -- only need the coordinates)
grid_name = grid_path + 'stn2grid_tollgate_monthly.nc'

; define variable names
varnames = [$
           'pptrate',    $  ; precipitation rate (mm/month)
           'airtemp',    $  ; air temperature (degrees C)
           'dewtemp',    $  ; dewpoint temperature (degrees C)
           'swRadDown',  $  ; incoming shortwave radiation flux (W m-2)'
           'windspd'     ]  ; wind speed (m/s)

; define variable descriptions
var_desc = [$
           'precipitation rate', $
           'air temperature',    $
           'dewpoint temperature', $
           'incoming shortwave radiation flux', $
           'wind speed']

; define the units
var_unit = [$
            'mm month-1',$
            'degrees C', $
            'degrees C', $
            'W m-2',     $
            'm s-1']

; define file
file_id = ncdf_create(strtrim(grid_name,2), /clobber)

 ; define the x and y dimensions
 x_id = ncdf_dimdef(file_id, 'x', nx_subset)
 y_id = ncdf_dimdef(file_id, 'y', ny_subset)

 ; define time dimension
 time_id = ncdf_dimdef(file_id, 'month', /unlimited)

 ; define the x index
 ivarid = ncdf_vardef(file_id, 'ix', [x_id], /short)
 ncdf_attput, file_id, ivarid, 'long_name', 'x index in the original daymet tile (0,1,2...)'

 ; define the y index
 ivarid = ncdf_vardef(file_id, 'iy', [y_id], /short)
 ncdf_attput, file_id, ivarid, 'long_name', 'y index in the original daymet tile (0,1,2...)'

 ; define the x coordinate
 ivarid = ncdf_vardef(file_id, 'x', [x_id], /double)
 ncdf_attput, file_id, ivarid, 'long_name', 'x coordinate'

 ; define the y coordinate
 ivarid = ncdf_vardef(file_id, 'y', [y_id], /double)
 ncdf_attput, file_id, ivarid, 'long_name', 'y coordinate'

 ; define the time variable
 ; NOTE: copying time from the station file
 ivarid = ncdf_vardef(file_id, 'month', time_id, /double)
 ncdf_attput, file_id, ivarid, 'units', cTimeUnits, /char

 ; define the mask
 ivarid = ncdf_vardef(file_id, 'mask', [x_id,y_id], /short)
 ncdf_attput, file_id, ivarid, 'long_name', 'tollgate mask'

 ; define the latitude
 ivarid = ncdf_vardef(file_id, 'lat', [x_id,y_id], /float)
 ncdf_attput, file_id, ivarid, 'long_name', 'latitude'
 ncdf_attput, file_id, ivarid, 'units', 'degrees north'

 ; define the longitude
 ivarid = ncdf_vardef(file_id, 'lon', [x_id,y_id], /float)
 ncdf_attput, file_id, ivarid, 'long_name', 'longitude'
 ncdf_attput, file_id, ivarid, 'units', 'degrees east'

 ; define the elevation
 ivarid = ncdf_vardef(file_id, 'elev', [x_id,y_id], /float)
 ncdf_attput, file_id, ivarid, 'long_name', 'elevation'
 ncdf_attput, file_id, ivarid, 'units', 'm'

 ; define data variables
 for ivar=0,n_elements(varnames)-1 do begin
  ivarid = ncdf_vardef(file_id, varnames[ivar], [x_id, y_id, time_id], /float)
  ncdf_attput, file_id, ivarid, 'long_name', strtrim(var_desc[ivar],2), /char
  ncdf_attput, file_id, ivarid, 'units', strtrim(var_unit[ivar],2), /char
  ncdf_attput, file_id, ivarid, '_FillValue', -9999., /float
 endfor

 ; define number of valid stations
 for ivar=0,n_elements(varnames)-1 do begin
  ivarid = ncdf_vardef(file_id, varnames[ivar]+'_nValid', [time_id], /short)
  ncdf_attput, file_id, ivarid, 'long_name', 'number of valid stations', /char
 endfor

 ; end control
 ncdf_control, file_id, /endef

; close the netcdf file
ncdf_close, file_id

; *****
; (5) WRITE METADATA...
; *********************

; define the start index
i1 = 110
j1 = 100

; define the end index
i2 = i1 + nx_subset -1
j2 = j1 + ny_subset -1

; open netcdf file for writing
file_id = ncdf_open(grid_name, /write)

 ; write x index
 ivarid = ncdf_varid(file_id,'ix')
 ncdf_varput, file_id, ivarid, indgen(nx_subset)+i1

 ; write y index
 ivarid = ncdf_varid(file_id,'iy')
 ncdf_varput, file_id, ivarid, indgen(ny_subset)+j1

 ; write x coordinate
 ivarid = ncdf_varid(file_id,'x')
 ncdf_varput, file_id, ivarid, daymet_x[i1:i2]

 ; write y coordinate
 ivarid = ncdf_varid(file_id,'y')
 ncdf_varput, file_id, ivarid, daymet_yy[j1:j2]

 ; write lat
 ivarid = ncdf_varid(file_id,'lat')
 ncdf_varput, file_id, ivarid, tile_lat[i1:i2,j1:j2]

 ; write lon
 ivarid = ncdf_varid(file_id,'lon')
 ncdf_varput, file_id, ivarid, tile_lon[i1:i2,j1:j2]

 ; write elev
 ivarid = ncdf_varid(file_id,'elev')
 ncdf_varput, file_id, ivarid, daymetElev[i1:i2,j1:j2]

 ; write mask
 ivarid = ncdf_varid(file_id,'mask')
 ncdf_varput, file_id, ivarid, imask[i1:i2,j1:j2]

; close the NetCDF file
ncdf_close, file_id


; *****
; (6) MAKE MONTHLY GRIDS FOR THE STATION DATA...
; **********************************************

; define variable names
varnames=['ppta','tmp3','dpt3']

; define the start index
ixStart = [0, 234, 234]

; define the end index
ixEnd = [587, 572, 572]

; define the number of valid months
nxValid = [588, 339, 339]

; define variable name (for plotting)
plotName = ['Precipitation (mm/month)', 'Air temperature (!eo!nC)', 'Dewpoint temperature (!eo!nC)']

; loop through variables
for ivar=0,n_elements(varnames)-1 do begin

 ; *****
 ; (6a) READ IN MONTHLY STATION DATA...
 ; *************************************

 ; define filename
 file_stn = '/home/mclark/summa/input/tollgate/stationData/tollgate_forcing_monthly.nc'

 ; open the NetCDF file
 nc_file = ncdf_open(file_stn, /nowrite)

  ; read in the number of filled months
  ivar_id = ncdf_varid(nc_file,varnames[ivar]+'__number_filled_months')
  ncdf_varget, nc_file, ivar_id, nFilledMonths

  ; read in the mean correlation of filled data
  ivar_id = ncdf_varid(nc_file,varnames[ivar]+'__correlation_filled_data')
  ncdf_varget, nc_file, ivar_id, corrFilledData

  ; read in the precip monthly precip data
  ivar_id = ncdf_varid(nc_file,varnames[ivar]+'_monthly')
  ncdf_varget, nc_file, ivar_id, xData

 ; close the netcdf file
 ncdf_close, nc_file

 ; get the dimensions of the precip data
 iDims = size(xData, /dimensions)

 ; define the number of stations and months
 nSta    = iDims[0]
 nMonths = iDims[1]

 ; define valid stations
 ixValidStn = make_array(nsta, /byte, value=1)

 ; if sheltering index missing then out of region
 iValid = where(zShelt lt -999., nValid)
 if(nValid gt 0)then ixValidStn[iValid] = 0

 ; if large number of filled months and low correlation
 iValid = where(nFilledMonths gt 400 and corrFilledData lt 0.9, nValid)
 if(nValid gt 0)then ixValidStn[iValid] = 0

 ; check for serially-complete data
 for iSta=0,nSta-1 do begin
  iValid = where(xData[iSta,ixStart[ivar]:ixEnd[ivar]] gt -50., nValid)
  if(nValid ne nxValid[iVar])then ixValidStn[iSta] = 0
  print, iSta, nValid, nxValid[iVar]
 endfor

 ; remove the quonset site (something funny going on)
 ;if(varnames[ivar] ne 'ppta')then begin
 ; iQuonset = where(cKey eq 'rc-076', nQuonset)
 ; if(nQuonset ne 1)then stop, 'cannot find the quonset'
 ; ixValidStn[iQuonset[0]] = 0
 ;endif

 ; get valid stations
 iValid = where(ixValidStn eq 1, nValid)
 print, 'n = ', nValid

 ; loop through months
 for imonth=0,nMonths-1 do begin

  ; define the time
  cTime = strtrim(stnYear[imonth],2)+'-'+strtrim(string(stnMonth[imonth],format='(i2.2)'),2)

  ; *****
  ; (6b) DEVELOP REGRESSION RELATIONSHIPS...
  ; ****************************************

  ; define grid
  varGrid = make_array(nx_subset,ny_subset, value=-9999., /float)
 
  ; get vector of dependent variables
  yVar = reform(xData[iValid,imonth])

  ; check if there is any missing data
  iMissing = where(yVar lt -50.d, nMissing)
  if(nMissing eq 0)then begin

   ; get mean of the predictors
   zCoord_mean = mean(zCoord[iValid])
   xCoord_mean = mean(xCoord[iValid])

   ; get the standard deviation of the predictors
   zCoord_sdev = stddev(zCoord[iValid])
   xCoord_sdev = stddev(xCoord[iValid])

   ; get matrix of predictor variables
   xVar = transpose([ $
                     [(zCoord[iValid] - zCoord_mean)/zCoord_sdev], $
                     [(xCoord[iValid] - xCoord_mean)/xCoord_sdev]  $
                    ])
 
   ; calculate regression coefficients
   xBeta = regress(xVar, yVar, const=x0, correlation=r, yfit=yPred)

   ; calculate the correlation
   r = correlate(yPred, yVar)
   pTitle='Correlation from spatial regression = '+strtrim(string(r,format='(f11.3,1x)'),2)

   ; *****
   ; (6c) APPLY REGRESSION RELATIONSHIPS...
   ; **************************************

   ; loop through grid
   for ix=0,nx_subset-1 do begin
    for jy=0,ny_subset-1 do begin
 
     ; check if grid overlaps the basin
     ; NOTE: imask is for the full daymet grid
     if(imask[i1+ix,j1+jy] eq 1)then begin
 
      ; define z and x
      zGrid = (daymetElev[i1+ix,j1+jy] - zCoord_mean)/zCoord_sdev
      xGrid = (daymet_x[i1+ix]         - xCoord_mean)/xCoord_sdev

      ; make the prediction
      varGrid[ix,jy] = x0 + xBeta[0]*zGrid + xBeta[1]*xGrid

      ; force precip to be positive
      if(varnames[ivar] eq 'ppta')then begin
       if(varGrid[ix,jy] lt 0.)then varGrid[ix,jy] = 0.
      endif

      ; print progress
      ;print, ix, jy, varGrid[ix,jy]
     
     endif  ; if the gridpoint is valid
    endfor ; looping through y
   endfor ; looping through x

   ; get max-min limits for plotting
   if(varnames[ivar] eq 'ppta')then begin
    vMin =   0.d
    vMax = 200.d
   endif else begin
    vMin1 = floor(min(yVar))
    vMin2 = floor(min(varGrid[where(varGrid gt -50.)]))
    vMin = min([vMin1,vMin2])
    vMax = vMin+10L
   endelse

   ; *****
   ; (6d) PLOT REGRESSION RELATIONSHIPS...
   ; *************************************

   ; plot regression fit
   plot, yVar, yPred, xrange=[vmin,vmax], yrange=[vmin,vmax], xstyle=1, ystyle=1, psym=sym(6), symsize=2, $
    xmargin=[10,-5], ymargin=[4,2], xtitle=varnames[ivar]+' (station)', ytitle=varnames[ivar]+' (predicted)', $
    title=pTitle

   ; make a base plot
   x0 = -0.1*(xmax-xmin)+xmin
   x1 =  0.8*(xmax-xmin)+xmin
   plot, indgen(5), xrange=[x0,x1], yrange=[ymax,ymin], xstyle=5, ystyle=5, $
    xmargin=[0,0], ymargin=[0,0], title=varnames[ivar]+' (station measurements)', /nodata

   ; plot basin outlines
   icolor=0
   plot_basins, icolor

   ; plot variable
   for ista=0,nSta-1 do begin
    if(ixValidStn[ista] eq 1)then begin
     icolor = 250.d * (xData[ista,imonth] - vMin) / (vMax - vMin)
     if(icolor lt   0.d)then icolor=0
     if(icolor gt 250.d)then icolor=250
     plots, xCoord[iSta], yCoord[iSta], color=icolor, psym=sym(1), symsize=2
     ;if(ckey[ista] eq 'rc.tg-145')then $
     ;xyouts, xCoord[iSta], yCoord[iSta], cKey[ista]
    endif
   endfor

   ; make a base plot
   x0 =  0.1*(xmax-xmin)+xmin
   x1 =  1.0*(xmax-xmin)+xmin
   plot, indgen(5), xrange=[x0,x1], yrange=[ymax,ymin], xstyle=5, ystyle=5, $
    xmargin=[0,0], ymargin=[0,0], title=varnames[ivar]+' (gridded estimates)', /nodata
 
   ; define the time
   xyouts, 0.35*(xmax-xmin)+xmin, 0.1*(ymax-ymin)+ymin, cTime, charsize=2
 
   ; Define the shapefile
   file_name = '/home/mclark/summa/ancillary_data/tollgate/Daymet_Tile_11912.shp'
 
    ; Open the Shapefile
    myshape=OBJ_NEW('IDLffShape', file_name)
 
    ; Get the number of entities so we can parse through them
    myshape->IDLffShape::GetProperty, N_ENTITIES=num_ent

    ; Parsing through the entities
    FOR iEnt=0, (num_ent-1) DO BEGIN
     ; Get the Attributes for entity x
     attr = myshape->IDLffShape::GetAttributes(iEnt)
     ; Get the attribute info
     myshape->GetProperty, ATTRIBUTE_INFO=attr_info
     ; Get entity
     ent=myshape->IDLffShape::GetEntity(iEnt)
     ; save x and y
     x = reform((*ent.vertices)[0,*])
     y = reform((*ent.vertices)[1,*])
     ; Clean-up of pointers
     myshape->IDLffShape::DestroyEntity, ent
     ; get the desired segID
     iSegID = attr.ATTRIBUTE_0
     iColID = attr.ATTRIBUTE_1
     iRowID = attr.ATTRIBUTE_2
     xLon   = attr.ATTRIBUTE_3
     xLat   = attr.ATTRIBUTE_4
     if(imask[iColID-1,iRowID-1] eq 1)then begin
      ; define x-y in the subset
      ix = iColID-i1-1
      jy = iRowID-j1-1
      ; print progress
      ;print, iSegID, iColID, iRowID, ix, jy, xLon, tile_lon[iColID-1,iRowID-1], xlat, tile_lat[iColID-1,iRowID-1], $
      ;        varGrid[ix,jy], daymet_x[iColID-1], daymet_yy[iRowID-1], x, y, $
      ;        format='(i6,1x,4(i3,1x),4(f11.6,1x),3(f11.1,1x),4x,2(5(f11.1,1x),4x))'
      ; plot data
      icolor = 250.d * (varGrid[ix,jy] - vMin) / (vMax - vMin)
      if(icolor lt   0.d)then icolor=0
      if(icolor gt 250.d)then icolor=250
      polyfill, x, y, color=icolor
      plots, x, y, color=60
     endif
    ENDFOR  ; parsing through the entities

   ; Close the Shapefile
   OBJ_DESTROY, myshape

   ; overplot the basins
   icolor=255
   plot_basins, icolor

   ; make a colorbar
   x0 = 0.80*(xmax-xmin)+xmin
   x1 = 0.85*(xmax-xmin)+xmin
   x2 = 0.86*(xmax-xmin)+xmin
   x3 = 0.87*(xmax-xmin)+xmin
   x4 = 0.98*(xmax-xmin)+xmin
   y0 = 0.90*(ymax-ymin)+ymin
   y1 = 0.10*(ymax-ymin)+ymin
   y2 = 0.50*(ymax-ymin)+ymin
   yoff = 0.005*(ymax-ymin)
   for ibyt=0,250 do begin
    ; plot the colorbar
    yy0 = (y1-y0)*float(iByt)  /250. + y0
    yy1 = (y1-y0)*float(iByt+1)/250. + y0
    xx = [x0,x1,x1,x0]
    yy = [yy0,yy0,yy1,yy1]
    polyfill, xx, yy, color=iByt
    ; plot the values
    z1 = float(iByt)/25.
    z2 = float(floor(z1))
    if(abs(z1 - z2) lt 0.001)then begin
     xVal = vMin + (vMax - vMin) * float(iByt)/250.d
     plots, [x1,x2], [yy1,yy1]
     if(varnames[ivar] eq 'ppta')then begin
      xText = strtrim(string(xVal,format='(i6)'),2)
     endif else begin
      xText = strtrim(string(xVal,format='(f9.1)'),2)
     endelse
     xyouts, x3, yy0+yoff, xText, charsize=1.5
    endif 
   endfor
   ; plot variable
   xyouts, x4, y2, plotName[ivar], orientation=90, alignment=0.5, charsize=2

   ; write the figure
   write_png, 'monthlyMaps/'+varnames[ivar]+'/'+varnames[ivar]+'_'+cTime+'.png', tvrd(true=1)

   ; print progress
   print, cTime, strtrim(string(r,format='(f11.3,1x)'),2), format='(a10,1x,f9.3)'
   ;stop

  endif  ; if there is no missing data

  ; *****
  ; (6d) WRITE DATA...
  ; ******************

  ; open file
  file_id = ncdf_open(grid_name, /write)

   ; write month
   ivarid = ncdf_varid(file_id,'month')
   ncdf_varput, file_id, ivarid, stnTime[imonth], offset=imonth, count=1

   ; write precip grid
   if(varnames[ivar] eq 'ppta')then ivarid = ncdf_varid(file_id,'pptrate')
   if(varnames[ivar] eq 'tmp3')then ivarid = ncdf_varid(file_id,'airtemp')
   if(varnames[ivar] eq 'dpt3')then ivarid = ncdf_varid(file_id,'dewtemp')
   ncdf_varput, file_id, ivarid, varGrid, offset=[0,0,imonth], count=[nx_subset,ny_subset,1]

  ; close file
  ncdf_close, file_id

 endfor  ; looping through the months
 stop, 'looping through variables'


endfor  ; looping through the variables



stop
end



; ************************************************************************************
; ************************************************************************************
; ************************************************************************************
; ************************************************************************************
; ************************************************************************************

pro plot_basins, icolor

; *****
; (0) IDENTIFY DESIRED BASINS...
; ******************************

; define the file path to the correspondence file
cros_path = '/home/mclark/summa/ancillary_data/tollgate/'

; define the filename (just an example file -- only need the coordinates)
cros_name = cros_path + 'Correspondence.nc'

; open netcdf file for reading
file_id = ncdf_open(cros_name, /nowrite)

 ; read the polygon ID
 ivarid = ncdf_varid(file_id,'polyid')
 ncdf_varget, file_id, ivarid, polyid

; close the NetCDF file
ncdf_close, file_id


; *****
; (1) PLOT UP THE SUB-BASINS...
; *****************************

; Define the shapefile
file_name = '/home/mclark/summa/ancillary_data/tollgate/Catchment2_Project.shp'

; Open the Shapefile
myshape=OBJ_NEW('IDLffShape', file_name)

 ; Get the number of entities so we can parse through them
 myshape->IDLffShape::GetProperty, N_ENTITIES=num_ent

 ; Parsing through the entities
 FOR ix=0, (num_ent-1) DO BEGIN
  ; Get the Attributes for entity x
  attr = myshape->IDLffShape::GetAttributes(ix)
  ; Get the attribute info
  myshape->GetProperty, ATTRIBUTE_INFO=attr_info
  ; Get entity
  ent=myshape->IDLffShape::GetEntity(ix)
  ; save x and y
  x = reform((*ent.vertices)[0,*])
  y = reform((*ent.vertices)[1,*])
  ; get the number of vertices
  nVerts = ent[0].n_vertices
  ; get the number of parts
  nParts = ent[0].n_parts
  ; save the indices that define the parts of the shape
  iStart = *ent[0].parts
  if(nParts gt 1)then begin
   iCount = [iStart[1:nParts-1] - iStart[0:nParts-2], nVerts - iStart[nParts-1]]
  endif else begin
   iCount = [nVerts]
  endelse
  ; Clean-up of pointers
  myshape->IDLffShape::DestroyEntity, ent
  ; get the desired segID
  iBasID = attr.ATTRIBUTE_0
  ipos = where(polyid eq iBasID, nMatch)
  if(nMatch eq 1)then begin
   ; plot data
   for iPart=0,nParts-1 do begin
    xx = x[iStart[iPart]:iStart[iPart]+iCount[iPart]-1]
    yy = y[iStart[iPart]:iStart[iPart]+iCount[iPart]-1]
    plots, xx, yy, thick=1, color=icolor
   endfor
  endif
 ENDFOR  ; parsing through the entities

; Close the Shapefile
OBJ_DESTROY, myshape

end
