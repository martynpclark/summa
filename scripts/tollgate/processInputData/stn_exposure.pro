pro stn_exposure

; define plotting parameters
window, 1, xs=1500, ys=1000, retain=2
device, decomposed=0
LOADCT, 39
!P.BACKGROUND=255
!P.CHARSIZE=3
!P.COLOR=0
erase, color=255
!P.MULTI=[0,3,2]

; define the date format
dummy = label_date(date_format=['%D-%M!C%Y'])

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
; (1) READ IN THE ASCII GRID FOR ELEV...
; **************************************

print, 'reading elevation'

; read save file
;goto, restore_files

; define file path for the ancillary data
elev_path = '/home/mclark/summa/ancillary_data/tollgate/'

; define filenames
elev_name = elev_path + 'ago_elevation_low_pass_lcc.txt'  ; elevation
mask_name = elev_path + 'hydroid_on_elevation_grid.txt'   ; hydro_id

; read elevation
read_asciiGrid, elev_name, xElev, yElev, zElev, ncols, nrows, cSize

; read hydro id
read_asciiGrid, mask_name, xMask, yMask, zMask, ncols, nrows, cSize

; reverse arrays
zElev = temporary(reverse(zElev,2))
zMask = temporary(long(reverse(zMask,2)+0.5))

; define half the cell size
cHalf = cSize/2.d

; save files
save, xElev, yElev, zElev, ncols, nrows, cSize, cHalf, filename='xIDLsave/tollgateElev.sav'
save, xMask, yMask, zMask, ncols, nrows, cSize, cHalf, filename='xIDLsave/tollgateMask.sav'

restore_files:

restore, 'xIDLsave/'+'tollgateElev.sav'
restore, 'xIDLsave/'+'tollgateMask.sav'

; *****
; (2) PLOT THE ELEVATION...
; *************************

print, 'plot elevation'

;zMin = 1000.d
;zMax = 2500.d
zMin = 1200.d
zMax = 2200.d
zRng = zMax - zMin

; define x range
;iMin = 0
;iMax = n_elements(xElev)-1
;iMin = 2500  ; rme
;iMax = 3200  ; rme
iMin = 3750
iMax = 4250

; define yrange
;jMin = 0
;jMax = n_elements(yElev)-1
;jMin = 1150  ; rme
;jMax = 1850  ; rme
jMin = 2900  ; usc
jMax = 3400  ; usc

; define xrange
xmin = xElev[iMin]
xmax = xElev[iMax]

; define yrange
ymin = yElev[jMin]
ymax = yElev[jMax]

; define desired basin
;ixBasin = 521
ixBasin = 268

; make a base plot
plot, indgen(5), xrange=[xmin,xmax], yrange=[ymin,ymax], xstyle=5, ystyle=5, $
 xmargin=[0,0], ymargin=[0,0], /nodata

; loop through grid
for iCol=iMin,iMax do begin
 for jRow=jMin,jMax do begin

  ; only plot data subset
  if(zElev[iCol,jRow] lt zMin or zElev[iCol,jRow] gt zMax)then continue

  ; only plot desired basin
  if(zMask[iCol,jRow] ne ixBasin)then continue

  ; get x coordinates
  xx = [xElev[iCol]-cHalf,xElev[iCol]+cHalf,xElev[iCol]+cHalf,xElev[iCol]-cHalf]
  yy = [yElev[jRow]-cHalf,yElev[jRow]-cHalf,yElev[jRow]+cHalf,yElev[jRow]+cHalf]

  ; get color
  icolor = 250. * (zElev[iCol,jRow] - zMin) / zRng

  ; plot elevation
  polyfill, xx, yy, color=icolor

 endfor  ; rows
endfor  ; columns

; *****
; (3) PLOT UP THE SUB-BASINS...
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
  if(iBasID ne ixBasin)then continue
  ipos = where(polyid eq iBasID, nMatch)
  if(nMatch eq 1)then begin
   ; plot data
   for iPart=0,nParts-1 do begin
    xx = x[iStart[iPart]:iStart[iPart]+iCount[iPart]-1]
    yy = y[iStart[iPart]:iStart[iPart]+iCount[iPart]-1]
    plots, xx, yy, thick=1
   endfor
  endif
 ENDFOR  ; parsing through the entities

; Close the Shapefile
OBJ_DESTROY, myshape


; *****
; (4) COMPUTE EXPOSURE...
; ***********************

print, 'computing exposure'

; skip because done already
;goto, restore_shelter

; number of cells to skip
nSkip = 1

; define search distance
xSearch = 200.d

