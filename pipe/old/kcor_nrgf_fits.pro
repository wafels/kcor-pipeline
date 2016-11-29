pro kcor_nrgf_fits, fits_file, fits=fits

;+
;-------------------------------------------------------------------------------
; NAME:
;   kcor_nrgf
;
; PURPOSE:
;   Apply nrgf filter to kcor a image.
;
; INPUTS:
;   fits_file:	kcor L1 fits file
;
; OUTPUTS:
;   gif file
;   fits file (optional)
;
; AUTHOR:
;   Andrew L. Stanger   HAO/NCAR
;   14 Apr 2015
;   29 May 2015 Mask image with black in occulter & with R > 504 pixels.
;   17 Jun 2015 Add option to create an NRGF FITS file.
;   15 Jul 2015 Add /NOSCALE keyword to readfits.
;-------------------------------------------------------------------------------
;-

img = readfits (fits_file, hdu, /NOSCALE, /SILENT)

xdim       = sxpar (hdu, 'NAXIS1')
ydim       = sxpar (hdu, 'NAXIS2')
xcen       = xdim / 2.0 - 0.5
ycen       = ydim / 2.0 - 0.5
date_obs   = sxpar (hdu, 'DATE-OBS')	; yyyy-mm-ddThh:mm:ss
platescale = sxpar (hdu, 'CDELT1')	; arcsec/pixel
rsun       = sxpar (hdu, 'RSUN')	; radius of photosphere [arcsec].

;--- Extract date and time from FITS header.

year   = strmid (date_obs, 0, 4)
month  = strmid (date_obs, 5, 2)
day    = strmid (date_obs, 8, 2)
hour   = strmid (date_obs, 11, 2)
minute = strmid (date_obs, 14, 2)
second = strmid (date_obs, 17, 2)

odate   = strmid (date_obs, 0, 10)	; yyyy-mm-dd
otime   = strmid (date_obs, 11, 8)	; hh:mm:ss

;--- Convert month from integer to name of month.

IF (month EQ '01') THEN name_month = 'Jan'
IF (month EQ '02') THEN name_month = 'Feb'
IF (month EQ '03') THEN name_month = 'Mar'
IF (month EQ '04') THEN name_month = 'Apr'
IF (month EQ '05') THEN name_month = 'May'
IF (month EQ '06') THEN name_month = 'Jun'
IF (month EQ '07') THEN name_month = 'Jul'
IF (month EQ '08') THEN name_month = 'Aug'
IF (month EQ '09') THEN name_month = 'Sep'
IF (month EQ '10') THEN name_month = 'Oct'
IF (month EQ '11') THEN name_month = 'Nov'
IF (month EQ '12') THEN name_month = 'Dec'

;--- Determine DOY.

mday      = [0,31,59,90,120,151,181,212,243,273,304,334]
mday_leap = [0,31,60,91,121,152,182,213,244,274,305,335] ;leap year

IF ((fix(year) mod 4) EQ 0) THEN $
   doy = (mday_leap(fix(month)-1) + fix(day))$
ELSE $
   doy = (mday (fix (month) - 1) + fix (day))

; ----------------------
; Find size of occulter.
; ----------------------
; One occulter has 4 digits; Other two have 5.
; Only read in 4 digits to avoid confusion.

occulter_id = ''
occulter_id = sxpar (hdu, 'OCCLTRID')
occulter    = strmid (occulter_id, 3, 5)
occulter    = float (occulter)
IF (occulter eq 1018.0) THEN occulter = 1018.9
IF (occulter eq 1006.0) THEN occulter = 1006.9

radius_guess = 178
img_info = kcor_find_image (img, radius_guess)
xc   = img_info (0)
yc   = img_info (1)
r    = img_info (2)

rocc    = occulter / platescale		; occulter radius [pixels].
r_photo = rsun / platescale		; photosphere radius [pixels]
r0 = rocc + 2				; add 2 pixels for inner FOV.
;r0   = (rsun * 1.05) / platescale

cneg = FIX (ycen - r_photo)
cpos = FIX (ycen + r_photo)

print, 'rsun [arcsec]:     ', rsun 
print, 'occulter [arcsec]: ', occulter
print, 'r_photo [pixels]:  ', r_photo
print, 'rocc [pixels]:     ', rocc
print, 'r0:                ', r0

;--- Compute normalized, radially-graded filter.

for_nrgf, img, xcen, ycen, r0, imgflt

imin = min (imgflt)
imax = max (imgflt)
cmin = imin / 2.0 
cmax = imax / 2.0
cmin = imin
cmax = imax

if (imin LT 0.0) then $
begin ;{
   amin = abs (imin)
   amax = abs (imax)
   if (amax GT amin) then max = amax else max = amin
end   ;}

print, 'imin/imax: ', imin, imax
;print, 'cmin/cmax: ', cmin, cmax

;--------------------
; Appl mask to image.
;--------------------

;--- Set image dimensions.

xx1   = findgen (xdim, ydim) mod (xdim) - xcen
yy1   = transpose (findgen (ydim, xdim) mod (ydim)) - ycen
xx1   = double (xx1)
yy1   = double (yy1)
rad1  = sqrt (xx1 * xx1 + yy1 * yy1)	; radial distance from center [pixels]

r_in  = fix (occulter / platescale) + 5.0
r_in  = fix (occulter / platescale)
r_out = 504.0

print, 'r_in: ', r_in, ' r_out: ', r_out

mask = where (rad1 LT r_in OR rad1 GE r_out)
imgflt (mask) = -10.0

;-------------------------------------------------------------------------------
; Write NRGF image to a FITS file.
;-------------------------------------------------------------------------------

