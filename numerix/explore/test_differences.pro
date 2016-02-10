pro test_differences

; define plotting parameters
window, 1, xs=2000, ys=1400, retain=2
device, decomposed=0
LOADCT, 39
!P.BACKGROUND=255
!P.CHARSIZE=2.5
!P.COLOR=0
erase, color=255
!P.MULTI=[0,3,3,0,0]

; define root directory
summa_root = '/home/mclark/check/summaTestCases/'

; define branches
branches = ['output_develop_upstream/', $
            'output_feature_improveConv/']

; define experiment
;experiment = 'wrrPaperTestCases/figure01/vegImpactsRad_2005-2006_riparianAspenBeersLaw.nc'
;experiment = 'wrrPaperTestCases/figure06/albedoTest_spinup_senatorConstantDecayRate.nc'
experiment = 'wrrPaperTestCases/figure01/vegImpactsRad_2007-2008_riparianAspenVegParamPerturb.nc'

; defile files
filenames = summa_root + branches + experiment

; define variables
varnames = [$
            'scalarCanopyTemp', $
            'scalarCanopyLiq', $
            'scalarCanopyIce', $
            'scalarSWE', $
            'scalarCanopyAbsorbedSolar', $
            'scalarGroundAbsorbedSolar', $
            'scalarSenHeatTotal', $
            'scalarLatHeatTotal', $
            'scalarSurfaceTemp']

; define the HRU index
iHRU=0

; loop through variables
for ivar=0,n_elements(varnames)-1 do begin

 ; loop through files
 for ifile=0,n_elements(filenames)-1 do begin

  ; open file
  nc_file = ncdf_open(filenames[ifile], /nowrite)

   ; get time units
   ivar_id = ncdf_varid(nc_file,'time')
   ncdf_attget, nc_file, ivar_id, 'units', bunits
   cunits = string(bunits)

   ; extract the units "words"
   tunit_words = strsplit(string(cunits),' ',/extract)
   tunit_idate = fix(strsplit(tunit_words[2],'-',/extract))
   tunit_ihour = fix(strsplit(tunit_words[3],':',/extract))
   bjulian     = julday(tunit_idate[1],tunit_idate[2],tunit_idate[0],tunit_ihour[0],tunit_ihour[1],tunit_ihour[2])

   ; get the offset in days
   if(strtrim(tunit_words[0],2) eq 'seconds') then aoff=1.d/86400.d else stop, 'unknown time units'

   ; extract the time vector
   ncdf_varget, nc_file, ivar_id, atime
   djulian = bjulian + atime*aoff

   ; define the date format
   dummy = label_date(date_format=['%D-%M!C%H'])

   ; get the number of time elements
   ntime = n_elements(djulian)

   ; get the desired variable
   ivar_id = ncdf_varid(nc_file,varnames[ivar])
   ncdf_varget, nc_file, ivar_id, varData, offset=[iHRU,0], count=[1,ntime]

   ; save data
   if(ifile eq 0)then varData01 = reform(varData)
   if(ifile eq 1)then varData02 = reform(varData)

  ; close the netcdf file
  ncdf_close, nc_file

 endfor  ; looping through files

 ; define position of maximum absolute difference
 if(ivar eq 0)then xMax = max(abs(varData01 - varData02), iMax)

 ; define plot range
 ixOff = 24*2
 i_beg = max([0, iMax-ixOff])
 i_end = min([iMax+ixOff, ntime-1])
 ;i_beg = 0
 ;i_end = ntime-1

 ; make a base plot
 plot, djulian[i_beg:i_end], xrange=[djulian[i_beg],djulian[i_end]], yrange=[min(varData01[i_beg:i_end]),max(varData01[i_beg:i_end])], xstyle=1, ystyle=1, $
  xtickformat=['label_date'], xticks=10, ytitle = varnames(ivar), xmargin=[10,2], /nodata

 ; plot lines
 oplot, djulian[i_beg:i_end], varData01[i_beg:i_end], color=80
 oplot, djulian[i_beg:i_end], varData02[i_beg:i_end], color=250

 ; plot symbols
 ;oplot, djulian[i_beg:i_end], varData01[i_beg:i_end], color=80, psym=sym(6)
 ;oplot, djulian[i_beg:i_end], varData02[i_beg:i_end], color=250, psym=sym(6)

endfor  ; looping through variables

stop
end
