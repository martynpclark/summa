pro plot_interp_timeseries

; define plotting parameters
window, 0, xs=2250, ys=1350, retain=2
device, decomposed=0
LOADCT, 39
!P.BACKGROUND=255
!P.CHARSIZE=3
!P.COLOR=0
erase, color=255
!P.MULTI=[0,5,4]

; define the date format
dummy = label_date(date_format=['%D!C%M'])

; define variable names for the station data
varnames_stn = ['ppta','tmp3','dpt3','sol','wnd3sa']

; define variable names for the grid
varnames_grid = ['pptrate','airtemp','dewtemp','swRadDn','windspd']

; define plot range
vmin = [   0,-30,-30,    0,  0]
vmax = [1000, 40, 40, 1000, 20]

; *****
; * GET THE GRID METADATA...
; **************************

; define the filename 
grid_path = '/home/mclark/summa/input/tollgate/interpGrid/'
grid_name = grid_path + 'stn2grid_tollgate_monthly.nc'

; open netcdf file for reading
file_id = ncdf_open(grid_name, /nowrite)

 ; read the x coordinate
 ivarid = ncdf_varid(file_id,'x')
 ncdf_varget, file_id, ivarid, xGrid

 ; read the y coordinate
 ivarid = ncdf_varid(file_id,'y')
 ncdf_varget, file_id, ivarid, yGrid

 ; read the mask
 ivarid = ncdf_varid(file_id,'mask')
 ncdf_varget, file_id, ivarid, mask

 ; read in the time vector
 ivarid = ncdf_varid(file_id,'time')
 ncdf_varget, file_id, ivarid, gridTime
 ncdf_attget, file_id, ivarid, 'units', bunits
 cTimeUnits = string(bunits)

; close the file
ncdf_close, file_id

; get the base julian day
tunit_words  = strsplit(string(cTimeUnits),' ',/extract)
tunit_idate  = fix(strsplit(tunit_words[2],'-',/extract))
tunit_ihour  = fix(strsplit(tunit_words[3],':',/extract))
bjulian      = julday(tunit_idate[1],tunit_idate[2],tunit_idate[0],tunit_ihour[0],tunit_ihour[1],tunit_ihour[2])

; convert the time to julian days
if(strtrim(tunit_words[0],2) eq 'seconds') then aoff=1.d/86400.d else stop, 'unknown time units'  ; get offset in days
djulian_grid = bjulian + gridTime*aoff

; compute the year/month/day
caldat, djulian_grid, gridMonth, gridDay, gridYear, gridHour
ntime_grid = n_elements(djulian_grid)

; get the number of x and y points
nx = n_elements(xGrid)
ny = n_elements(yGrid)

; get the x-limits
xmin = min(xGrid)
xmax = max(xGrid)

; get the y-limits
ymin = min(yGrid)
ymax = max(yGrid)

; *****
; * GET THE STATION METADATA... 
; *****************************

; define filename
stn_path = '/home/mclark/summa/input/tollgate/stationData/netcdf_data/'
stn_name = stn_path + 'tollgate_forcing_monthly.nc'

; open the NetCDF file
nc_file = ncdf_open(stn_name, /nowrite)

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
 ncdf_varget, nc_file, ivar_id, xStation

 ; read in the station y-coordinate
 ivar_id = ncdf_varid(nc_file,'LCC_y')
 ncdf_varget, nc_file, ivar_id, yStation

 ; read in the time vector
 ivar_id = ncdf_varid(nc_file,'time')
 ncdf_varget, nc_file, ivar_id, stnTime
 ncdf_attget, nc_file, ivar_id, 'units', bunits
 cTimeUnits = string(bunits)

; close the NetCDF file
ncdf_close, nc_file

; get the base julian day
tunit_words  = strsplit(string(cTimeUnits),' ',/extract)
tunit_idate  = fix(strsplit(tunit_words[2],'-',/extract))
tunit_ihour  = fix(strsplit(tunit_words[3],':',/extract))
bjulian      = julday(tunit_idate[1],tunit_idate[2],tunit_idate[0],tunit_ihour[0],tunit_ihour[1],tunit_ihour[2])

; convert the time to julian days
if(strtrim(tunit_words[0],2) eq 'seconds') then aoff=1.d/86400.d else stop, 'unknown time units'  ; get offset in days
djulian_stn = bjulian + stnTime*aoff

; compute the year/month/day
caldat, djulian_stn, stnMonth, stnDay, stnYear, stnHour
ntime_stn = n_elements(djulian_stn)

; *****
; * PLOT STATION DATA AND THE CLOSEST GRIDPOINT...
; ************************************************

; get the number of stations
nStations = n_elements(cName)