; get limits for the search
iSearch = ceil(xSearch/cSize)

; convert radians to degrees
rad2deg = 180.d/!PI

; define range of aziumth
aWin =  15.d
aMid = 230.d
aMin = aMid - aWin
aMax = aMid + aWin

; define sheltering
zShel = fltarr(nCols,nRows)

; identify the number of elements in the basin
iBasin = where(zMask eq ixBasin and zElev gt 1800., nBasin)

; keep count of the number of elements
jBasin = 0L

; loop through grid
for iMid=iMin,iMax do begin
 for jMid=jMin,jMax do begin
;for iMid=2997,2997 do begin
; for jMid=1356,1359 do begin

  ; check if in the basin
  if(zMask[iMid,jMid] ne ixBasin or zElev[iMid,jMid] le 1800.)then continue

  ; count the number of elements
  jBasin = jBasin + 1

  ; define initial vectors
  ;vec_xDist = make_array(1, /float, value=0.)
  ;vec_zDiff = make_array(1, /float, value=0.)
  vec_azimu = make_array(1, /float, value=0.)
  vec_slope = make_array(1, /float, value=0.)

  ; define mean slope
  ;zMean = 0.
  ;nMean = 0L

  ; loop through columns
  for iCol=iMid-iSearch,iMid-1,nSkip do begin

   ; compute x-difference
   xDiff = xElev[iCol] - xElev[iMid]

   ; loop through rows
   for jRow=jMid-iSearch,jMid-1,nSkip do begin

    ; compute y-difference
    yDiff = yElev[jRow] - yElev[jMid]

    ; compute the azimuth
    azimu = rad2deg*atan(xDiff, yDiff) + 360.d

    ; compute the distance
    xDist = sqrt(xDiff^2. + yDiff^2.)

    ; check if within the window
    if(azimu gt aMin and azimu lt aMax and xDist lt xSearch)then begin

     ; compute elevation difference
     zDiff = zElev[iCol,jRow] - zElev[iMid,jMid]   

     ; compute slope
     slope = rad2deg*atan(zDiff/xDist)

     ; save info
     ;vec_xDist = [vec_xDist, xDist]
     ;vec_zDiff = [vec_zDiff, zDiff]
     vec_azimu = [vec_azimu, azimu]
     vec_slope = [vec_slope, slope]

     ; save data
     ;zMean = zMean + slope
     ;nMean = nMean + 1

    endif  ; if within the window

   endfor  ; looping through data subset
  endfor  ; looping through data subset

  ; define the number of 5 deg bins
  width = 1.  ; width of the azimuth
  nBins = floor((aMax - aMin)/width + 0.01)

  ; define the maximum slope for each of the 5 deg bins
  xSlope = fltarr(nBins)

  ; get the maximum slope in 5 deg increments
  for iBin=0,nBins-1 do begin
   xAzi = aMin + float(iBin)*width
   iValid = where(vec_azimu gt xAzi and vec_azimu le xAzi+width, nValid)
   xSlope[iBin] = max(vec_slope[iValid])
   ;print, xAzi, xAzi+width, xSlope[iBin], nValid, format='(3(f11.3,1x),i6)'
   ;if(iBin eq 2)then begin
   ; print, 'vec_xDist = ', vec_xDist[iValid]
   ; print, 'vec_zDiff = ', vec_zDiff[iValid]
   ; print, 'vec_slope = ', vec_slope[iValid]
   ; stop
   ;endif
  endfor

  ; save mean slope
  zShel[iMid,jMid] = mean(xSlope)

  ; compute fractional progress
  fProgress = float(jBasin)/float(nBasin)

  ; print progress
  print, iMid, jMid, jBasin, nBasin, fProgress, zShel[iMid,jMid], format='(4(i6,1x),2(f20.8,1x))'

 endfor  ; looping through the grid
endfor  ; looping through the grid

; save the sheltering grid
save, xElev, yElev, zShel, ncols, nrows, cSize, cHalf, filename='xIDLsave/'+'sheepCreekShel.sav'

; restore the sheltering grid
restore_shelter:
restore, 'xIDLsave/'+'sheepCreekShel.sav'

; make a base plot
plot, indgen(5), xrange=[xmin,xmax], yrange=[ymin,ymax], xstyle=5, ystyle=5, $
 xmargin=[0,0], ymargin=[0,0], /nodata

; define limits for sheltering
iValid = where(zMask eq ixBasin, nValid)
xMin = min(zShel[iValid])
xMax = max(zShel[iValid])
xRng = xMax - xMin