if (keyword_set (fits)) then $
BEGIN ;{
  imgint = FIX (imgflt * 1000.0)   ; Convert to short integer (16 bits/pixel).

  bscale  =  0.001
  dispmin = -2.0
  dispmax =  4.0
  dispexp =  1.0
  bunit   = 'nrgf'

  rhdu = hdu
  sxaddpar, rhdu, 'DATATYPE', 'NRGF', $
                  ' Normalized Radially-Graded Filter applied'
  sxaddpar, rhdu, 'LEVEL', 'L1-NRGF', $
                  ' Level 1 normalized radially-graded filter'
  sxaddpar, rhdu, 'BSCALE', bscale, $
                  ' physical = data * BSCALE + BZERO', format = '(f8.3)'
  sxaddpar, rhdu, 'BUNIT', bunit, $
                  ' Normalized Radially Graded Filter values'
  sxaddpar, rhdu, 'DISPMIN', dispmin, ' minimum value for display', $
                  AFTER='BSCALE',  format = '(f9.3)'
  sxaddpar, rhdu, 'DISPMAX', dispmax, ' maximum value for display', $
                  AFTER='DISPMIN', format = '(f9.3)'
  sxaddpar, rhdu, 'DISPEXP', dispexp, $
                  ' bytscl (img^dispexp, min=dispmin, max=dispmax', $
                  AFTER='DISPMAX', format = '(f9.3)'

  fts_loc = strpos (fits_file, '.fts')
  fits_base = strmid (fits_file, 0, fts_loc)
  nrgf_fits = fits_base + '_nrgf.fts'
  print, 'nrgf_fits: ', nrgf_fits
  print, 'min/max (imgint): ', minmax (imgint)

  writefits, nrgf_fits, imgint, rhdu
END   ;}

;-------------------------------------------------------------------------------
; Write NRGF image to a GIF file.
;-------------------------------------------------------------------------------
;--- Select graphics device.

set_plot, 'Z'
device, set_resolution = [xdim, ydim], $
        decomposed=0, set_colors=256, z_buffering=0
erase

;device, decomposed = 1
;window, xsize = xdim, ysize = xdim, retain = 2

;------------------
; Load color table.
;------------------

lct,   '/hao/acos/sw/colortable/quallab.lut'    ; color table.
tvlct, red, green, blue, /get

;----------------------------
; Display image and annotate.
;----------------------------

tv, bytscl (imgflt, cmin, cmax)

xyouts, 4, 990, 'MLSO/HAO/KCOR', color = 251, charsize = 1.5, /device
xyouts, 4, 970, 'K-Coronagraph', color = 254, charsize = 2.0, font=1, /device
;xyouts, 512, 1000, 'North', color = 253, charsize = 1.2, alignment = 0.5, $
;	            /device
;xyouts, 506, 1000,    'N', color = 254, charsize = 1.5, /device
xyouts, 505, cpos-24, 'N', color = 254, charsize = 1.5, /device
xyouts, 1018, 995, string (format = '(a2)', day) + ' ' + $
                   string (format = '(a3)', name_month) +  ' ' + $
                   string (format = '(a4)', year), /device, alignment = 1.0, $
                   charsize = 1.2, color = 251
xyouts, 1010, 975, 'DOY ' + string (format = '(i3)', doy), /device, $
                   alignment = 1.0, charsize = 1.2, color = 251
xyouts, 1018, 955, string (format = '(a2)', hour) + ':' + $
                   string (format = '(a2)', minute) + ':' + $
	           string(format = '(a2)', second) + ' UT', /device, $
                   alignment = 1.0, charsize = 1.2, color = 251
;xyouts, 22, 512, 'East', color = 254, charsize = 1.2, alignment = 0.5, $
;                 orientation = 90., /device
;xyouts, 10,      505, 'E', color = 254, charsize = 1.5, /device 
xyouts, cneg+12, 505, 'E', color = 254, charsize = 1.5, /device 
;xyouts, 1012, 512, 'West', color = 254, charsize = 1.2, alignment = 0.5, $
;                   orientation = 90., /device
;xyouts, 998,     505, 'W', color = 254, charsize = 1.5, /device 
xyouts, cpos-24, 505, 'W', color = 254, charsize = 1.5, /device 
;xyouts, 512, 12, 'South', color = 254, charsize = 1.2, alignment = 0.5, $
;	            /device
;xyouts, 505, 12,      'S', color = 254, charsize = 1.5, /device 
xyouts, 505, cneg+12, 'S', color = 254, charsize = 1.5, /device 
xyouts, 4, 46, 'Level 1 data', color = 251, charsize = 1.2, /device
xyouts, 4, 26, 'min/max: ' + string (format = '(f8.1)', cmin) + ', ' $
                           + string (format = '(f8.1)', cmax), $
	       color = 251, charsize = 1.2, /device
;xyouts, 4, 6, 'scaling: Intensity ^ ' + string (format = '(f3.1)', exp), $
;              color = 251, charsize = 1.2, /device
xyouts, 4, 6, 'Intensity: normalized, radial-graded filter', $
              color = 251, charsize = 1.2, /device
xyouts, 1018, 6, 'circle = photosphere', $
                 color = 251, charsize = 1.2, /device, alignment = 1.0

;--- Image has been shifted to center of array.
;--- Draw circle at photosphere.

;tvcircle, r_photo, 511.5, 511.5, color = 251, /device

;----------------------------------
; Draw polar grid in occulter area.
;----------------------------------

suncir_kcor, xdim, ydim, xcen, ycen, 0, 0, r_photo, 0.0

save     = tvrd ()
fts_loc = strpos (fits_file, '.fts')
gif_file = strmid (fits_file, 0, fts_loc) + '_nrgf.gif'

print, 'gif_file: ', gif_file

;-----------------
; Create GIF file.
;-----------------

write_gif, gif_file, save, red, green, blue

end