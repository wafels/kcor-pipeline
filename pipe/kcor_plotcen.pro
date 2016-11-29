;+
; :Name: kcor_plotcen.pro
;-------------------------------------------------------------------------------
; :Uses: plot occulting centers.
;-------------------------------------------------------------------------------
; :Author: Andrew L. Stanger   HAO/NCAR   22 Jun 2015
;
; :History:
; 26 Jun 2015 Plot time in hours:minutes instead of hours (decimal).
; 03 Dec 2015 Add 'eng' quality type for file summary.
; 26 Jan 2016 Color tables are in /hao/acos/sw/idl/color.
;-------------------------------------------------------------------------------
; :Params:
;   date [format: 'yyyymmdd']
;
; :Keywords:
;   list [format: 'list']
;   append	if set, append log information to existing log file.
;   gif		if set, produce raw GIF images.
;   base_dir 	Directory where date sub-directory is located.
;-------------------------------------------------------------------------------
;-

PRO kcor_plotcen, date, list=list, append=append, base_dir=base_dir

;--- Store initial system time.

TIC

;--- Default keywords.

default, base_dir, '/hao/mlsodata1/Data/KCor/raw'

;--- Establish list of files to process.

np = n_params ()
;PRINT, 'np: ', np

IF (np EQ 0) THEN $
BEGIN ;{
   PRINT, "kcor_plotcen, 'yyyymmdd', list='list'"
   RETURN
END   ;}

IF (KEYWORD_SET (list)) THEN $
BEGIN ;{
   listfile = list
END  $ ;}
ELSE $
BEGIN  ;{
   listfile = 'list.q'
   spawn, 'ls *kcor.fts* > list.q'
END   ;}

;----------------
; Date for plots.
;----------------

pyear  = strmid (date, 0, 4)
pmonth = strmid (date, 4, 2)
pday   = strmid (date, 6, 2)
pdate  = string (format='(a4)', pyear)   + '-' $
       + string (format='(a2)', pmonth)  + '-' $
       + string (format='(a2)', pday)

;-----------------------------------------
; Define directory names.
;-----------------------------------------

log_file  = date + '_plotcen_' + listfile + '.log'

date_dir   = base_dir + '/' + date	; L0 fits files.
date_path  = date_dir + '/'
p_dir      = date_dir + '/p/'

l0_dir     = date_dir + '/level0'

q_cal = 'cal'
q_eng = 'eng'
q_sci = 'sci'
q_dev = 'dev'

ncal = 0
neng = 0
nsci = 0
ndev = 0

;-----------------------------------------
; Check for existence of Level0 directory.
;-----------------------------------------