; loop through grid
for iCol=iMin,iMax do begin
 for jRow=jMin,jMax do begin

  ; only plot data subset
  if(zMask[iCol,jRow] ne ixBasin)then continue

  ; get x coordinates
  xx = [xElev[iCol]-cHalf,xElev[iCol]+cHalf,xElev[iCol]+cHalf,xElev[iCol]-cHalf]
  yy = [yElev[jRow]-cHalf,yElev[jRow]-cHalf,yElev[jRow]+cHalf,yElev[jRow]+cHalf]

  ; get color
  icolor = 250. * (zShel[iCol,jRow] - xMin) / xRng

  ; plot sheltering
  polyfill, xx, yy, color=icolor

 endfor  ; rows
endfor  ; columns


; *****
; (5) GET THE STATION DATA... 
; ***************************

; define the file for the station data
data_path = '/home/mclark/summa/input/tollgate/stationData/netcdf_data/'
file_stn  = data_path + 'tollgate_forcing_monthly.nc'

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

 ; read in the station x-coordinate
 ivar_id = ncdf_varid(nc_file,'LCC_x')
 ncdf_varget, nc_file, ivar_id, xCoord

 ; read in the station y-coordinate
 ivar_id = ncdf_varid(nc_file,'LCC_y')
 ncdf_varget, nc_file, ivar_id, yCoord

 ; read in the station elevation
 ivar_id = ncdf_varid(nc_file,'elevation')
 ncdf_varget, nc_file, ivar_id, zCoord

 ; read in the precip monthly precip data
 ivar_id = ncdf_varid(nc_file,'ppta_monthly')
 ncdf_varget, nc_file, ivar_id, xData

; close the NetCDF file
ncdf_close, nc_file

; *****
; (6) CREATE A NEW VARIABLE FOR THE MAXIMUM UPWIND SLOPE PARAMETER... 
; *******************************************************************

; define the file for the station data
file_stn  = data_path + 'tollgate_forcing_monthly.nc'

; open the NetCDF file
nc_file = ncdf_open(file_stn, /write)

 ; get the dimension id for station
 stn_id  = ncdf_dimid(nc_file, 'station')

 ; get into control mode (in order to make a new variable)
 ncdf_control, nc_file, /redef

  ; make a new variable to store the maximum upwind slope parameter
  if(ncdf_varid(nc_file, 'maximum_upwind_slope_parameter') eq -1)then begin
   ivarid = ncdf_vardef(nc_file, 'maximum_upwind_slope_parameter', stn_id, /float)
   ncdf_attput, nc_file, ivarid, 'long_name', 'maximum upwind slope within a distance of 200m, averaged for 1 deg bins within a 30 deg window around the mean wind direction', /char
   ncdf_attput, nc_file, ivarid, '_FillValue', -9999., /float
  endif

 ; exit control mode
 ncdf_control, nc_file, /endef

; close the NetCDF file
ncdf_close, nc_file

; *****
; (6) COMPUTE EXPOSURE FOR INDIVIDUAL STATIONS...
; ***********************************************

; get the dimensions of the precip data
iDims = size(xData, /dimensions)

; define the number of stations and months
nSta    = iDims[0]
nMonths = iDims[1]

; define mean precip
xMean = fltarr(nSta)

; define sheltering
xShelter = fltarr(nSta)
xShelter[*] = -9999.d

