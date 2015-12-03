pro plot_groundHeatFlux

; define plotting parameters
window, 0, xs=2000, ys=1400, retain=2
device, decomposed=0
LOADCT, 39
!P.BACKGROUND=255
!P.CHARSIZE=2
!P.COLOR=0
erase, color=255
!P.MULTI=[0,2,2,0,1]

; define the HRU
iHRU=0

; define file paths
file_path = '/home/mclark/summa/output/plumber/'

; define file name
file_name = 'SUMMA.1.0_BugacFluxnet.1.4.nc'

; *****
; * READ THE GROUND HEAT FLUX...
; ******************************

; open files
ncFileID = ncdf_open(file_path+file_name, /nowrite)

 ; get time units
 ivar_id = ncdf_varid(ncFileID,'time')
 ncdf_attget, ncFileID, ivar_id, 'units', bunits
 cunits = string(bunits)

 ; extract the units "words"
 tunit_words = strsplit(string(cunits),' ',/extract)
 tunit_idate = fix(strsplit(tunit_words[2],'-',/extract))
 tunit_ihour = fix(strsplit(tunit_words[3],':',/extract))
 bjulian     = julday(tunit_idate[1],tunit_idate[2],tunit_idate[0],tunit_ihour[0],tunit_ihour[1],tunit_ihour[2])

 ; get the offset in days
 if(strtrim(tunit_words[0],2) eq 'seconds') then aoff=1.d/86400.d else stop, 'unknown time units'

 ; extract the time vector
 ncdf_varget, ncFileID, ivar_id, atime
 djulian_mod = bjulian + atime*aoff

 ; get the number of time elements
 ntime_mod = n_elements(djulian_mod)-1

 ; get the ground heat flux
 ivar_id = ncdf_varid(ncFileID,'Qg')
 ncdf_varget, ncFileID, ivar_id, Qg, offset=[iHRU,0], count=[1,ntime_mod]

; close the netcdf file
ncdf_close, ncFileID

; *****
; * PLOT THE DIURNAL CYCLE IN THE GROUND HEAT FLUX...
; ***************************************************

; get the time
caldat, djulian_mod, im, id, iyyy, ih, imin

; get observation times
obsTime = ceil(ih*100+imin*1.66666666d)

; get the xticks
xticks = [' ',[strtrim(indgen(7)*3+3,2)],' ']

; define yrange
ymin = -100
ymax =  200

; define the years
iyStart=2003
iyEnd=2006

; loop through years
for iYear=iyStart,iyEnd do begin

 ; make the base plot
 plot, indgen(24)+1, xrange=[0,24], yrange=[ymin,ymax], xstyle=9, ystyle=1, $
   xmargin = [15,2], xticks=8, xtickname=xticks, ytitle='heat flux', $
   xcharsize=1.5, ycharsize=1.5, xticklen=(-0.02), title=strtrim(iYear,2), $
   /nodata
 plots, [0,24], [0,0]
 plots, [0,24], [ymax,ymax]

 ; get time of the day
 xtime = dindgen(48)/2.d + 0.25d

 ; get arrays for the mean diurnal cycle
 summaQg  = fltarr(49)

 ; compute the mean diurnal cycle
 for jhour=0,47 do begin
  imatch = where(obsTime eq jhour*50 and iyyy eq iYear, nmatch)
  summaQg[jhour] =  total(Qg[imatch])/float(nmatch)
 endfor  ; (looping through hours)
 summaQg[48] = summaQg[0]

 ; plot
 oplot, xtime, summaQg,  color=250, thick=4

endfor

stop
end
