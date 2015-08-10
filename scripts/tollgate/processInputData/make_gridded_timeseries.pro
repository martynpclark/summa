pro make_gridded_timeseries

; desire a plot
ixDesirePlot = 0  ; =1 then plot

; define plotting parameters
if(ixDesirePlot eq 1)then begin
 window, 0, xs=1350, ys=500, retain=2
 device, decomposed=0
 LOADCT, 39
 !P.BACKGROUND=255
 !P.CHARSIZE=3
 !P.COLOR=0
 erase, color=255
 !P.MULTI=[0,3,1]
endif

; define station data file
stn_path = '/home/mclark/summa/input/tollgate/stationData/netcdf_data/'
stn_name = stn_path + 'tollgate_forcing_monthly.nc'

; define grid data file
grid_path = '/home/mclark/summa/input/tollgate/interpGrid/'
grid_name = grid_path + 'stn2grid_tollgate_monthly.nc'

; define variable names for the station data
varnames_stn = ['ppta','tmp3','dpt3','sol','wnd3sa']

; define variable names for the grid
varnames_grid = ['pptrate','airtemp','dewtemp','swRadDn','windspd']

; define long names
vardesc = ['Precipitation, Hamon 1971 Dual Gage Wind Corrected', $
           'Air Temperature', $
           'Dewpoint Temperature', $
           'Incoming solar radiation flux', $
           'Wind speed']

; define variable units
varunit = ['kg m-2 s-1', $
           'K', $
           'K', $
           'W m-2', $
           'm s-1']

; define the search radius
searchRadius = 20000.d ; 20km

; *****
; * READ IN THE SPATIAL GRIDS...
; ******************************

; open netcdf file for reading
file_id = ncdf_open(grid_name, /nowrite)

 ; get time units
 ivar_id = ncdf_varid(file_id,'month')
 ncdf_attget, file_id, ivar_id, 'units', bunits
 cunits = string(bunits)

 ; get the base julian day
 tunit_words  = strsplit(string(cunits),' ',/extract)
 tunit_idate  = fix(strsplit(tunit_words[2],'-',/extract))
 tunit_ihour  = fix(strsplit(tunit_words[3],':',/extract))
 bjulian      = julday(tunit_idate[1],tunit_idate[2],tunit_idate[0],tunit_ihour[0],tunit_ihour[1],tunit_ihour[2])

 ; read the time vector (convert to units of days)
 if(strtrim(tunit_words[0],2) eq 'seconds') then aoff=1.d/86400.d else stop, 'unknown time units'  ; get offset in days
 ncdf_varget, file_id, ivar_id, atime
 djulian = bjulian + atime*aoff
 nMonths = n_elements(dJulian)

 ; get the year, month, day
 caldat, djulian, im_grid, id_grid, iyyy_grid

 ; read the x coordinate
 ivarid = ncdf_varid(file_id,'x')
 ncdf_varget, file_id, ivarid, x_grid

 ; read the y coordinate
 ivarid = ncdf_varid(file_id,'y')
 ncdf_varget, file_id, ivarid, y_grid

 ; read the mask
 ivarid = ncdf_varid(file_id,'mask')
 ncdf_varget, file_id, ivarid, mask_grid

; close the file
ncdf_close, file_id

; get the size of the x and the y dimensions
nx = n_elements(x_grid)
ny = n_elements(y_grid)

; get the x-limits
xmin = min(x_grid)
xmax = max(x_grid)

; get the y-limits
ymin = min(y_grid)
ymax = max(y_grid)

; *****
; * READ IN THE DATES FOR THE HOURLY TIME SERIES...
; *************************************************