; loop through stations
for iStation=0,nStations-1 do begin

 ; skip everything apart from the quonset
 ;if(cKey[iStation] ne 'rc-076')then continue

 xMaxd = 1.d+12
 ; identify the closest gridpoint
 for ix=0,nx-1 do begin
  for jy=0,ny-1 do begin
   if(mask[ix,jy] eq 1)then begin
    xDist = sqrt( (xGrid[ix] - xStation[iStation])^2.d + (yGrid[jy] - yStation[iStation])^2.d )
    if(xDist le xMaxd)then begin
     ixClose = ix
     jyClose = jy
     xMaxd = xDist
    endif
   endif  ; if gridpoint is valid
  endfor ; looping through y
 endfor ; looping through x
 print, iStation, cKey[iStation], cName[iStation], ixClose, jyClose, xMaxd, format='(i2,1x,a10,1x,a40,1x,2(i3,1x),f9.3)'

 ; loop through variables
 for ivar=0,n_elements(varnames_stn)-1 do begin

  ; make a base plot
  icolor_grid  = 250
  icolor_basin = 0
  x0 = -0.1*(xmax-xmin)+xmin
  x1 =  1.8*(xmax-xmin)+xmin
  y0 =  0.0*(ymax-ymin)+ymin
  y1 =  1.6*(ymax-ymin)+ymin
  plot, indgen(5), xrange=[x0,x1], yrange=[y0,y1], xstyle=5, ystyle=5, $
   xmargin=[0,0], ymargin=[0,0], /nodata
  plot_grid, mask, nx, ny, icolor_grid  ; plot grid
  plot_basins, icolor_basin ; plot basin outlines

  ; plot the closest gridpoint
  plots, xGrid[ixClose], yGrid[jyClose], psym=sym(6), color=80

  ; plot the station
  plots, xStation[iStation], yStation[iStation], psym=sym(1), symsize=2
  xyouts, xStation[iStation]+500., yStation[iStation]-500., cName[iStation]

  ; read in station data
  nc_file = ncdf_open(stn_name, /nowrite)
   ivarid = ncdf_varid(nc_file,varnames_stn[ivar])
   ncdf_varget, nc_file, ivarid, stnData, offset=[iStation,0], count=[1,ntime_stn]
  ncdf_close, nc_file

  ; read in the interpolated data from the closest point
  nc_file = ncdf_open(grid_name, /nowrite)
   ivarid = ncdf_varid(nc_file,varnames_grid[ivar]+'_hourly')
   ncdf_varget, nc_file, ivarid, gridData, offset=[ixClose,jyClose,0], count=[1,1,ntime_grid]
  ncdf_close, nc_file

  ; loop through years
  for iYear=1990,2008 do begin

   ; identify the station data
   iValid = where(stnYear eq iYear, nValid)
   if(nValid gt 0)then begin

    ; define plot range
    i_beg = iValid[0]
    i_end = iValid[nValid-1]

    ; make a base plot
    plot, djulian_stn[i_beg:i_end], xrange=[djulian_stn[i_beg],djulian_stn[i_end]], yrange=[vmin[ivar],vmax[ivar]], xstyle=1, ystyle=1, $
     xtickformat=['label_date'], xticks=6, ytitle=varnames_stn[ivar]+' ('+strtrim(iYear,2)+')', /nodata

    ; identify the data from the closest gridpoint
    jValid = where(gridYear eq iYear, nValid)
    if(nValid gt 0)then begin

     ; get data subset
     if(varnames_stn[ivar] eq 'ppta')then begin
      aData = gridData[0,0,jValid]
      xData = dblarr(nValid)
      xData[0] = aData[0]
      for i=1,nValid-1 do xData[i] = xData[i-1] + aData[i]
     endif else begin
      xData = gridData[0,0,jValid]
     endelse

     ; plot gridded data
     if(varnames_stn[ivar] eq 'ppta'  )then oplot, djulian_grid[jValid], xData*3600.d, color=80
     if(varnames_stn[ivar] eq 'tmp3'  )then oplot, djulian_grid[jValid], xData - 273.16d, color=80
     if(varnames_stn[ivar] eq 'dpt3'  )then oplot, djulian_grid[jValid], xData - 273.16d, color=80
     if(varnames_stn[ivar] eq 'sol'   )then oplot, djulian_grid[jValid], xData, color=80
     if(varnames_stn[ivar] eq 'wnd3sa')then oplot, djulian_grid[jValid], xData, color=80

    endif 

    ; get data subset
    if(varnames_stn[ivar] eq 'ppta')then begin
     aData = stnData[0,iValid]
     xData = dblarr(nValid)
     xData[0] = aData[0]
     for i=1,nValid-1 do xData[i] = xData[i-1] + aData[i]
    endif else begin
     xData = stnData[0,iValid]
    endelse

    ; plot station data
    oplot, djulian_stn[iValid], xData, color=250, min_value= -999.


   endif   ; if there is valid station data
  endfor  ; looping through years

  ; write the figure
  write_png, 'stationTimeseries/'+varnames_stn[ivar]+'/'+varnames_stn[ivar]+'_'+cKey[istation]+'.png', tvrd(true=1)

 endfor  ; looping through variables

endfor  ; looping through stations






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




