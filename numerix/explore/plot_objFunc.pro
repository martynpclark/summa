pro plot_objFunc

; define plotting parameters
window, 0, xs=2400, ys=1200, retain=2
device, decomposed=0
LOADCT, 39
!P.BACKGROUND=255
!P.CHARSIZE=2.5
!P.COLOR=0
erase, color=255
!P.MULTI=[0,4,2,0,1]

; define nx and ny
nx=101L
ny=101L

; define number of grids
nGrids = nx*ny

; define the arrays
fDat = fltarr(4,nGrids)
xState = fltarr(2)
xInc   = fltarr(2)

; define path
fPath = '/home/mclark/summa/bin/'

; loop through iterations
for iter=1,1 do begin

 ; get the filename
 fName = fPath + 'grid.objFunc' + strtrim(string(iter,format='(i3.3)'),2) + '.txt'
 print, fName

 ; read in the data
 openr, in_unit, fName, /get_lun
  readf, in_unit, fDat
  readf, in_unit, xState
  readf, in_unit, xInc
 free_lun, in_unit

 ; format the data
 xx = reform(fDat[0,*],nx,ny)
 yy = reform(fDat[1,*],nx,ny)
 fx = reform(fDat[2,*],nx,ny)
 fm = reform(fDat[3,*],nx,ny)

 ;  make a base plot
 plot, xx, yy, xrange=[min(xx),max(xx)], yrange=[min(yy),max(yy)], xstyle=1, ystyle=1, /nodata

 ; get the plot limits
 fMax = max(fx)
 fMin = min(fx)
 fRng = fMax-fMin

 ; make a contour plot
 nLevels = 50
 cLevels = fMin + fRng*dindgen(nLevels+1)/double(nLevels)
 cColors = reverse(indgen(nLevels)*5)
 contour, fx, xx, yy, levels=cLevels, c_colors=cColors, /overplot
 stop

endfor


stop
end