; open the station file for reading
file_id = ncdf_open(stn_name, /nowrite)

 ; get time units
 ivar_id = ncdf_varid(file_id,'time')
 ncdf_attget, file_id, ivar_id, 'units', bunits
 cunits = string(bunits)

 ; get the base julian day
 tunit_words  = strsplit(string(cunits),' ',/extract)
 tunit_idate  = fix(strsplit(tunit_words[2],'-',/extract))
 tunit_ihour  = fix(strsplit(tunit_words[3],':',/extract))
 bjulian      = julday(tunit_idate[1],tunit_idate[2],tunit_idate[0],tunit_ihour[0],tunit_ihour[1],tunit_ihour[2])

 ; read the time vector (convert to units of days)
 if(strtrim(tunit_words[0],2) eq 'seconds') then aoff=1.d/86400.d else stop, 'unknown time units'  ; get offset in days
 ncdf_varget, file_id, ivar_id, atime
 djulian = bjulian + atime*aoff
 ntime = n_elements(dJulian)

 ; get the x-coordinate
 ivarid = ncdf_varid(file_id,'LCC_x')
 ncdf_varget, file_id, ivarid, x_station

 ; get the y-coordinate
 ivarid = ncdf_varid(file_id,'LCC_y')
 ncdf_varget, file_id, ivarid, y_station

 ; get the year, month, day
 verySmall = 1.d-8 ; offset to ensure we get variables at the end of the day
 caldat, djulian-verySmall, im_station, id_station, iyyy_station, ih_station

; close the file
ncdf_close, file_id

; get the number of stations
nStations = n_elements(x_station)

; *****
; * ADD HOURLY DIMENSIONS AND VARIABLES TO THE GRID FILE...
; *********************************************************

; open netcdf file for writing
file_id = ncdf_open(grid_name, /write)

 ; get the ID of the x and y dimensions
 x_id = ncdf_dimid(file_id, 'x')
 y_id = ncdf_dimid(file_id, 'y')

 ; get into control mode (in order to make a new variable)
 ncdf_control, file_id, /redef

  ; define time dimension
  if(ncdf_dimid(file_id,'time') eq -1)then begin
   time_id = ncdf_dimdef(file_id, 'time', /unlimited)
  endif else begin
   time_id = ncdf_dimid(file_id,'time')
  endelse
 
  ; define the time variable
  if(ncdf_varid(file_id, 'time') eq -1) then begin
   ivarid = ncdf_vardef(file_id, 'time', time_id, /double)
   ncdf_attput, file_id, ivarid, 'units', cunits, /char
  endif

  ; define other variables
  for ivar=0,n_elements(varnames_grid)-1 do begin
   if(ncdf_varid(file_id, varnames_grid[ivar]+'_hourly') eq -1)then begin
    ivarid = ncdf_vardef(file_id, varnames_grid[ivar]+'_hourly', [x_id, y_id, time_id], /float)
    ncdf_attput, file_id, ivarid, 'long_name', strtrim(vardesc[ivar],2), /char
    ncdf_attput, file_id, ivarid, 'units', strtrim(varunit[ivar],2), /char
    ncdf_attput, file_id, ivarid, '_FillValue', -9999., /float
   endif
  endfor

 ; end control
 ncdf_control, file_id, /endef

; close the NetCDF file
ncdf_close, file_id

; *****
; * INTERPOLATE...
; ****************

; get the total number of desired grid points
xTotalDesire = float(total(mask_grid))

