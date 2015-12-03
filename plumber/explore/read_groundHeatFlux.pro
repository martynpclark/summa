pro read_groundHeatFlux

; define the HRU
iHRU=0

; define file paths
filePath_root = '/home/mclark/summa/output/plumber/'
filePath_orig = filePath_root + 'orig/'
filePath_temp = filePath_root + 'temp/'

; define file name
fileName = 'Bugac_spinup_initialPlumberTest.nc'

; open files
ncFileID_orig = ncdf_open(filePath_orig+fileName, /nowrite)
ncFileID_temp = ncdf_open(filePath_temp+fileName, /nowrite)

 ; get time units
 ivar_id = ncdf_varid(ncFileID_orig,'time')
 ncdf_attget, ncFileID_orig, ivar_id, 'units', bunits
 cunits = string(bunits)

 ; extract the units "words"
 tunit_words = strsplit(string(cunits),' ',/extract)
 tunit_idate = fix(strsplit(tunit_words[2],'-',/extract))
 tunit_ihour = fix(strsplit(tunit_words[3],':',/extract))
 bjulian     = julday(tunit_idate[1],tunit_idate[2],tunit_idate[0],tunit_ihour[0],tunit_ihour[1],tunit_ihour[2])

 ; get the offset in days
 if(strtrim(tunit_words[0],2) eq 'seconds') then aoff=1.d/86400.d else stop, 'unknown time units'

 ; extract the time vector
 ncdf_varget, ncFileID_orig, ivar_id, atime
 djulian_mod = bjulian + atime*aoff

 ; get the number of time elements
 ntime_mod = n_elements(djulian_mod)-1

 ; get the number of layers
 ivar_id = ncdf_varid(ncFileID_orig,'nLayers')
 ncdf_varget, ncFileID_orig, ivar_id, nLayers, offset=[iHRU,0], count=[1,ntime_mod]

 ; get the start index for ifcToto
 ivar_id = ncdf_varid(ncFileID_orig,'ifcTotoStartIndex')
 ncdf_varget, ncFileID_orig, ivar_id, ifcTotoStartIndex, offset=[iHRU,0], count=[1,ntime_mod]

 ; get the ground heat flux
 ; NOTE: from the temp file
 ivar_id = ncdf_varid(ncFileID_temp,'Qg')
 ncdf_varget, ncFileID_temp, ivar_id, Qg, offset=[iHRU,0], count=[1,ntime_mod]

 ; get the ground heat flux
 for iTime=0,nTime_mod-1 do begin

  ; get the vector of measurment height
  ivar_id = ncdf_varid(ncFileID_orig,'iLayerHeight')
  ncdf_varget, ncFileID_orig, ivar_id, xHeight, offset=[iHRU,ifcTotoStartIndex[iTime]-1], count=[1,nLayers[iTime]+1]

  ; get the vector of the heat flux
  ivar_id = ncdf_varid(ncFileID_orig,'iLayerNrgFlux')
  ncdf_varget, ncFileID_orig, ivar_id, xFlux, offset=[iHRU,ifcTotoStartIndex[iTime]-1], count=[1,nLayers[iTime]+1]

  ; print progress
  ;print, itime, ifcTotoStartIndex[iTime], xHeight[iHRU,*], format='(2(i6,1x),20(f13.5,1x))'
  print, itime, ifcTotoStartIndex[iTime], Qg[iHRU,itime], xFlux[iHRU,*], format='(2(i6,1x),20(f13.5,1x))'

 endfor  ; looping through time

; close the netcdf file
ncdf_close, ncFileID_orig
ncdf_close, ncFileID_temp



end