IF (NOT FILE_TEST (l0_dir, /DIRECTORY)) THEN $
BEGIN ;{
   PRINT, l0_dir, ' does not exist.  No files to process.'
   GOTO, DONE
END   ;{

;-----------------------------------
; Create p sub-directory, if needed.
;-----------------------------------

IF (NOT FILE_TEST (p_dir, /DIRECTORY)) THEN FILE_MKDIR, p_dir

;------------------------
; Move to 'L0' directory.
;------------------------

CD, current=start_dir			; Save current directory.
CD, l0_dir				; Move to date directory.

doview = 0

;---------------
; Open log file.
;---------------

OPENW, ULOG, log_file, /GET_LUN			; Open new log file for writing.

;--- Print information.

PRINT, "kcor_plotcen, '", date, "', list='", list, "'"
;PRINT, 'start_dir:    ', start_dir
PRINT, 'base_dir:     ', base_dir
PRINT, 'l0_dir:       ', l0_dir
PRINT, 'p_dir:        ', p_dir
PRINT, 'log_file:     ', log_file

PRINTF, ULOG, "kcor_plotcen, '", date, "', list='", list, "'"
;PRINTF, ULOG, 'start_dir:    ', start_dir
PRINTF, ULOG, 'base_dir:     ', base_dir
PRINTF, ULOG, 'l0_dir:       ', l0_dir
PRINTF, ULOG, 'p_dir:        ', p_dir
PRINTF, ULOG, 'log_file:     ', log_file

;-------------------------------------------------------------------------------
; Set up graphics window & color table.
;-------------------------------------------------------------------------------

set_plot, 'z'
; window, 0, xs=1024, ys=1024, retain=2

device, set_resolution=[1024,1024], decomposed=0, set_colors=256, $
        z_buffering=0

;lct,'/hao/acos/sw/idl/color/quallab_ver2.lut' ; color table.
;lct,'/hao/acos/sw/idl/color/art.lut' ; color table.
;lct,'/hao/acos/sw/idl/color/bwyvid.lut' ; color table.
;lct,'/hao/acos/sw/idl/color/artvid.lut' ; color table.

lct,'/hao/acos/sw/id/color/bwy5.lut' ; color table.

tvlct, rlut, glut, blut, /get

;-------------------------------------------------------------------------------
; Define color levels for annotation.
;-------------------------------------------------------------------------------

yellow = 250 
grey   = 251
blue   = 252
green  = 253
red    = 254
white  = 255

;-------------------------------------------------------------------------------
; Open file containing a list of kcor L0 FITS files.
;-------------------------------------------------------------------------------

PRINT,        'listfile: ', listfile
PRINTF, ULOG, 'listfile: ', listfile

GET_LUN, ULIST
CLOSE,   ULIST
OPENR,   ULIST, listfile
l0_file = ''
i = -1

cal = 0
eng = 0
sci = 0
dev = 0

;------------------------------------------
; Determine the number of files to process.
;------------------------------------------

nimg = FILE_LINES (listfile)

PRINT,        'nimg: ', nimg
PRINTF, ULOG, 'nimg: ', nimg

PRINT,        $
   'file name                datatype    exp  cov drk  dif pol angle  qual'
PRINTF, ULOG, $
   'file name                datatype    exp  cov drk  dif pol angle  qual'

;---------------------------------------
; Declare storage for occulting centers.
;---------------------------------------

hours = fltarr (nimg)

fxcen0 = fltarr (nimg)
fycen0 = fltarr (nimg)
frocc0 = fltarr (nimg)

fxcen1 = fltarr (nimg)
fycen1 = fltarr (nimg)
frocc1 = fltarr (nimg)

;-------------------------------------------------------------------------------
; Image file loop.
;-------------------------------------------------------------------------------

WHILE (NOT EOF (ULIST)) DO $
BEGIN ;{
   i += 1
   READF, ULIST, l0_file
   img = readfits (l0_file, hdu, /SILENT)	; Read FITS image & header.

   fitsloc  = STRPOS (l0_file, '.fts')
   gzloc    = STRPOS (l0_file, '.gz')
   img_file = l0_file
   if (gzloc GE 0) then $
      img_file = STRMID (l0_file, gzloc)

   img0 = reform (img (*, *, 0, 0))
;   img0 = reverse (img0, 2)			; y-axis inversion
   img1 = reform (img (*, *, 0, 1))

   ;--- Get FITS header size.

;   finfo = FILE_INFO (l0_file)			; Get file information.
;   hdusize = SIZE (hdu)

   cal  = 0
   eng  = 0
   sci  = 0
   dev  = 0
   diff = 0
   calp = 0
   drks = 0
   cov  = 0

   ;---------------------------------------------
   ; Extract keyword parameters from FITS header.
   ;---------------------------------------------

   diffuser = ''
   calpol   = ''
   darkshut = ''
   cover    = ''
   occltrid = ''

   naxis    = SXPAR (hdu, 'NAXIS',    count=qnaxis)
   naxis1   = SXPAR (hdu, 'NAXIS1',   count=qnaxis1)
   naxis2   = SXPAR (hdu, 'NAXIS2',   count=qnaxis2)
   naxis3   = SXPAR (hdu, 'NAXIS3',   count=qnaxis3)
   naxis4   = SXPAR (hdu, 'NAXIS4',   count=qnaxis4)
   np       = naxis1 * naxis2 * naxis3 * naxis4 

   date_obs = SXPAR (hdu, 'DATE-OBS', count=qdate_obs)
   level    = SXPAR (hdu, 'LEVEL',    count=qlevel)

   bzero    = SXPAR (hdu, 'BZERO',    count=qbzero)
   bbscale  = SXPAR (hdu, 'BSCALE',   count=qbbscale)

   datatype = SXPAR (hdu, 'DATATYPE', count=qdatatype)

   diffuser = SXPAR (hdu, 'DIFFUSER', count=qdiffuser)
   calpol   = SXPAR (hdu, 'CALPOL',   count=qcalpol)
   calpang  = SXPAR (hdu, 'CALPANG',  count=qcalpang)
   darkshut = SXPAR (hdu, 'DARKSHUT', count=qdarkshut)
   exptime  = SXPAR (hdu, 'EXPTIME',  count=qexptime)
   cover    = SXPAR (hdu, 'COVER',    count=qcover)

   occltrid = SXPAR (hdu, 'OCCLTRID', count=qoccltrid)
   
   dshutter = 'unk'
   if (darkshut EQ 'in')  then dshutter = 'shut'
   if (darkshut EQ 'out') then dshutter = 'open'
   ;-----------------------------------
   ; Determine occulter size in pixels.
   ;-----------------------------------

   occulter = strmid (occltrid, 3, 5)	; Extract 5 characters from occltrid.
   IF (occulter EQ '991.6') THEN occulter =  991.6
   IF (occulter EQ '1006.') THEN occulter = 1006.9
   IF (occulter EQ '1018.') THEN occulter = 1018.9

   platescale = 5.643		; arsec/pixel.
   radius_guess = occulter / platescale		; occulter size [pixels].

;   PRINT,        '>>>>>>> ', l0_file, i, '  ', datatype, ' <<<<<<<'
;   PRINTF, ULOG, '>>>>>>> ', l0_file, i, '  ', datatype, ' <<<<<<<'

;   PRINT,        'file size: ', finfo.size
;   PRINTF, ULOG, 'file size: ', finfo.size

   ;--------------------------------------
   ; Get FITS image size from image array.
   ;--------------------------------------

   n1 = 1
   n2 = 1
   n3 = 1
   n4 = 1
   imgsize = SIZE (img)			; get size of img array.
   ndim    = imgsize [0]		; # dimensions
   n1      = imgsize [1]		; dimension #1 size X: 1024
   n2      = imgsize [2]		; dimension #2 size Y: 1024
   n3      = imgsize [3]		; dimension #3 size pol state: 4
   n4      = imgsize [4]		; dimension #4 size camera: 2
   dtype   = imgsize [ndim + 1]		; data type
   npix    = imgsize [ndim + 2]		; # pixels
   nelem   = 1
   FOR j=1, ndim DO nelem *= imgsize [j]	; compute # elements in array.
   IF (ndim EQ 4) THEN nelem = n1 * n2 * n3 * n4

;   imgmin = min (img)
;   imgmax = max (img)

;   PRINTF, ULOG, 'imgmin,imgmax: ', imgmin, imgmax
;   PRINT,        'imgmin,imgmax: ', imgmin, imgmax

;   PRINTF, ULOG, 'size (img): ', imgsize
;   PRINT,        'size (img): ', imgsize
;   PRINTF, ULOG, 'nelem:      ', nelem
;   PRINT,        'nelem:      ', nelem

   ;---------------------------------
   ; Define array center coordinates.
   ;---------------------------------

   xdim = naxis1
   ydim = naxis2
   axcen = (xdim / 2.0) - 0.5		; x-axis array center.
   aycen = (ydim / 2.0) - 0.5		; y-axis array center.

   ;----------------------------------------------------------
   ; Extract date items from FITS header parameter (DATE-OBS).
   ;----------------------------------------------------------

   year   = strmid (date_obs,  0, 4)
   month  = strmid (date_obs,  5, 2)
   day    = strmid (date_obs,  8, 2)
   hour   = strmid (date_obs, 11, 2)
   minute = strmid (date_obs, 14, 2)
   second = strmid (date_obs, 17, 2)

   hdate = string (format='(a4)', year)   + '-' $
         + string (format='(a2)', month)  + '-' $
         + string (format='(a2)', day)    + 'T' $
	 + string (format='(a2)', hour)   + ':' $
	 + string (format='(a2)', minute) + ':' $
	 + string (format='(a2)', second)

   obs_hour = hour
   if (hour LT 16) THEN obs_hour += 24

   hours (i) = obs_hour + minute / 60.0 + second / 3600.0

   ;------------------------------------------------------------

   ; Verify that image size agrees with FITS header information.
   ;------------------------------------------------------------

   IF (nelem    NE  np)   THEN $
   BEGIN
      PRINT,        '*** nelem: ', nelem, 'NE np: ', np
      PRINTF, ULOG, '*** nelem: ', nelem, 'NE np: ', np
      CONTINUE
   END

   ;------------------------------
   ; Verify that image is Level 0.
   ;------------------------------

   IF (level    NE 'L0')  THEN $
   BEGIN
      PRINT,        '*** not Level 0 data ***'
      PRINTF, ULOG, '*** not Level 0 data ***'
      CONTINUE
   END

   ;----------------
   ; Check datatype.
   ;----------------

   IF (datatype EQ 'calibration') THEN  cal += 1
   IF (datatype EQ 'engineering') THEN  eng += 1
   IF (datatype EQ 'science')     THEN  sci += 1

   ;---------------------------
   ; Check mechanism positions.
   ;---------------------------

   ;--- Check diffuser position.

   IF (diffuser NE 'out') THEN $
   BEGIN
      dev  += 1
      diff += 1
;      PRINT,        '+ + + ', l0_file, '                     diffuser: ', $
;                    diffuser
;      PRINTF, ULOG, '+ + + ', l0_file, '                     diffuser: ', $
;                    diffuser
   END

   IF (qdiffuser NE 1) THEN $
   BEGIN
;      PRINT,        'qdiffuser: ', qdiffuser
;      PRINTF, ULOG, 'qdiffuser: ', qdiffuser
   END

   ;-----------------------
   ; Check calpol position. 
   ;-----------------------

   IF (calpol  NE 'out') THEN $
   BEGIN
      dev  += 1
      calp += 1
;      calpang_str = string (format='(f7.2)', calpang)
;      PRINT,        '+ + + ', l0_file, '                     calpol:   ', $
;      calpol, calpang_str
;      PRINTF, ULOG, '+ + + ', l0_file, '                     calpol:   ', $
;      calpol, calpang_str
   END

   IF (qcalpol  NE 1) THEN $
   BEGIN
;      PRINT,        'qcalpol:   ', qcalpol
;      PRINTF, ULOG, 'qcalpol:   ', qcalpol
   END

   ;-----------------------------
   ; Check dark shutter position.
   ;-----------------------------

   IF (darkshut NE 'out') THEN $
   BEGIN
      dev  += 1
      drks += 1
;      PRINT,        '+ + + ', l0_file, '                     darkshut: ', $
;                    darkshut
;      PRINTF, ULOG, '+ + + ', l0_file, '                     darkshut: ', $
;                    darkshut
   END

   IF (qdarkshut NE 1) THEN $
   BEGIN
;      PRINT,        'qdarkshut: ', qdarkshut
;      PRINTF, ULOG, 'qdarkshut: ', qdarkshut
   END

   ;----------------------
   ; Check cover position.
   ;----------------------

   IF (cover    NE 'out') THEN $
   BEGIN
      dev += 1
      cov += 1
;      PRINT,        '+ + + ', l0_file, '                     cover:    ', cover
;      PRINTF, ULOG, '+ + + ', l0_file, '                     cover:    ', cover
   END

   IF (qcover    NE 1) THEN $
   BEGIN
;      PRINT,        'qcover:    ', qcover
;      PRINTF, ULOG, 'qcover:    ', qcover
   END

   ;------------------
   ; Find disc center.
   ;------------------

   rocc0_pix = 0.0
   rocc1_pix = 0.0

;   IF (cal GT 0 OR dev GT 0) THEN $ ; fixed location for center.
;   BEGIN
;      xcen = axcen - 4
;      ycen = aycen - 4
;      rocc0_pix = radius_guess
;   END  $
;   ELSE $					; Locate disc center.

   BEGIN ;{
      cen0_info = kcor_find_image (img0, chisq=chisq, radius_guess, $
                                   /center_guess)
      xcen0 = cen0_info (0)	; x center
      ycen0 = cen0_info (1)	; y center
      rocc0 = cen0_info (2)	; radius of occulter [pixels]
      fxcen0 (i) = xcen0
      fycen0 (i) = ycen0
      frocc0 (i) = rocc0

      cen1_info = kcor_find_image (img1, chisq=chisq, radius_guess, $
                                   /center_guess)
      xcen1 = cen1_info (0)	; x center
      ycen1 = cen1_info (1)	; y center
      rocc1 = cen1_info (2)	; radius of occulter [pixels]
      fxcen1 (i) = xcen1
      fycen1 (i) = ycen1
      frocc1 (i) = rocc1
   END  ;}
;   END  ;}

   PRINTF, ULOG, 'xcen0,ycen0,rocc0:', xcen0, ycen0, rocc0
;   PRINT,        'xcen0,ycen0,rocc0:', xcen0, ycen0, rocc0
   PRINTF, ULOG, 'xcen1,ycen1,rocc1:', xcen1, ycen1, rocc1
;   PRINT,        'xcen1,ycen1,rocc1:', xcen1, ycen1, rocc1

;   PRINT, '!D.N_COLORS: ', !D.N_COLORS

   ;-------------------------
   ; Determine type of image.
   ;-------------------------

   fitsloc  = STRPOS (l0_file, '.fts')
   qual     = 'unk'

   IF (eng GT 0) THEN $			; Engineering
   BEGIN   ;{
      qual  = q_eng
      neng += 1
   END   $ ;}

   ELSE	 $
   IF (cal GT 0) THEN $			; Calibration
   BEGIN   ;{
      qual  = q_cal
      ncal += 1
;      PRINTF, UCAL, l0_file
;      PRINTF, ULOG, l0_file, ' --> ', cdate_dir
;      FILE_COPY, l0_file, cdate_dir, /overwrite   ; copy L0 file to cdate_dir.
   END   $ ;}

   ELSE  $
   IF (dev GT 0) THEN $			; Device obscuration
   BEGIN   ;{
      qual  = q_dev
      ndev += 1
;      PRINTF, UDEV, l0_file
   END   $ ;}

   ELSE  $				; science image.
   BEGIN ;{
      qual = q_sci
      nsci += 1
;      PRINTF, UOKF, l0_file
;      PRINTF, UOKA, l0_file
   END   ;}

   istring     = string (format='(i5)',   i)
   exptime_str = string (format='(f5.2)', exptime)
;   PRINT,        '>>>>> ', img_file, istring, ' exptime:', exptime_str, '  ', $
;                 datatype, ' <<<<< ', qual
;   PRINTF, ULOG, '>>>>> ', img_file, istring, ' exptime:', exptime_str, '  ', $
;                 datatype, ' <<<<< ', qual

   datatype_str = string (format='(a12)', datatype)
   darkshut_str = string (format='(a4)', darkshut)
   dshutter_str = string (format='(a5)', dshutter)
   cover_str    = string (format='(a4)', cover)
   diffuser_str = string (format='(a4)', diffuser)
   calpol_str   = string (format='(a4)', calpol)
   calpang_str  = string (format='(f7.2)', calpang)
   qual_str     = string (format='(a4)', qual)

   ;---------------------
   ; Print image summary.
   ;---------------------

   PRINT,        img_file, datatype_str, exptime_str, cover_str, dshutter_str, $
                 diffuser_str, calpol_str, calpang_str, qual_str
   PRINTF, ULOG, img_file, datatype_str, exptime_str, cover_str, dshutter_str, $
                 diffuser_str, calpol_str, calpang_str, qual_str

END   ;}

;-------------------------------------------------------------------------------
; End of image loop.
;-------------------------------------------------------------------------------

num_img = i + 1

CD, p_dir

PRINT,        'nimg: ', num_img
PRINTF, ULOG, 'nimg: ', num_img

;----------------------------
; Plot occulting disc center.
;----------------------------

set_plot, "Z"
device, set_resolution=[772,900], decomposed=0, set_colors=256
!P.MULTI = [0, 1, 4]

erase

plot, hours, fxcen0, title=pdate + '  Camera 0 occulter raw X center', $
      xtitle='Hours [UT]', ytitle='X center', $
      background=255, color=0, charsize=2.0, $
      yrange = [460.0, 540.0]
      
plot, hours, fycen0, title=pdate + '  Camera 0 occulter raw Y center', $
      xtitle='Hours [UT]', ytitle='Y center', $
      background=255, color=0, charsize=2.0, $
      yrange = [460.0, 550.0]
      
plot, hours, fxcen1, title=pdate + '  Camera 1 occulter X raw center', $
      xtitle='Hours [UT]', ytitle='X center', $
      background=255, color=0, charsize=2.0, $
      yrange = [460.0, 540.0]
      
plot, hours, fycen1, title=pdate + '  Camera 1 occulter Y raw center', $
      xtitle='Hours [UT]', ytitle='Y center', $
      background=255, color=0, charsize=2.0, $
      yrange = [460.0, 540.0]
 
ocen_gif = 'ocen.gif'
ocen_gif = date + '_' + listfile + '_ocen.gif'
save = tvrd ()
write_gif, ocen_gif, save

;-------------------------------
; Plot occulter radius [pixels].
;-------------------------------

!P.MULTI = [0, 1, 2]

erase

plot, hours, frocc0, title=pdate + '  Camera 0 occulter raw radius (pixels)', $
      xtitle='Hours [UT]', ytitle='X center', $
      background=255, color=0, charsize=1.0, $
      yrange = [170.0, 200.0]
      
plot, hours, frocc1, title=pdate + '  Camera 1 occulter raw radius (pixels)', $
      xtitle='Hours [UT]', ytitle='X center', $
      background=255, color=0, charsize=1.0, $
      yrange = [170.0, 200.0]
      
rocc_gif = 'rocc.gif'
rocc_gif = date + '_' + listfile + '_rocc.gif'
save     = tvrd ()
write_gif, rocc_gif, save

;------------------------------------------------------------------------------
CD, l0_dir

move_command = 'mv ' + log_file + ' ' + p_dir

PRINT,        'spawn, ' + move_command
PRINTF, ULOG, 'spawn, ' + move_command

spawn, move_command

;------------------------------------------------------------------------------

DONE:
CD, start_dir
set_plot, 'X'

;--- Get system time & compute elapsed time since "TIC" command.

qtime = TOC ()
PRINTF, ULOG, 'elapsed time: ', qtime
PRINTF, ULOG, qtime / num_img, ' sec/image'

PRINT,        '===== end ... kcor_plotcen ====='
PRINTF, ULOG, '===== end ... kcor_plotcen ====='
PRINTF, ULOG, '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'

CLOSE,    ULIST
FREE_LUN, ULIST
CLOSE,    ULOG
FREE_LUN, ULOG 

END