; loop through variables
for ivar=0,n_elements(varnames_stn)-1 do begin

 ; get the monthly station data for a given variable
 file_id  = ncdf_open(stn_name, /nowrite) 
  ivarid = ncdf_varid(file_id,varnames_stn[ivar]+'_monthly')
  ncdf_varget, file_id, ivarid, stn_monthly
 ncdf_close, file_id

 ; get the monthly station flag for a given variable
 file_id  = ncdf_open(stn_name, /nowrite)
  ivarid = ncdf_varid(file_id,varnames_stn[ivar]+'_monthly_flag')
  ncdf_varget, file_id, ivarid, stn_monthly_flag
 ncdf_close, file_id

 ; get the monthly gridded data for a given variable
 file_id  = ncdf_open(grid_name, /nowrite)  
  ivarid = ncdf_varid(file_id,varnames_grid[ivar]+'_monthly')
  ncdf_varget, file_id, ivarid, grid_monthly
 ncdf_close, file_id

 ; define an index for the output
 ixOutput=0L

 ; loop through months
 iMonthStart = 336  ; 336=Jan 1990
 iMonthEnd   = 560  ; 560=Sep 2008
 for iMonth=iMonthStart,iMonthEnd do begin

  ; identify start index and count
  iMatch = where(im_station eq im_grid[iMonth] and iyyy_station eq iyyy_grid[iMonth], nMatch)
  iStart = iMatch[0]

  ; get the hourly station data for a given variable
  file_id = ncdf_open(stn_name, /nowrite)
   ivarid = ncdf_varid(file_id,varnames_stn[ivar])
   ncdf_varget, file_id, ivarid, stn_hourly, offset=[0,iStart], count=[nStations,nMatch]
  ncdf_close, file_id

  ; make a base plot
  if(ixDesirePlot eq 1)then begin
   icolor_grid  = 250
   icolor_basin = 0
   x0 = -0.1*(xmax-xmin)+xmin
   x1 =  0.8*(xmax-xmin)+xmin
   plot, indgen(5), xrange=[x0,x1], yrange=[ymin,ymax], xstyle=5, ystyle=5, $
    xmargin=[0,0], ymargin=[0,0], /nodata
   plot_grid, mask_grid, nx, ny, icolor_grid  ; plot grid
   plot_basins, icolor_basin ; plot basin outlines
  endif
  
  ; loop through hourly time series for data subset
  for iHour=0,nMatch-1 do begin

   ; get the date index
   jHour=iMatch[iHour]

   ; get the number of valid stations
   iValid = where(stn_hourly[*,iHour] gt -50., nValid)
   if(nValid eq 0)then stop, 'insufficient data' 

   ; initialize the total number of valid stations
   nValidTotal = 0L

   ; define the grid
   gridInterp = dblarr(nx,ny)

   ; loop through the grid
   for ix=0,nx-1 do begin
    for iy=0,ny-1 do begin

     ; check if we desire information for a given gridpoint
     if(mask_grid[ix,iy] eq 1)then begin

      ; compute distances from each station
      xDist = sqrt( (x_grid[ix] - x_station[*])^2.d + (y_grid[iy] - y_station[*])^2.d )

      ; identify valid stations
      iValid = where(stn_hourly[*,iHour] gt -50. and stn_monthly[*,iMonth] gt -50. and stn_monthly_flag[*,iMonth] eq 0 $
                     and xDist[*] le searchRadius, nValid)
      nValidTotal = nValidTotal + nValid

      ; check for zero precip
      if(varnames_stn[ivar] eq 'ppta' or varnames_stn[ivar] eq 'sol')then begin
       if(total(stn_hourly[iValid,iHour]) lt 1.d-8)then begin
        gridInterp[ix,iy] = 0.d
        continue
       endif
      endif

      ; get the interpolation weight
      xWeight = ( (searchRadius - xDist[iValid])/(searchRadius*xDist[iValid]) )^1.d
      xWeight = xWeight/total(xWeight)

      ; variable dependent interpolation
      case varnames_stn[ivar] of

       ; precip: normal ratio interpolation
       'ppta':begin
        xRatio = stn_hourly[iValid,iHour]/stn_monthly[iValid,iMonth]
        gridInterp[ix,iy] = total(xWeight[*]*xRatio[*]) * grid_monthly[ix,iy,imonth]
       end

       ; solar radiation: normal ratio interpolation
       'sol':begin
        xRadMJ = stn_hourly[iValid,iHour]*3600.d/1000000.d  ; W m-2 --> MJ m-2
        xRatio = xRadMJ/stn_monthly[iValid,iMonth]
        gridInterp[ix,iy] = total(xWeight[*]*xRatio[*]) * grid_monthly[ix,iy,imonth]
       end

       ; all other variables: anomaly interpolation
       else: begin
        xAnom = stn_hourly[iValid,iHour] - stn_monthly[iValid,iMonth]
        gridInterp[ix,iy] = total(xWeight[*]*xAnom[*]) + grid_monthly[ix,iy,imonth]
       end

      endcase

      ; scale variables
      case varnames_stn[ivar] of
       'ppta':   gridInterp[ix,iy] = gridInterp[ix,iy]/3600.d           ; mm hour-1 --> kg m-2 s-1
       'tmp3':   gridInterp[ix,iy] = gridInterp[ix,iy] + 273.16d        ; deg C --> K
       'dpt3':   gridInterp[ix,iy] = gridInterp[ix,iy] + 273.16d        ; deg C --> K
       'sol':    gridInterp[ix,iy] = gridInterp[ix,iy]*1000000.d/3600.d ; MJ m-2 --> W m-2
       else:  ; (else, do nothing)
      endcase

      ; plot grid location
      if(ixDesirePlot eq 1)then plots, x_grid[ix], y_grid[iy], psym=sym(6), color=80
      
      ; plot distances
      if(ixDesirePlot eq 1)then begin
       for iStation=0,nValid-1 do begin
        jStation = iValid[iStation]
        if(varnames_stn[ivar] ne 'ppta')then print, xDist[jStation], xWeight[iStation], xAnom[iStation],  format='(3(f9.3,1x))'
        if(varnames_stn[ivar] eq 'ppta')then print, xDist[jStation], xWeight[iStation], xRatio[iStation], format='(3(f9.3,1x))'
        plots, x_station[jStation], y_station[jStation], psym=sym(1), symsize=2, color=xDist[jStation]/100.
       endfor  ; looping through stations
       stop, 'plotting data'
      endif  ; if desire a plot

      ; check precip
      if(varnames_stn[ivar] eq 'ppta')then begin
       if(gridInterp[ix,iy] gt 1000.)then stop, 'huge precip -- something went wrong'
      endif

     endif else begin  ; if we desire information for a given gridpoint
      gridInterp[ix,iy] = -9999.d
     endelse  ; if we desire information for a given gridpoint

    endfor  ; looping through the y dimension
   endfor  ; looping through the x dimension

   ; get average number of valid points
   nValidAverage = float(nValidTotal)/xTotalDesire

   ; open file for writing
   file_id = ncdf_open(grid_name, /write)

    ; write time
    ivarid = ncdf_varid(file_id,'time')
    ncdf_varput, file_id, ivarid, atime[jHour], offset=ixOutput, count=1

    ; write interpolated grid
    if(varnames_stn[ivar] eq 'ppta')then    ivarid = ncdf_varid(file_id,'pptrate_hourly')
    if(varnames_stn[ivar] eq 'tmp3')then    ivarid = ncdf_varid(file_id,'airtemp_hourly')
    if(varnames_stn[ivar] eq 'dpt3')then    ivarid = ncdf_varid(file_id,'dewtemp_hourly')
    if(varnames_stn[ivar] eq 'sol' )then    ivarid = ncdf_varid(file_id,'swRadDn_hourly')
    if(varnames_stn[ivar] eq 'wnd3sa' )then ivarid = ncdf_varid(file_id,'windspd_hourly')
    ncdf_varput, file_id, ivarid, gridInterp, offset=[0,0,ixOutput], count=[nx,ny,1]

   ; close file
   ncdf_close, file_id

   ; print the date
   print, varnames_stn[ivar], iyyy_station[jHour], im_station[jHour], id_station[jHour], ih_station[jHour], nValidAverage, $
    gridInterp[11,2], format='(a10,1x,i4,1x,3(i2,1x),f12.2,1x,f30.16)'

   ; increment the output index
   ixOutput = ixOutput+1

  endfor ; looping through hours in a month

 endfor ; looping through months

endfor  ; looping through variables


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

; ******************************
; ******************************

pro plot_grid, imask, nx, ny, icolor

; define the start indices
i1 = 110
j1 = 100

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
  ; get the column and row indices for the entire daymet tile
  iColID = attr.ATTRIBUTE_1
  iRowID = attr.ATTRIBUTE_2
  ; get local indices
  ix = iColID-i1-1
  jy = iRowID-j1-1
  ; plot if in the local region
  if(ix gt 0 and ix lt nx)then begin
   if(jy gt 0 and jy lt ny)then begin
    if(imask[ix,jy] eq 1)then plots, x, y, color=icolor
   endif
  endif    
 ENDFOR  ; parsing through the entities

; Close the Shapefile
OBJ_DESTROY, myshape

end