; loop through stations
for iSta=0,nSta-1 do begin

 ; just do one station for now
 ;if(strtrim(cKey[iSta],2) ne 'rc-055')then continue
 ;if(strtrim(cKey[iSta],2) ne 'rc.tg.rme-166b')then continue
 ;if(strtrim(cKey[iSta],2) ne 'rc.tg.rme-176')then continue
 ;if(strtrim(cKey[iSta],2) ne 'rc.tg.rme-rmsp')then continue

 ; check for serially-complete data
 iValid = where(xData[iSta,*] gt -0.1, nValid)
 if(nValid eq nMonths)then begin

  ; compute mean monthly precip
  xMean[iSta] = mean(xData[iSta,iValid])

  ; define the location of the station
  sxMin = min(abs(xElev - xCoord[iSta]), iMid)
  syMin = min(abs(yElev - yCoord[iSta]), jMid)

  ; check that the station is within the dem
  if(abs(sxMin) lt cSize*2.d and abs(syMin) lt cSize*2.d and zElev[iMid,jMid] gt 0.)then begin

   ; compute sheltering over a window around the station
   vec_zShelter=fltarr(11,11)
   for iLoc=iMid-5,iMid+5 do begin
    for jLoc=jMid-5,jMid+5 do begin
     shelter, xElev, yElev, zElev, cSize, iLoc, jLoc, zShelter
     vec_zShelter[iLoc-iMid+5,jLoc-jMid+5] = zShelter
     ;print, iLoc, jLoc, iLoc-iMid+5, jLoc-jMid+5, zShelter, zShel[iLoc,jLoc], zElev[iLoc,jLoc], format='(4(i6,1x),3(f13.5,1x))'
    endfor
   endfor

   ; define mean sheltering
   xShelter[iSta] = mean(vec_zShelter)

   ; define color
   icolor = 250. * (xShelter[iSta] - xMin) / xRng

  ; station is outside the dem
  endif else begin
   xShelter[iSta] = -9999.d
   icolor=255
  endelse

  ; write data to the NetCDF file
  nc_file = ncdf_open(file_stn, /write)
   ivarid = ncdf_varid(nc_file, 'maximum_upwind_slope_parameter')
   ncdf_varput, nc_file, ivarid, xShelter[iSta], offset=ista, count=1
  ncdf_close, nc_file

  ; plot data
  plots, xCoord[iSta], yCoord[iSta], color=icolor, psym=sym(1), symsize=2
  plots, xCoord[iSta], yCoord[iSta], color=255, psym=sym(6), symsize=2
  xyouts, xCoord[iSta], yCoord[iSta], ' '+strtrim(cKey[iSta],2)

  ; print data
  print, strtrim(cKey[iSta],2), ': ', strtrim(cName[iSta],2), xMean[iSta], xCoord[iSta], yCoord[iSta], zCoord[iSta], $
    xShelter[iSta], icolor, format='(a15,a2,a80,5(f13.3,1x),i6)'

 ; some data missing
 endif else begin
  xMean[iSta] = -9999.
  print, strtrim(cKey[iSta],2), ': ', strtrim(cName[iSta],2), format='(a15,a2,a80)'
 endelse

endfor  ; looping through stations





stop
end


; *****
; read an ascii gis grid
pro read_asciiGrid, filenm, xElev, yElev, zElev, ncols, nrows, cSize

; define the header
cHead=''
nHead=6

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
 zElev = fltarr(nCols,nRows)
 readf, in_unit, zElev

; close file
free_lun, in_unit

; define x and y coordinates
cHalf = cSize/2.d
xElev = xll + dindgen(nCols)*cSize + cHalf
yElev = yll + dindgen(nRows)*cSize + cHalf

end

; *****
; compute sheltering index
pro shelter, xElev, yElev, zElev, cSize, iMid, jMid, zShelter

; number of cells to skip
nSkip = 1

; define search distance
xSearch = 200.d

; get limits for the search
iSearch = ceil(xSearch/cSize)

; convert radians to degrees
rad2deg = 180.d/!PI

; define range of aziumth
aWin =  15.d
aMid = 230.d
aMin = aMid - aWin
aMax = aMid + aWin

; define initial vectors
vec_azimu = make_array(1, /float, value=0.)
vec_slope = make_array(1, /float, value=0.)

; loop through columns
for iCol=iMid-iSearch,iMid-1,nSkip do begin

 ; compute x-difference
 xDiff = xElev[iCol] - xElev[iMid]

 ; loop through rows
 for jRow=jMid-iSearch,jMid-1,nSkip do begin

  ; compute y-difference
  yDiff = yElev[jRow] - yElev[jMid]

  ; compute the azimuth
  azimu = rad2deg*atan(xDiff, yDiff) + 360.d

  ; compute the distance
  xDist = sqrt(xDiff^2. + yDiff^2.)

  ; check if within the window
  if(azimu gt aMin and azimu lt aMax and xDist lt xSearch)then begin

   ; compute elevation difference
   zDiff = zElev[iCol,jRow] - zElev[iMid,jMid]

   ; compute slope
   slope = rad2deg*atan(zDiff/xDist)

   ; save info
   vec_azimu = [vec_azimu, azimu]
   vec_slope = [vec_slope, slope]

  endif  ; if within the window

 endfor  ; looping through data subset
endfor  ; looping through data subset

; define the number of 5 deg bins
width = 1.  ; width of the azimuth
nBins = floor((aMax - aMin)/width + 0.01)

; define the maximum slope for each of the 5 deg bins
xSlope = fltarr(nBins)

; get the maximum slope in 5 deg increments
for iBin=0,nBins-1 do begin
 xAzi = aMin + float(iBin)*width
 iValid = where(vec_azimu gt xAzi and vec_azimu le xAzi+width, nValid)
 xSlope[iBin] = max(vec_slope[iValid])
endfor

; save mean slope
zShelter = mean(xSlope)

end









