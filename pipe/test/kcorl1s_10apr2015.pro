;+
; pro kcorl1s
;
; :Author: Joan Burkepile [JB]
; 
; Modified version of 'make_calib_kcor_vig_gif.pro' 
; 8 Oct 2014 09:57 (Andrew Stanger [ALS])
; Extensive revisions by Giliana de Toma [GdT].
; Merge two camera images prior to removal of sky polarization (radius, angle).
;
; 03 Oct 2014: Add date & list parameters.
; 13 Nov 2014: Add base_dir parameter.
; 13 Nov 2014: Use kcor_find_image function to locate disc center.
; 14 Nov 2014: Use Z-buffer instead of X window device for GIF images.
;              Note: charsize for xyouts needs to be reduced to about 2/3 of
;              of the size used for the X window device to yield approximately
;              the same size of characters in the annotated image.
; 19 Nov 2014: Change log file name so that the date always refers to 
;              the observing day (instead of calendar day for the L0 list).
;
; 7 Nov 2014: [GdT] Modified centering algorithm, since it did not find 
;             the correct center.
; 7 Nov 2014: [GdT] Changed to double precision to properly find inflection 
;             points
;             Added keyword center_guess to guess center location using with 
;             vertical/horizonatl scans (see Alice's quick-look code).
;             Added iteration if center is not found at first attempt.
;             Used Randy Meisner fitcircle.pro to fit a circle because faster.
;                
; Revisions to speed up code and fixed a few other things (GdT):
;   Dec 1 2014: negative and zero values in the gain are replaced with the
;               mean value in a 5x5 region centered on bad data point
;   Dec 1 2014: coordinates and radius are defined as arrays for gain and images
;   Dec 1 2014: solar radius, platescale, and occulter are determined at the 
;               beginning of the code
;   Dec 1 2014: gain is not shifted to properly flat-field images 
;               region where gain is not available is based on a shifted gain 
;   Dec 1 2014: removed part about finding the center after demodulation 
;               center for final images is based on distorted raw images - 
;               this is the best way to find the correct center (hard to find 
;               the center after image calibration because of saturation ring).
;   Dec 1 2014: Mk4 cordinate transformation is now based on arrays 
;               (removed loops).
;   Dec 1 2014: sky polaritzion correction is now based on on arrays 
;               (removed loops).
;               sin2theta uses 2 instead of 3 parameters
;               changed derivative in sin2theta and initial guesses in main code
;               U fit is shifted by 45deg for Q correction
;   Dec 1 2014: "a" was used as fit parameter and also as index in for-loops
;               changed to avoid possible variable conflicts
;   Dec 1 2014: final image masking is done with array (removed loop)
;
;   Dec 2014: Calibrated image is shifted and rotated using ROT - so only
;             one interpolation is made to put north up and image in the
;             array center (Giuliana de Toma & Andrew Stanger)
;   Jan 2015: fixed error in sine2theta fit: 
;             converted degrees in radiants for input in sine2theta_new.pro
;             changed degrees and "a" coeff to double precision
;             changed phase guess to zero (this should not make any difference)
; 24 Jan 2015 [ALS] Modify L1SWID = 'kcorl1g.pro 24jan2015'.
;             Remove sine2theta U plots to display.
;             Replace pb0r.pro with sun.pro to compute ephemeris data.
; 28 Jan 2015 [ALS] Modify L1SWID = 'kcorl1g.pro 28jan2015'.
;             Set maxi=1.8, exp=0.7 [previous values: maxi=1.2, exp=0.8]
; 03 Feb 2015 [ALS] Add append keyword (for output log file).
; 12 Feb 2015 [ALS] Add TIC & TOC commands to compute elapsed time.
; 19 Feb 2015 [ALS] Add current time to log file.
; 27 Feb 2015 [GdT] changed the DOY computation
; 27 Feb 2015 [GdT] removed some print statements
; 27 Feb 2015 [GdT] commened out the pb0r (not used anymore)
; 27 Feb 2015 [GdT] added mask of good data and make demodulation for 
;                   good data only
;  3 Mar 2015 [GdT] changed code so distorsion coeff file is restored  only once
;  3 Mar 2015 [GdT] made phase0 and phase1 keywords and set default values
;  3 Mar 2015 [GdT] made bias and sky_factor keywords and set default values
;  3 Mar 2015 [GdT] made cal_dir and cal_file keywords and set defaults
;  3 Mar 2015 [GdT] removed more print statements
;  3 Mar 2015 [GdT] changed call to sun.pro and removed ephem2.pro, 
;                   julian_date.pro, jd_carr_long.pro
;                   all ephemeris info is computed using sun.pro
;  4 Mar 2015 [ALS] L1SWID = 'kcorl1_quick.pro 04mar2015'.
;  6 Mar 2015 [JB] Replaced application of demodulation matrix multiplication
;                  with M. Galloy C-code method. 
;                  *** To execute Galloy C-code, you need a new environmental
;                  variable in your .login or .cshrc:
;                  IDL_DLM_PATH=/hao/acos/sw/idl/kcor/pipe:"<IDL_DEFAULT>"
; 10 Mar 2015 [ALS] Cropped gif annotation was incorrect (power 0.7 should have
;                   been 0.8).  Changed exponent to 0.8.
;                   Now both cropped & fullres gif images use the following:
;                   tv, bytscl (img^0.8, min=0.0 max=1.8).
;                   Annotation will also now be correct for both GIF images.
; 11 Mar 2015 [ALS] Modified GIF scaling: exp=0.7, mini=0.1, maxi=1.4
;                   This provides an improvement in contrast.
;                   L1SWID = "kcorl1g.pro 11mar2015"
; 15 Mar 2015 [JB]  Updated ncdf file from Jan 1, 2015 to March 15, 2015 ncdf file. 
; 18 Mar 2015 [ALS] Modified FITS header comment for RCAMLUT & RCAMLUT.
;                   RCAMLUT is the Reflected camera & TCAMLUT is Transmitted.
;
;                   Kcor data acquired prior to 16 Mar 2015 were using the
;                   WRONG LUT values !.
;                   Greg Card reported (15 Mar 2015) that the following tables
;                   were in use (KcoConfig.ini file [C:\kcor directory]) :
;                   LUT_Names
;                   c:/kcor/lut/Photonfocus_MV-D1024E_13890_adc0_20131203.bin
;                   c:/kcor/lut/Photonfocus_MV-D1024E_13890_adc1_20131203.bin
;                   c:/kcor/lut/Photonfocus_MV-D1024E_13890_adc2_20131203.bin
;                   c:/kcor/lut/Photonfocus_MV-D1024E_13890_adc3_20131203.bin
;                   c:/kcor/lut/Photonfocus_MV-D1024E_13891_adc0_20131203.bin
;                   c:/kcor/lut/Photonfocus_MV-D1024E_13891_adc1_20131203.bin
;                   c:/kcor/lut/Photonfocus_MV-D1024E_13891_adc2_20131203.bin
;                   c:/kcor/lut/Photonfocus_MV-D1024E_13891_adc3_20131203.bin
;                   These look-up tables are for the two SPARE cameras, NOT
;                   the ones in use at MLSO.
;
;                   On 16 Mar 2015, Ben Berkey changed the KcoConfig.ini file:
;                   LUT_Names
;                   c:/kcor/lut/Photonfocus_MV-D1024E_11461_adc0_20131203.bin
;                   c:/kcor/lut/Photonfocus_MV-D1024E_11461_adc1_20131203.bin
;                   c:/kcor/lut/Photonfocus_MV-D1024E_11461_adc2_20131203.bin
;                   c:/kcor/lut/Photonfocus_MV-D1024E_11461_adc3_20131203.bin
;                   c:/kcor/lut/Photonfocus_MV-D1024E_13889_adc0_20131203.bin
;                   c:/kcor/lut/Photonfocus_MV-D1024E_13889_adc1_20131203.bin
;                   c:/kcor/lut/Photonfocus_MV-D1024E_13889_adc2_20131203.bin
;                   c:/kcor/lut/Photonfocus_MV-D1024E_13889_adc3_20131203.bin
;                   These are the correct tables to be used, since the cameras
;                   in use at MLSO (since deployment, Nov 2013) are:
;                   camera 0 (Reflected)   S/N 11461
;                   camera 1 (Transmitted) S/N 13889
; 09 Apr 2015 [ALS] L1SWID='kcorl1s.pro 09apr2015'.
;                   Combine images from both cameras prior to removal
;                   of sky polarization (radius, angle).
;		    cal_file='20150403_203428_ALL_ANGLES_kcor_1ms_new_dark.ncdf'
; 10 Apr 2015 [ALS] Add fits header keyword: 'DATATYPE' (cal, eng, science).
;                   L1SWID='kcorl1s.pro 10apr2015'.
;-------------------------------------------------------------------------------
;   Make semi-calibrated kcor images.
;-------------------------------------------------------------------------------
; 1. Uses a coordinate transform to a mk4-q like image. Need to find a better 
;    way to identify the phase angle.
;*** I am setting a variable called 'phase' to try to minimize coronal signal 
;    in unwanted polarization image.
;*** I HAVE ADDED A BIAS IN  TO HELP REMOVE DARK AREAS
;*** VIGNETTING IS OFF!!!!!!!
;*** USING ONLY FRACTION OF SKY POLARIZATION REMOVAL
;
; I am only removing sky from Q and U. Need to remove it from I as well 
; at a later date.
;
; 2. FUTURE: Alfred needs to add the Elmore calibration of Mk4 Opal 
; 3. Alfred still testing cameras to remove unwanted zeros in creating ncdf file
; 4. NEED TO STREAMLINE CODE AND MINIMIXE NUMBER OF INTERPOLATIONS
; 5. SPEED UP VIGNETTING BY using Giluiana's suggestion of creating a
; vignetting image and doing matrix multiplication to apply to image.
;
; ORDER OF PROCESSING: 
; 1. Apply Alfred's Demodulation Matrix
; 2. Find Image Centers for Each Camera
; 3. Apply Co-ordinate Transformation to get to Tangential (with respect to 
;    solar limb) Polarization ('mk4-q') and polarization 45 degrees from 
;    tangential ('mk4-u').
;    Ideally, tangential image will contain all corona + sky polarization and 
;    image polarized 45 deg.to tangential will contain only sky polarization.
;  
; FINAL CORONAL IMAGE: Only uses mk4-q like data. 
; There is still a small residual coronal signal in mk4-u like images 
; but they contain mostly noise.
;      
;--- HISTORY OF INSTRUMENT CHANGES THAT EFFECT CALIBRATION AND PROCESSING ---
;
; I have hardwired certain parameters to best process images
; acquired between Oct 2013 and present (May 2014)
; By 3rd week of Oct 2013 the instrument software was finally
; operating to give consistent sequences of polarization images
; by running socketcam continuously. Prior to that data may not be usable
; since we are not sure of the order of polarization states 
; CHANGES: 
; BZERO in header Oct 15, and Oct 31 =  2147483648 = 2^15
; OCCLTRID value changes. Prior to ??? it was 'OC-1'. 
; I believe this is occulter 1018.9". Need to verify.
; On Oct 15, the header value for modulator temperture is 512.0 deg C. 
; That's nuts. should be 35 deg C.
; Oct 20: Ben reports changing zero offset(BZERO). It was initially set at 
; 16 bit (65536, 32768)
;
; Other things to check: integrity of SGS values
;
;--- FUTURE: NEED TO CHECK OCCULTER SIZE AND EXPOSURE TO DETERMINE APPROPRIATE 
;    NCDF FILE.
;   CURRENTLY: Hardwired.
; Short cut could be to read date of file to determine which ncdf calibration 
; file to pick up
; As of now (May 2014) we have used 1 msec exposures as the standard since 
; the mk4 opal went in back in early November 2013 so all ncdf files so far 
; have same exposure.
; Occulters: There are 3 Kcor occulters. Dates of changes are: 

; r = 1018.9" occulter installed 30 October 2013 21:02 to 28 March 2014 16:59
; r = 1006.9"  installed for a few minutes only on 28 Jan 2014 01:09:13 
;              installed 28 March 2014 17:00:09 to 28 Apr 2014 16:42
; r = 996.1"   installed 28 April 2014 16:43:47
;------------------------------------------------------------------------------
; FUNCTIONS AND OTHER PROGRAMS CALLED: 
;------------------------------------------------------------------------------
; anytim2tai         (in /ssw/gen dir)
; anytim2jd          (in /ssw/gen dir)
; apply_dist         (tomczyk: in /acos/sw/idl/kcor/pipe dir)
; datecal            (sitongia; located in /acos/sw/idl/kcor/pipe directory)
; ephem2             (in /acos/sw/idl/gen dir)
; kcor_find_image    (tomczyk/detoma author, code is in: /acos/sw/idlkcor/pipe)
; kcor_radial_der    (tomczyk/detoma author, code is in: /acos/sw/idlkcor/pipe)
; fitshead2struct    (in ssw/gen dir)
; fitcircle          (meisner  in: /acos/sw/idlkcor/pipe)
; fshift             (in ssw/yohloh dir)
; jd_carr_long.pro   (in /acos/sw/idl/kcor/pipe dir)
; pb0r               (in ssw/gen dir)
;  
;  -------------------   RECORD OF PARAMETERS USED FOR VARIOUS DATES
;
;  ----- 31 OCT 2013  -----------------
;
; ncdf file:  20131031_cal_214306_kcor.ncdf created in May 2014
; Mk4-like transformation phase= !pi/24.    ; 8 deg.  
; Sky polarization amplitude: skyamp = .0035  
; Sky polarization phase:     skyphase = -1.*!pi/4.   ; -45  deg  
; Used image distortion test results of Oct 30, 2013 generated by Steve Tomczyk
; bias = 0.002     
; tv, bytscl(corona^0.8, min=-.05, max=0.15)      
; mini= 0.00    
; maxi= 0.08     
;------------------------------------------------------------------------------
; SYNTAX :
; kcorl1s, date_string, list='list_of_L0_files', $
;               base_dir='base_directory_path'
; kcorl1s, 'yyyymmdd', list='L0_list', $
;               base_dir='/hao/mlsodata1/Data/KCor/raw'
; 
; EXAMPLES:
; kcorl1s, '20141101', list='list17'
; kcorl1s, '20141101', list='list17', /append
; kcorl1s, '20140731', list='doy212.ls',base_dir='/hao/mlsodata1/Data/KCor/work'
;
; The default base directory is '/hao/mlsodata1/Data/KCor/raw'.
; The base directory may be altered via the 'base_dir' keyword parameter.
;
; The L0 fits files need to be stored in the 'date' directory, 
; which is located in the base directory.
; The list file, containing a list of L0 files to be processed, also needs to
; be located in the 'date' directory.
; The name of the L0 FITS files needs to be specified via the 'list' 
; keyword parameter.
;
; All Level 1 files (fits & gif) will be stored in the sub-directory 'levelg',
; under the date directory.
;------------------------------------------------------------------------------
;-

pro kcorl1s, date_str, list=list, $
             base_dir=base_dir, append=append, $
             cal_dir=cal_dir, cal_file=cal_file, $
             phase0=phase0, phase1=phase1, bias=bias, $
             sky_factor=sky_factor, $
	     dc_dir=dc_dir, dc_file=dc_file

;--- Use TIC & TOC to determine elapsed duration of procedure execution.

TIC

;-------------------------------------------------------------------------------
; Default values for optional keywords.
;-------------------------------------------------------------------------------

default, cal_dir,   '/hao/mlsodata1/Data/KCor/calib_files'

; default, cal_file,  '20150101_190612_kcor_cal_1.0ms.ncdf' ; < 10 Mar 2015.
; Use 20150315 file >= March 10, 2015 due to color corrector lens changes
; by Dennis G.

;default, cal_file,  '20150315_202646_kcor_cal_1.0ms.ncdf'   

; Use 20150403_203428_ALL_ANGLES_kcor_1ms_new_dark.ncdf after 03 Apr 2015 20:12.

default, cal_file,  '20150403_203428_ALL_ANGLES_kcor_1ms_new_dark.ncdf'   

default, phase0,  !pi/11.       ; camera 0   16. degrees look ok for 18 Jun 2014
                                ; and April 27, 2014
default, phase1, -1.*!pi/9.	; camera 1  -20. degrees look ok for 27 Apr 2014

; GdT: bias and sky_factor are now keywords
; default values should be 0 and 1 but I kept the old values for now.

default, bias, 0.07
default, sky_factor, 0.5

default, dc_dir,  '/hao/acos/sw/idl/kcor/pipe'
default, dc_file, 'dist_coeff_20131030_2058.sav'	; distortion correction

dc_file = 'dist_coeff_20131030_2058.sav'

;--- Define base directory and L0 directory.

IF NOT KEYWORD_SET (base_dir) THEN base_dir = '/hao/mlsodata1/Data/KCor/raw'

l0_dir   = base_dir + '/' + date_str + '/'
l1_dir   = l0_dir   + 'levels/'
l0_file  = ''
dc_path  = dc_dir + '/' + dc_file	; distortion correction pathname.

IF (NOT FILE_TEST (l1_dir, /DIRECTORY)) THEN FILE_MKDIR, l1_dir

;-------------------------------------------------------------------------------
; Move to the processing directory.
;-------------------------------------------------------------------------------

cd, current=start_dir			; Save current directory.
cd, l0_dir				; Move to L0 processing directory

;-------------------------------------------------------------------------------
; Identify list of L0 files.
;-------------------------------------------------------------------------------

GET_LUN, ULIST
CLOSE,   ULIST

IF (KEYWORD_SET (list)) THEN $
BEGIN
   listfile = list   
END  $
ELSE $
BEGIN
   listfile = l0_dir + 'l0_list'

;   OPENW,   ULIST, listfile
;   PRINTF,  ULIST, 'test.fts'
;   CLOSE,   ULIST

   spawn, 'ls *kcor.fts* > l0_list'
END

;-------------------------------------------------------------------------------
; Get current date & time.
;-------------------------------------------------------------------------------

current_time = systime (0)

;-------------------------------------------------------------------------------
; Open log file.
;-------------------------------------------------------------------------------

logfile = date_str + '_l1_' + listfile + '.log'
GET_LUN, ULOG
CLOSE,   ULOG
IF (keyword_set (append)) THEN $
   OPENW,   ULOG, l1_dir + logfile, /append $
ELSE	$
   OPENW,   ULOG, l1_dir + logfile

;PRINT,        '--- kcorl1g ', date_str, ' --- ', current_time
;PRINT,        'l0_dir: ', l0_dir
;PRINT,        'l1_dir: ', l1_dir

PRINTF, ULOG, '--- kcorl1g ', date_str, ' --- ', current_time

;PRINTF, ULOG, 'l0_dir: ', l0_dir
;PRINTF, ULOG, 'l1_dir: ', l1_dir

;-------------------------------------------------------------------------------
; Check for empty list file.
;-------------------------------------------------------------------------------

nfiles = fix (file_lines (listfile))		; # files in list file.
if (nfiles EQ 0) THEN $
BEGIN ;{
   PRINT,        listfile, ' empty.  No files to process.'
   PRINTF, ULOG, listfile, ' empty.  No files to process.'
   GOTO, DONE
END   ;}

;-------------------------------------------------------------------------------
; Extract information from calibration file.
;-------------------------------------------------------------------------------

calpath = cal_dir + '/' + cal_file

PRINT,        'calpath: ', calpath
PRINTF, ULOG, 'calpath: ', calpath

unit = ncdf_open (calpath)
  ncdf_varget, unit, 'Dark', dark_alfred
  ncdf_varget, unit, 'Gain', gain_alfred
  ncdf_varget, unit, 'Modulation Matrix', mmat
  ncdf_varget, unit, 'Demodulation Matrix', dmat
ncdf_close, unit

; IN FUTURE: Check matrix for any elements > 1.0
; I am only printing matrix for one pixel.

;PRINT, 'Mod Matrix = camera 0'
;PRINT, reform (mmat(100, 100, 0, *, *))
;PRINT, 'Mod Matrix = camera 1'
;PRINT, reform (mmat(100, 100, 1, *, *))

;PRINTF, ULOG, 'Mod Matrix = camera 0'
;PRINTF, ULOG, reform (mmat(100, 100, 0, *, *))
;PRINTF, ULOG, 'Mod Matrix = camera 1'
;PRINTF, ULOG, reform (mmat(100, 100, 1, *, *))

; Set image dimensions.

xsize = 1024L
ysize = 1024L

;-------------------------------------------------------------------------------
; Modify gain images.
; Set zero and negative values in gain to value stored in 'gain_negative'.
;-------------------------------------------------------------------------------
; GdT: changed gain correction and moved it up (not inside the loop)
; this will change when we read the daily gain instead of a fixed one.

gain_negative = -10
gain_alfred (WHERE (gain_alfred LE 0, /NULL)) = gain_negative

;--- Replace zero and negative values with mean of 5x5 neighbour pixels.

FOR b = 0, 1 DO BEGIN
   gain_temp = double (reform (gain_alfred (*, *, b)))
   filter = mean_filter (gain_temp, 5, 5, invalid = gain_negative , missing=1)
   bad = WHERE (gain_temp EQ gain_negative, nbad)

   IF (nbad GT 0) THEN $
   BEGIN 
      gain_temp (bad) = filter (bad)
      gain_alfred (*, *, b) = gain_temp
   ENDIF
ENDFOR
gain_temp = 0

;----------------------------------------------------------------------
; Find center and radius for gain images.
;----------------------------------------------------------------------

; Set guess for radius - needed to find center.

radius_guess = 178		; average radius for occulter.

;PRINTF, ULOG, 'radius_guess ', radius_guess

center0_info_gain = kcor_find_image (gain_alfred (*, *, 0), radius_guess)
center1_info_gain = kcor_find_image (gain_alfred (*, *, 1), radius_guess)

;------------------------------------------
; Define coordinate arrays for gain images.
;------------------------------------------

gxx0 = findgen (xsize, ysize) mod (xsize) - center0_info_gain (0)
gyy0 = transpose (findgen (ysize, xsize) mod (ysize) ) - center0_info_gain (1)

gxx0 = double (gxx0)  &  gyy0 = double (gyy0)
grr0 = sqrt (gxx0^2.0 + gyy0^2.0)  

gxx1 = findgen (xsize, ysize) mod (xsize) - center1_info_gain(0)
gyy1 = transpose (findgen (ysize, xsize) mod (ysize) ) - center1_info_gain (1)

gxx1 = double (gxx1)  &  gyy1 = double (gyy1)
grr1 = sqrt (gxx1^2.0 + gyy1^2.0)  

PRINTF, ULOG, 'Gain 0 center and radius : ' , center0_info_gain
PRINTF, ULOG, 'Gain 1 center and radius : ' , center1_info_gain

;-------------------------------------------------------------------------------
; Initialize variables.
;-------------------------------------------------------------------------------

cal_data     = dblarr (xsize, ysize, 2, 3)
cal_data_new = dblarr (xsize, ysize, 2, 3)
gain_shift   = dblarr (xsize, ysize, 2)

set_plot, 'Z'

doplot = 0			; Flag to do diagnostic plots & images.

;set_plot, 'X'
;device, set_resolution=[768, 768], decomposed=0, set_colors=256, $
;        z_buffering=0
;erase

;--- Load color table.

lct, '/hao/acos/sw/colortable/quallab_ver2.lut'	; color table.
tvlct, red, green, blue, /get

;*******************************************************************************
;*******************************************************************************
; Image file loop.
;*******************************************************************************
;*******************************************************************************

fnum = 0
OPENR, ULIST, listfile

WHILE (not EOF (ULIST) ) DO $
BEGIN ;{
   fnum += 1
   lclock = TIC ('Loop_' + STRTRIM (fnum, 2))

   readf, ULIST,   l0_file
   img = readfits (l0_file, header, /SILENT)
   img = float (img)
   image0 = reform (img (*, *, 0, 0))
   image1 = reform (img (*, *, 0, 1))

   TYPE = ''
   TYPE = fxpar (header, 'DATATYPE')

   PRINT,        '>>>>>>> ', l0_file, '  ', fnum, '  ', TYPE, ' <<<<<<<'
   PRINTF, ULOG, '>>>>>>> ', l0_file, '  ', fnum, '  ', TYPE, ' <<<<<<<'

   ;--- Read date of observation.  (needed to compute ephemeris info)

   dateobs = SXPAR  (header, 'DATE-OBS') 
   date    = strmid (dateobs, 0,10)

;   PRINT,         'dateobs: ', dateobs
;   PRINTF, ULOG,  'dateobs: ', dateobs

   ; -----------------------------------------
   ; Create string data for annotating image.
   ; -----------------------------------------

   ;--- Extract date and time from L0 FITS file name.

   year   = strmid (l0_file, 0, 4)
   month  = strmid (l0_file, 4, 2)
   day    = strmid (l0_file, 6, 2)
   hour   = strmid (l0_file, 9, 2)
   minute = strmid (l0_file, 11, 2)
   second = strmid (l0_file, 13, 2)

   ehour = float (hour) + minute / 60.0 + second / 3600.0

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

   dateimg = day + ' ' + name_month + ' ' + year + ' ' $
           + hour + ':' + minute + ':'  + second

;   PRINT,        'dateimg: ', dateimg
;   PRINTF, ULOG, 'dateimg: ', dateimg

   ;--- Determine DOY.

    mday      = [0,31,59,90,120,151,181,212,243,273,304,334]   
    mday_leap = [0,31,60,91,121,152,182,213,244,274,305,335] ;leap year

    IF ((fix(year) mod 4) EQ 0) THEN doy = (mday_leap(fix(month)-1) + fix(day))$
    ELSE $
    doy = (mday (fix (month) - 1) + fix (day))

   ;--- Put the fits header into a structure.

   struct = fitshead2struct ((header), DASH2UNDERSCORE = dash2underscore)

;   window, 0, xs = 1024, ys = 1024, retain = 2
;   window, 0, xs = 1024, ys = 1024, retain = 2, xpos = 512, ypos = 512

   device, set_resolution=[1024,1024], decomposed=0, set_colors=256, $
           z_buffering=0
   erase

;  PRINT,        'year, month, day, hour, minute, second: ', $
;                year, ' ', month, ' ', day, ' ', hour, ' ', minute, ' ', second
;  PRINTF, ULOG, 'year, month, day, hour, minute, second: ', $
;                year, ' ', month, ' ', day, ' ', hour, ' ', minute, ' ', second

   ; ----------------------------------
   ; Solar radius, P and B angle.
   ; ---------------------------------
   
   ;ephem  = pb0r (dateobs, /earth)
   ;pangle = ephem (0)      
   ;bangle = ephem (1)
   ;radsun = ephem (2)    ; arcmin

   ; --------------------------------
   ; Ephemeris data.
   ;---------------------------------
   
   sun, year, month, day, ehour, sd=radsun, pa=pangle, lat0=bangle, $
        true_ra=sol_ra, true_dec=sol_dec, $
        carrington=carrington, long0=carrington_long

   sol_ra = sol_ra * 15.0		; Convert from hours to degrees.
   carrington_rotnum = fix (carrington)

;   julian_date = julday (month, day, year, hour, minute, second)

   ; ---------------------
   ;  Platescale
   ; ---------------------
   ; Made PRELIMARY measurements of 3 occulter diameters to compute 
   ; first estimate of platescale.
   ; Largest occulter: radius = 1018.9" is 361 pixels in diameter,
   ; giving platescale = 5.64488" / pixel
   ; Medium occulter: radius = 1006.9" is 356.5 pixels in diameter,
   ; giving platescale = 5.64881" / pixel
   ; Smallest occulter: radius = 991.6" is 352 pixels in diameter,
   ; giving platescale = 5.63409" / pixel
   ; Avg value = 5.643 +/- 0.008" / pixel

   platescale = 5.643			; arcsec/pixel.

   ; ----------------------
   ; Find size of occulter.
   ; ----------------------
   ; One occulter has 4 digits; Other two have 5. 
   ; Only read in 4 digits to avoid confusion.

   occulter_id = ''
   occulter_id = fxpar (header, 'OCCLTRID')
   occulter = strmid (occulter_id, 3, 5)
   occulter = float (occulter)
   IF (occulter eq 1018.0) THEN occulter = 1018.9
   IF (occulter eq 1006.0) THEN occulter = 1006.9

;   PRINT,        'occulter size [arcsec] : ', occulter
;   PRINTF, ULOG, 'occulter size [arcsec] : ', occulter

   radius_guess = occulter / platescale			; pixels

   ;----------------------------------------------------------------------------
   ; Find image centers & radii of raw images.
   ;----------------------------------------------------------------------------
 
   ; Camera 0. (reflected)
    
   center_info_img  = kcor_find_image (img (*, *, 0, 0), $
                                       radius_guess, /center_guess)
   xctr0    = center_info_img (0)
   yctr0    = center_info_img (1)
   radius_0 = center_info_img (2)

   xx0 = findgen (xsize, ysize) mod (xsize) - xctr0   
   yy0 = transpose (findgen (ysize, xsize) mod (ysize) ) - yctr0

   xx0 = double (xx0)  &  yy0 = double (yy0)
   rr0 = sqrt (xx0^2.0 + yy0^2.0)

   theta0 = (atan (-yy0, -xx0)) 
   theta0 = theta0 + !pi

;   pick0 = where (rr0 gt radius_0 -1.0 and rr0 lt 506.0 )
;   mask_occulter0 = fltarr (xsize, ysize)
;   mask_occulter0 (*) = 0
;   mask_occulter0 (pick0) = 1.

   ; Camera 1. (transmitted)

   center_info_img = kcor_find_image (img (*, *, 0, 1), $
                                      radius_guess, /center_guess)
   xctr1    = center_info_img (0)
   yctr1    = center_info_img (1)
   radius_1 = center_info_img (2)

   xx1 = findgen (xsize, ysize) mod (xsize) - xctr1  
   yy1 = transpose (findgen (ysize, xsize) mod (ysize) ) - yctr1

   xx1 = double (xx1) &  yy1 = double (yy1)
   rr1 = sqrt (xx1^2.0 + yy1^2.0)

   theta1 = (atan (-yy1, -xx1)) 
   theta1 = theta1 + !pi

;   pick1 = where (rr1 ge radius_1 -1.0 and rr1 lt 506.0)
;   mask_occulter1 = fltarr (xsize, ysize)
;   mask_occulter1 (*) = 0
;   mask_occulter1 (pick1) = 1.0

;   PRINTF, ULOG, 'CAMERA CENTER INFO FOR RAW IMAGES'
   PRINTF, ULOG, 'Camera 0 center and radius: ', xctr0, yctr0, radius_0
   PRINTF, ULOG, 'Camera 1 center and radius: ', xctr1, yctr1, radius_1

   ;--------------------------------------------
   ; Create new gain to account for image shift.
   ;--------------------------------------------
   ; Region of missing data is set to a constant for now.
   ; It should be replaced with the values from the gain we took without
   ; occulter in.

   ;--- camera 0:

   replace = WHERE (rr0 GT radius_0 -4. AND grr0 LE center0_info_gain(2) +4., $
                    nrep)
   IF (nrep GT 0) THEN $
   BEGIN ;{
      gain_temp = gain_alfred (*, *, 0)
      gain_replace = shift (gain_alfred (*, *, 0), $
                            xctr0 - center0_info_gain (0), $
                            yctr0 - center0_info_gain (1) )
      gain_temp (replace) = gain_replace (replace)  ;gain_no_occulter0 (replace)
      gain_shift (*, *, 0) = gain_temp
;      PRINTF, ULOG, 'Gain for CAMERA 0 shifted to image position.'     
   ENDIF ;}

   ;--- camera 1:

   replace = WHERE (rr1 GT radius_1 -4. AND grr1 LE center1_info_gain(2) +4., $
                    nrep)
   IF (nrep GT 0) THEN $
   BEGIN ;{
      gain_temp =  gain_alfred (*, *, 1)
      gain_replace = shift (gain_alfred (*, *, 1), $
                            xctr1 - center1_info_gain (0), $
			    yctr1 - center1_info_gain (1) )
      gain_temp (replace) = gain_replace (replace) ; gain_no_occulter1 (replace)
      gain_shift (*, *, 1) = gain_temp
;      PRINTF, ULOG, 'Gain for CAMERA 1 shifted to image position.'
   ENDIF ;}

   gain_temp    = 0
   gain_replace = 0
   img_cor      = img

   ;----------------------------------------------------------------------------
   ; Apply dark and gain correction.
   ;----------------------------------------------------------------------------
   ; (Set negative values (after dark subtraction) to zero.)

   FOR b = 0, 1 DO $
   BEGIN  ;{ 
      FOR s = 0, 3 DO $
      BEGIN  ;{
;         img (*, *, s, b) = $
;            (img (*, *, s, b) - dark_alfred (*, *, b)) / gain_shift (*, *, b)

         img_cor (*, *, s, b) = img (*, *, s, b) - dark_alfred (*, *, b)
	 img_temp = reform (img_cor (*, *, s, b))
	 img_temp (WHERE (img_temp LE 0, /NULL)) = 0
	 img_cor (*, *, s, b)  = img_temp
         img_cor (*, *, s, b) /= gain_shift (*, *, b)
      ENDFOR ;}
   ENDFOR ;}

   img_temp = 0

;   PRINTF, ULOG, 'Applied dark and gain correction.'  

   ;----------------------------------------------------------------------------
   ; Apply demodulation matrix to get I, Q, U images from each camera.
   ;----------------------------------------------------------------------------

   ;--- Method 27 Feb 2015.

;   FOR y = 0, ysize - 1 do begin
;      FOR x = 0, xsize - 1 do begin
;         IF (mask_occulter0 (x,y) EQ 1) THEN $
;         cal_data (x, y, 0, *) = reform (   dmat (x, y, 0, *, *)) $
;                              ## reform (img_cor (x, y, *, 0))
;         IF (mask_occulter1 (x,y) EQ 1) THEN $
;         cal_data (x, y, 1, *) = reform (   dmat (x, y, 1, *, *)) $
;                              ## reform (img_cor (x, y, *, 1))
;      ENDFOR
;   ENDFOR

  ;--- New method using M. Galloy C-language code. (04 Mar 2015).

   dclock = TIC ('demod_matrix')

   a = transpose (    dmat, [3, 4, 0, 1, 2])
   b = transpose (img_cor,  [2, 0, 1, 3])
   result = kcor_batched_matrix_vector_multiply (a, b, 4, 3, xsize * ysize * 2)
   cal_data = reform (transpose (result), xsize, ysize, 2, 3)

   demod_time = TOC (dclock)

   PRINT,        '--- demod matrix   [sec]:  ', demod_time 
   PRINTF, ULOG, '--- demod matrix   [sec]:  ', demod_time 

;  PRINTF, ULOG, 'Applied demodulation.'

   ;----------------------------------------------------------------------------
   ; Apply distortion correction for raw images.
   ;----------------------------------------------------------------------------

   image0 = reform  (img (*, *, 0, 0))
   image0 = reverse (image0, 2)			; y-axis inversion.
   image1 = reform  (img (*, *, 0, 1))

;   restore, '/home/iguana/idl/kcor/dist_coeff.sav'

   restore, dc_path			; distortion correction file.

   dat1 = image0
   dat2 = image1
   apply_dist, dat1, dat2, dx1_c, dy1_c, dx2_c, dy2_c
   image0 = dat1
   image1 = dat2

   ;----------------------------------------------------------------------------
   ; Find image centers of distortion-corrected images.
   ;----------------------------------------------------------------------------
   ;--- Camera 0:

   center0_info_new = kcor_find_image (image0, radius_guess, /center_guess)
   xctr0    = center0_info_new (0)
   yctr0    = center0_info_new (1)
   radius_0 = center0_info_new (2)

   IF (doplot EQ 1) THEN $
   BEGIN ;{
      tv, bytscl(image0, 0, 20000)
      loadct, 39
      draw_circle, xctr0, yctr0, radius_0, /dev, color=250
      loadct, 0
      print, 'center camera 0 ', center0_info_new
      wait, 1  
   ENDIF ;}

   ;--- Camera 1:

   center1_info_new = kcor_find_image (image1, radius_guess, /center_guess)
   xctr1    = center1_info_new (0)
   yctr1    = center1_info_new (1)
   radius_1 = center1_info_new (2)

   xx1 = findgen (xsize, ysize) mod (xsize) - xctr1
   yy1 = transpose (findgen (ysize, xsize) mod (ysize) ) - yctr1

   xx1 = double (xx1)
   yy1 = double (yy1)
   rad1 = sqrt (xx1^2.0 + yy1^2.0)

   theta1 = atan (-yy1, -xx1)
   theta1 = theta1 + !pi

   IF (doplot EQ 1) THEN $
   BEGIN ;{
      tv, bytscl (image1, 0, 20000)
      loadct, 39
      draw_circle, xctr1, yctr1, radius_1, /dev, color=250
      loadct, 0
      print, 'center camera 1 ', center1_info_new
      wait, 1  
   ENDIF ;}

   ;----------------------------------------------------------------------------
   ; Combine I, Q, U images from camera 0 and camera 1.
   ;----------------------------------------------------------------------------

   radius = (radius_0 + radius_1) * 0.5

   ;--- To shift camera 0 to canera 1:

   deltax = xctr1 - xctr0
   deltay = yctr1 - yctr0

;   print, 'combine beams'

   ; TEST TO COMBINE BEAMS

   FOR s = 0, 2 DO $
   BEGIN  ;{
      cal_data (*, *, 0, s) = reverse (cal_data (*, *, 0, s), 2, /overwrite)
   ENDFOR ;}

   restore, dc_path			; distortion correction file.

   FOR s = 0, 2 DO $
   BEGIN  ;{
      dat1 = cal_data (*, *, 0, s)
      dat2 = cal_data (*, *, 1, s)
      apply_dist, dat1, dat2, dx1_c, dy1_c, dx2_c, dy2_c
      cal_data (*, *, 0, s) = dat1
      cal_data (*, *, 1, s) = dat2
   ENDFOR ;}

   ;----------------------------------------------------------------------------
   ; Compute image average from cameras 0 & 1.
   ;----------------------------------------------------------------------------

   cal_data_combined = dblarr (xsize, ysize, 3)

   FOR s = 0, 2 DO $
   BEGIN  ;{
      cal_data_combined (*, *, s) = $
         ( fshift (cal_data (*, *, 0, s), deltax, deltay) $
	         + cal_data (*, *, 1, s) ) * 0.5
   ENDFOR ;}

   if (doplot EQ 1) THEN $
   BEGIN ;{
      tv, bytscl (cal_data_combined(*,*,0), 0, 100)
      draw_circle, xctr1, yctr1, radius_1, /dev, color=0
      wait, 1
   ENDIF ;}

   phase = -17 / !radeg
;   phase = 0.0

   ;--- Polar coordinate images (mk4 scheme).

   qmk4 = - cal_data_combined (*, *, 1) * sin (2.0 * theta1 + phase) $
          + cal_data_combined (*, *, 2) * cos (2.0 * theta1 + phase)
;   qmk4 = -1.0 * qmk4

   umk4 =   cal_data_combined (*, *, 1) * cos (2.0 * theta1 + phase) $
          + cal_data_combined (*, *, 2) * sin (2.0 * theta1 + phase)

   intensity = cal_data_combined (*, *, 0)

   if (doplot EQ 1) THEN $
   BEGIN ;{
      tv, bytscl (umk4, -0.5, 0.5)
      wait, 1
   ENDIF ;}

;   print, 'finished combining beams.'

   ;----------------------------------------------------------------------------
   ; Shift images to center of array & orient north up.
   ;----------------------------------------------------------------------------

   xcen = 511.5 + 1     ; X Center of FITS array equals one plus IDL center.
   ycen = 511.5 + 1     ; Y Center of FITS array equals one plus IDL center.

                        ; IDL starts at zero but FITS starts at one.
                        ; See Bill Thompson Solar Soft Tutorial on
                        ; basic World Coorindate System Fits header.

   shift_center = 0
   shift_center = 1
   IF (shift_center EQ 1) THEN $
   BEGIN ;{
      cal_data_combined_center = dblarr (xsize, ysize, 3)

      FOR s = 0, 2 DO $
      BEGIN ;{
         cal_data_new (*, *, 0, s) = rot (reverse (cal_data (*, *, 0, s), 1), $
	                                  pangle, 1, xsize - 1 - xctr0, yctr0, $
					  cubic=-0.5)
         cal_data_new (*, *, 1, s) = rot (reverse (cal_data (*, *, 1, s), 1), $
                                          pangle, 1, xsize - 1 - xctr1, yctr1, $
					  cubic=-0.5)

         cal_data_combined_center (*, *, s) = (cal_data_new (*, *, 0, s)  $
	                                    +  cal_data_new (*, *, 1, s)) * 0.5
      ENDFOR ;}

      xx1    = findgen (xsize, ysize) mod (xsize) - 511.5
      yy1    = transpose (findgen (ysize, xsize) mod (ysize) ) - 511.5

      xx1    = double (xx1)
      yy1    = double (yy1)
      rad1   = sqrt ( xx1^2.0 + yy1^2.0 )

      theta1 = atan (-yy1, -xx1)
      theta1 = theta1 + !pi
      theta1 = rot (reverse (theta1), pangle, 1)

      xctr1  = 511.5
      yctr1  = 511.5

;      print, 'finished combined beams center'

      IF (doplot EQ 1) THEN $
      BEGIN ;{
         window, 1, xs = xsize, ys = ysize, retain = 2
         wset,1
         tv, bytscl (cal_data_combined_center (*, *, 0), 0, 100)
         draw_circle,  xctr1, yctr1, radius, /dev, color=0
         wset,1
      ENDIF ;}

      ;--- Polar coordinates.

      qmk4 = - cal_data_combined_center (*, *, 1) * sin (2.0 * theta1 + phase) $
             + cal_data_combined_center (*, *, 2) * cos (2.0 * theta1 + phase)
;      qmk4 = -1.0 * qmk4

      umk4 =   cal_data_combined_center (*, *, 1) * cos (2.0 * theta1 + phase) $
             + cal_data_combined_center (*, *, 2) * sin (2.0 * theta1 + phase)

      intensity = cal_data_combined_center (*, *, 0)

      IF (doplot EQ 1) THEN $
      BEGIN ;{
         tv, bytscl (umk4, -0.5, 0.5)
      ENDIF ;}

   ENDIF ;}

   ; -------------------------------------------------------------------------
   ; Sky polarization removal on coordinate-transformed data.
   ; -------------------------------------------------------------------------

;   print, 'Remove sky polarization.'

   r_init = 1.8
   rnum   = 11 

   radscan    = fltarr (rnum)
   amplitude1 = fltarr (rnum)
   phase1     = fltarr (rnum)

;   numdeg=360
;   numdeg=180

   numdeg  = 90
   stepdeg = 360 / numdeg
   degrees = findgen (numdeg) * stepdeg + 0.5 * stepdeg
   degrees = double (degrees)/!radeg

   a           = dblarr (2)		; coefficients for sine (2 * theta) fit.
   weights     = fltarr (numdeg)
   weights (*) = 1.0

   angle_ave_u = dblarr (numdeg)
   angle_ave_q = dblarr (numdeg)

   !p.multi    = [0,2,2]
   !p.charsize = 1.5
   !y.style    = 1

;-- Initialize guess for parameters.
;  as we loop we will use the parameters from the previous fit as a guess

;   fit in U and Q

;   a (0) = 0.012
;   a (1) = 0.25

;  fit in U/I and Q/I

   a (0) = 0.0033
   a (1) = 0.14

   factor = 1.00

   ;-- Constant sky bias.

   bias   = 0.0015 

   ;-- Sky bias as a function of radius.

;   bias_sky = fltarr (rnum)
;   bias_sky = [0.0000, 0.0000, 0.0005, 0.0008, 0.0008, $
;               0.0010, 0.0015, 0.0015, 0.0015, 0.0015, 0.0015]

   ;----------------------------------------------------------------------------
   ; Radius loop.
   ;----------------------------------------------------------------------------

   FOR ii = 0, rnum - 1 DO $
   BEGIN ;{
      angle_ave_u (*) = 0d0
      angle_ave_q (*) = 0d0

      ; Use solar radius: radsun = radius in arcsec.

      radstep = 0.10
      r_in    = (r_init + ii * radstep)
      r_out   = (r_init + ii * radstep + radstep)

      r_in  = r_in  * radsun / platescale
      r_out = r_out * radsun / platescale
      radscan (ii) = (r_in + r_out) / 2.0

      ;-----------------------------------------
      ; Extract annulus and average all heights 
      ; at 'stepdeg' increments around the sun.
      ;-----------------------------------------

      ; Make new theta arrays in degrees.

      theta1_deg = theta1 * !radeg

      ; Define U/I and Q/I.

      umk4_int = umk4 / intensity
      qmk4_int = qmk4 / intensity
      
;      print, 'min/max (umk4):      ', minmax (umk4)
;      print, 'min/max (intensity): ', minmax (intensity)
;      print, 'mean (umk4), mean (intensity): ', mean (umk4), mean (intensity)

      j = 0
      FOR i = 0, 360 - stepdeg, stepdeg DO $
      BEGIN ;{
         angle = float (i)
         pick1 = where (rr1 GE r_in AND rr1 LE r_out $
	                AND theta1_deg GE angle $
                        AND theta1_deg LT angle + stepdeg, nnl1)
         IF (nnl1 GT 0) THEN $
         BEGIN ;{
            angle_ave_u (j) = mean ( umk4_int (pick1) )
            angle_ave_q (j) = mean ( qmk4_int (pick1) )
         ENDIF ;}
         j = j + 1
      ENDFOR ;}

      sky_polar_cam1 = curvefit (degrees, double (angle_ave_u), weights, a, $
                                 FUNCTION_NAME = 'sine2theta_new')

;      print, 'angle_ave_u (0)', angle_ave_u (0)
;      print, 'fit coeff : ', a (0), a (1) * !radeg

      amplitude1 (ii) = a (0)
      phase1 (ii)     = a (1)
      mini = -0.15
      maxi =  0.15

      IF (doplot EQ 1) THEN $
      BEGIN ;{
         loadct, 39
         plot,  degrees  *!radeg,  angle_ave_u, thick=2, title='U', ystyle=1
         oplot, degrees * !radeg, sky_polar_cam1, color=100, thick=5
         oplot, degrees * !radeg, a(0) * factor * sin (2.0 * degrees + a(1)), $
                lines=2,thick=5, color=50
         wait,1
         plot,  degrees * !radeg, angle_ave_q, thick=2, title='Q', ystyle=1
         oplot, degrees * !radeg, a(0) * sin(2.0*degrees +90./!radeg + a(1)), $
	        color=100, thick=5
         oplot, degrees * !radeg, $
	        a(0) * factor * sin (2.0*degrees +90./!radeg + a(1)) + bias , $
		lines=2, color=50, thick=5
         wait, 0.4
         loadct, 0
         pause
      ENDIF ;}

   ENDFOR ;}
   ;----------------------------------------------------------------------------

   mean_phase1 = mean (phase1)

;   radial_amplitude1 = interpol (amplitude1, radscan, rr1,/spline)
;   radial_amplitude1 = interpol (amplitude1, radscan, rr1, /quadratic)

   ;--- Force the fit to be a straight line.

   afit_amplitude    = poly_fit (radscan, amplitude1, 1, afit)
   radial_amplitude1 = interpol (afit, radscan, rr1, /quadratic)

;   afit_bias  = poly_fit (radscan, bias_sky, 1, biasfit)
;   bias_image = interpol (biasfit, radscan, rr1, /quadratic)

   IF (doplot EQ 1) THEN $
   BEGIN ;{
      plot, rr1 (*, 500) * platescale / (radsun), $
            radial_amplitude1 (*, 500), $
	    xtitle='distance (solar radii)', $
            ytitle='amplitude', title='CAMERA 1'
      oplot, radscan * platescale / (radsun), amplitude1, psym=2
      wait,1
   ENDIF ;}

   radial_amplitude1 = reform (radial_amplitude1, xsize, ysize)

;   bias_image        = reform (bias_image, xsize, ysize)
;   tv, bytscl (bias_image, 0.0, 0.002)
;   save = tvrd ()
;   write_gif, 'bias_image.gif', save

   IF (doplot EQ 1)THEN $
   BEGIN ;{
      tvscl, radial_amplitude1
      wait, 1
   END   ;} 

   sky_polar_u1 = radial_amplitude1 * sin (2.0 * theta1 + mean_phase1)
   sky_polar_q1 = radial_amplitude1 * sin (2.0 * theta1 + 90.0 / !radeg $
                                           + mean_phase1 ) + bias

;   sky_polar_q1 = radial_amplitude1 * sin (2.0 * theta1 + 90.0 / !radeg $
;                                           + mean_phase1 ) + bias_image

   qmk4_new = qmk4 - factor * sky_polar_q1 * intensity
   umk4_new = umk4 - factor * sky_polar_u1 * intensity

   IF (doplot EQ 1) THEN $
   BEGIN ;{
      tv, bytscl (qmk4_new, -1, 1)
      draw_circle, xctr1, yctr1, radius_1, thick=4, color=0,  /dev
      FOR i=0, rnum-1 DO draw_circle, xctr1, yctr1, radscan (i), /dev
      FOR ii=0,numdeg-1 DO plots, [xctr1, xctr1 + 500 * cos (degrees(ii))], $
                                  [yctr1, yctr1 + 500 * sin (degrees(ii))], $
				  /dev
      pause
      wait,1
   ENDIF ;}

;   print, 'Finished sky polarization removal.'

   ; Add beams U and Q - with no sky polarizatio correction - linear pol.

   corona0 = sqrt (qmk4^2 + umk4^2)	

   ; Add beams U and Q - with sky polarizatio correction - linear pol.

   corona2 = sqrt (qmk4_new^2 + umk4_new^2)           

   ; Add beams only Q - with sky polarizatio correction pB.

   corona =  sqrt (qmk4_new^2)                        

   ;-------------------------------
   ; Use mask to build final image.
   ;-------------------------------

   r_in = fix (occulter / platescale) + 5.0
   r_out = 504.0

   bad = where (rad1 LT r_in OR rad1 GE r_out)
   corona  (bad) = 0
   corona2 (bad) = 0
   corona0 (bad) = 0

   cbias = 0.02
   corona_bias = corona + cbias
   corona_bias (bad) = 0

   IF (doplot EQ 1) THEN $
   BEGIN ;{
      wset,0
      tv, bytscl (sqrt (corona), 0.0, 1.5)
      pause
   END   ;}

   lct, '/hao/acos/sw/colortable/quallab_ver2.lut'      ; color table.
   tvlct, red, green, blue, /get

   mini = 0.00
   maxi = 1.20

   test = (corona + 0.03) ^ 0.8
   test (bad) = 0

   IF (doplot EQ 1) THEN $
   BEGIN ;{
      tv, bytscl (test,  min = mini, max = maxi)
      pause
   END   ;}

;   print, 'Finished.'

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
; End of new beam combination modifications.
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

   ; photosphere height = apparent diameter of sun [arcseconds] 
   ;                      divided by platescale [arcseconds / pixel]
   ;                    * radius of occulter [pixels] :

   r_photo = radsun / platescale

;   PRINT,        'Radius of photosphere [pixels] : ', r_photo
;   PRINTF, ULOG, 'Radius of photosphere [pixels] : ', r_photo

   ;--- Load color table.

   lct,   '/hao/acos/sw/colortable/quallab_ver2.lut'	; color table.
   tvlct, red, green, blue, /get

   ;----------------------------------------------------------------------------
   ; Display image, annotate, and save as a full resolution GIF file.
   ;----------------------------------------------------------------------------

   ; mini = -.02 ; USED FOR MARCH 10, 2014
   ; maxi =  0.5 ; USED FOR MARCH 10, 2014
   ; maxi =  1.2 ; maximum intensity scaling value.  Used < 28 jan 2015.

   ; mini =  0.0 ; minimum intensity scaling value.  Used <  11 Mar 2015.
   ; maxi =  1.8 ; maximum intensity scaling value.  Used 28 Jan - 10 Mar 2015.
   ; exp  =  0.8 ; scaling exponent.                 Used 28 Jan - 10 Mar 2015.

   mini = 0.1    ; minimum intensity scaling value.  Used >= 11 Mar 2015.
   maxi = 1.4    ; maximum intensity scaling value.  Used >= 11 Mar 2015.
   exp  = 0.7    ; scaling exponent.                 Used >= 11 Mar 2015.
   
   mini  = 0.0	; minimum intensity scaling value.  Used >= 09 Apr 2015.
   maxi  = 1.2	; maximum intensity scaling value.  Used >= 09 Apr 2015.
   exp   = 0.7	; scaling exponent.                 Used >= 09 Apr 2015.

;   cbias = 0.03
;   tv, bytscl ((corona + cbias)^exp, min = mini, max = maxi)

   tv, bytscl ((corona_bias)^exp, min = mini, max = maxi)

   corona_int = intarr (1024, 1024)
   corona_int = fix (1000 * corona)

   corona_min    = min (corona)
   corona_max    = max (corona)
   corona_median = median (corona)

   icorona_min    = min (corona_int)
   icorona_max    = max (corona_int)
   icorona_median = median (corona_int)

;   PRINT, 'corona      min, max, median :', $
;          corona_min, corona_max, corona_median
;   PRINT, 'corona*1000 min, max, median :', $
;          icorona_min, icorona_max, icorona_median
;   PRINT, 'mini, maxi, exp: ', mini, maxi, exp
;
;   PRINT, minmax (corona), median (corona)
;   PRINT, minmax (corona_int), median (corona_int)
;
;   PRINTF, ULOG, 'corona      min, max, median :', $
;                 corona_min, corona_max, corona_median
;   PRINTF, ULOG, 'corona*1000 min, max, median :', $
;                 icorona_min, icorona_max, icorona_median
;   PRINTF, ULOG, 'mini, maxi, exp: ', mini, maxi, exp
;
;   PRINTF, ULOG, minmax (corona), median (corona)
;   PRINTF, ULOG, minmax (corona_int), median (corona_int)

   xyouts, 4, 990, 'MLSO/HAO/KCOR', color = 255, charsize = 1.5, /device
   xyouts, 4, 970, 'K-Coronagraph', color = 255, charsize = 1.5, /device
   xyouts, 512, 1000, 'North', color = 255, charsize = 1.2, alignment = 0.5, $
           /device
   xyouts, 1018, 995, string (format = '(a2)', day) + ' ' + $
           string (format = '(a3)', name_month) + $
           ' ' + string(format = '(a4)', year), /device, alignment = 1.0, $
	   charsize = 1.2, color = 255
   xyouts, 1010, 975, 'DOY ' + string(format = '(i3)', doy), /device, $
           alignment = 1.0, charsize = 1.2, color = 255
   xyouts, 1018, 955, string (format = '(a2)', hour) + ':' + $
           string (format = '(a2)', minute) + $
           ':' + string(format = '(a2)', second) + ' UT', /device, $
	   alignment = 1.0, charsize = 1.2, color = 255
   xyouts, 22, 512, 'East', color = 255, charsize = 1.2, alignment = 0.5, $
           orientation = 90., /device
   xyouts, 1012, 512, 'West', color = 255, charsize = 1.2, alignment = 0.5, $
           orientation = 90., /device
   xyouts, 4, 46, 'Level 1 data', color = 255, charsize = 1.2, /device
   xyouts, 4, 26, 'min/max: ' + string (format = '(f3.1)', mini) + ', ' + $
           string (format = '(f3.1)', maxi), $
           color = 255, charsize = 1.2, /device
   xyouts, 4, 6, 'scaling: Intensity ^ ' + string (format = '(f3.1)', exp), $
           color = 255, charsize = 1.2, /device
   xyouts, 1018, 6, 'Circle = photosphere.', $
           color = 255, charsize = 1.2, /device, alignment = 1.0

   ;--- Image has been shifted to center of array.
   ;--- Draw circle at photosphere.

   tvcircle, r_photo, 511.5, 511.5, color = 255, /device

   device, decomposed = 1 
   save     = tvrd ()
   gif_file = 'l1.gif'
   gif_file = strmid (l0_file, 0, 20) + '.gif'
   write_gif, l1_dir + gif_file, save, red, green, blue

   ;----------------------------------------------------------------------------
   ; CREATE A FITS IMAGE:
   ; Burkepile: Some of this code comes from Sitongias update_header_l1.pro 
   ; and _l2.pro programs
   ;
   ; Need to keep level 0 headers and add additional quantities.
   ; Level 0 headers are stored in string variable = header
   ; Need to reorganize the header so that it reads well, e.g. group related 
   ; information togtherer
   ; and put all comments and history at the bottom of the header
   ;
   ; Compute solar ephemeris quantities from date and time
   ;----------------------------------------------------------------------------
   ; GdT: Removed the code below, all ephemeris are computed at the
   ; beginning using sun.pro
   ;
   ;date_str = fxpar (header, 'DATE-OBS')
   ;times    = anytim2tai (date_str)
   ;jdstruct = anytim2jd (times)
   ;jd       = jdstruct.int + jdstruct.frac
   ;ephem2, jd, sol_ra, sol_dec, b0, p_angle, semi_diam, sid_time, $
   ;        dist, xsun, ysun, zsun
   ;
   ; ephem2 doesn't give carrington longitude and rotation number. 
   ; Get that using jd_carr_long:
   ;
   ;julian_date = julday (month, day, year, hour, minute, second)
   ;jd_carr_long, julian_date, carrington_rotnum, carrington_long
   ;----------------------------------------------------------------------------

   ;****************************************************************************
   ; BUILD NEW HEADER: reorder old header and insert new information.
   ;****************************************************************************
   ; Enter the info from the level 0 header and insert ephemeris and comments
   ; in proper order. Remove information from level 0 header that is 
   ; NOT correct for level 1 and 2 images
   ; For example:  NAXIS = 4 for level 0 but NAXIS =  2 for level 1&2 data. 
   ; Therefore NAXIS3 and NAXIS4 fields are not relevent for level 1 and 2 data.
   ;----------------------------------------------------------------------------
   ; ISSUES TO DEAL WITH: 
   ;----------------------------------------------------------------------------
   ; 1. 01ID objective lens id added on June 18, 2014 
   ; 2. On June 17, 2014 19:30 Allen reports the Optimax 01 was installed. 
   ;    Prior to that date the 01 was from Jenoptik
   ;    NEED TO CHECK  THE EXACT TIME NEW OBJECTIVE WENT IN BY OBSERVING 
   ;    CHANGES IN ARTIFACTS 
   ;    IT MAY HAVE BEEN INSTALLED EARLIER IN DAY
   ; 3. IDL stuctures turn boolean 'T' and 'F' into integers (1, 0); 
   ;    need to turn back to boolean to meet FITS headers standards.
   ; 4. structures don't accept dashes ('-') in keywords which are FITS header 
   ;    standards (e.g. date-obs). 
   ;    use /DASH2UNDERSCORE  
   ; 5. structures don't save comments. Need to type them back in.
   ;----------------------------------------------------------------------------

   newheader    = strarr (200)
   newheader(0) = header(0)         ; contains SIMPLE keyword
   sxaddpar, newheader, 'BITPIX',   struct.bitpix, ' bits per pixel'
   sxaddpar, newheader, 'NAXIS', 2, ' number of dimensions; FITS image' 
   sxaddpar, newheader, 'NAXIS1',   struct.naxis1, ' (pixels) x dimension'
   sxaddpar, newheader, 'NAXIS2',   struct.naxis2, ' (pixels) y dimension'
   sxaddpar, newheader, 'DATE-OBS', struct.date_d$obs, ' UTC observation start'
   sxaddpar, newheader, 'DATE-END', struct.date_d$end, ' UTC observation end'
   sxaddpar, newheader, 'TIMESYS',  'UTC', $
                        ' date/time system: Coordinated Universal Time'
   sxaddpar, newheader, 'LOCATION', 'MLSO', $
                        ' Mauna Loa Solar Observatory, Hawaii'
   sxaddpar, newheader, 'ORIGIN',   struct.origin, $
                        ' Nat.Ctr.Atmos.Res. High Altitude Observatory'
   sxaddpar, newheader, 'TELESCOP', 'COSMO K-Coronagraph'
   sxaddpar, newheader, 'INSTRUME', 'COSMO K-Coronagraph'
   sxaddpar, newheader, 'OBJECT',   struct.object, $
                        ' white light polarization brightness'
   sxaddpar, newheader, 'DATATYPE', struct.datatype, ' type of data acquired'
   sxaddpar, newheader, 'OBSERVER', struct.observer, $
                        ' name of Mauna Loa observer'
   sxaddpar, newheader, 'LEVEL',    'L1', $
                        ' Level 1 intensity is quasi-calibrated'
   sxaddpar, newheader, 'DATE-L1', datecal(), ' Level 1 processing date'
   sxaddpar, newheader, 'CALFILE', cal_file, $
                        ' calibration file'
;                        ' calibration file:dark, opal, 4 pol.states'
   sxaddpar, newheader, 'DISTORT', dc_file, ' distortion file'
   sxaddpar, newheader, 'L1SWID',   'kcorl1s.pro 10apr2015', $
                        ' Level 1 software'
   sxaddpar, newheader, 'DMODSWID', '18 Aug 2014', $
                        ' date of demodulation software'
   sxaddpar, newheader, 'OBSSWID',  struct.obsswid, $
                        ' version of the observing software'
   sxaddpar, newheader, 'BZERO',    struct.bzero, $
                        ' offset for unsigned integer data'
   sxaddpar, newheader, 'BSCALE',   struct.bscale, $
             ' physical = data * BSCALE + BZERO', format = '(f8.2)'
   sxaddpar, newheader, 'WCSNAME',  'helioprojective-cartesian', $
                        'World Coordinate System (WCS) name'
   sxaddpar, newheader, 'CTYPE1',   'HPLN-TAN', $
                        ' [deg] helioprojective west angle: solar X'
   sxaddpar, newheader, 'CRPIX1',   xcen, $
                        ' [pixel]  solar X sun center (FITS=1+IDL value)', $
			format='(f9.2)'
   sxaddpar, newheader, 'CRVAL1',   0.00, ' [arcsec] solar X sun center', $
			format='(f9.2)'
   sxaddpar, newheader, 'CDELT1',   platescale, $
                        ' [arcsec/pix] solar X increment = platescale', $
			format='(f9.4)'
   sxaddpar, newheader, 'CUNIT1',   'arcsec'
   sxaddpar, newheader, 'CTYPE2',   'HPLT-TAN', $
                        ' [deg] helioprojective north angle: solar Y'
   sxaddpar, newheader, 'CRPIX2',   ycen, $
                        ' [pixel]  solar Y sun center (FITS=1+IDL value)', $
			format='(f9.2)'
   sxaddpar, newheader, 'CRVAL2',   0.00, ' [arcsec] solar Y sun center', $
			format='(f9.2)'
   sxaddpar, newheader, 'CDELT2',   platescale, $
                        ' [arcsec/pix] solar Y increment = platescale', $
			format='(f9.4)'
   sxaddpar, newheader, 'CUNIT2',   'arcsec'
   sxaddpar, newheader, 'INST_ROT', 0.00, $
                        ' [deg] rotation of the image wrt solar north', $
			format='(f9.3)'
   sxaddpar, newheader, 'PC1_1',    1.00, $
                        ' coord transform matrix element (1, 1) WCS std.', $
			format='(f9.3)'
   sxaddpar, newheader, 'PC1_2',    0.00, $
                        ' coord transform matrix element (1, 2) WCS std.', $
			format='(f9.3)'
   sxaddpar, newheader, 'PC2_1',    0.00, $
                        ' coord transform matrix element (2, 1) WCS std.', $
			format='(f9.3)'
   sxaddpar, newheader, 'PC2_2',    1.00, $
                        ' coord transform matrix element (2, 2) WCS std.', $
			format='(f9.3)'
  
   ;----------------------------------------------------------------------------
   ; Add ephemeris data to new newheader.
   ;----------------------------------------------------------------------------

   sxaddpar, newheader, 'RSUN',     radsun, $
                        ' [arcsec] solar radius', format = '(f9.3)'
   sxaddpar, newheader, 'SOLAR_P0', pangle, $
                        ' [deg] solar P angle',   format = '(f9.3)'
   sxaddpar, newheader, 'CRLT_OBS', bangle, $
                        ' [deg] solar B angle: Carr. latitude ', $
			format = '(f8.3)'
   sxaddpar, newheader, 'CRLN_OBS', carrington_long, $
                        ' [deg] solar L angle: Carr. longitude', $
			format = '(f9.3)'
   sxaddpar, newheader, 'CAR_ROT',  carrington_rotnum, $
                        ' Carrington rotation number', format = '(i4)'
   sxaddpar, newheader, 'SOLAR_RA', sol_ra, $
                        ' [h]   solar Right Ascension (hours)', $
			format = '(f9.3)'
   sxaddpar, newheader, 'SOLARDEC', sol_dec, $
                        ' [deg] solar Declination (deg)', format = '(f9.3)'

   ;----------------------------------------------------------------------------
   ; Add keywords about instrument hardware.
   ;----------------------------------------------------------------------------

   sxaddpar, newheader, 'WAVELNTH', 735, $
                        ' [nm] center wavelength   of bandpass filter', $
	                format = '(i4)'
   sxaddpar, newheader, 'WAVEFWHM', 30, $
                        ' [nm] full width half max of bandpass filter', $
	                format = '(i3)'
   sxaddpar, newheader, 'DIFFUSER', struct.diffuser, $
                        ' diffuser in or out of the light beam'
   sxaddpar, newheader, 'DIFFSRID', struct.diffsrid, $
                        ' unique ID of the current diffuser'
   sxaddpar, newheader, 'CALPOL',   struct.calpol, $
                        ' calibration polarizer in or out of beam'
   sxaddpar, newheader, 'CALPANG',  struct.calpang, $
                        ' calibration polarizer angle', format='(f9.3)'
   sxaddpar, newheader, 'CALPOLID', struct.calpolid, $
                        ' unique ID of current polarizer'
   sxaddpar, newheader, 'DARKSHUT', struct.darkshut, $
                        ' dark shutter open(out) or closed(in)'
   sxaddpar, newheader, 'EXPTIME',  struct.exptime*1.e-3, $
                        ' [s] exposure time for each frame', format = '(e9.2)'
   sxaddpar, newheader, 'NUMSUM',   struct.numsum, $
                        ' # frames summed per camera & polarizer state'
   sxaddpar, newheader, 'RCAMID',   'MV-D1024E-CL-11461', $
                        ' unique ID of camera 0 (reflected)'
   sxaddpar, newheader, 'TCAMID',   'MV-D1024E-CL-13889', $
                        ' unique ID of camera 1 (transmitted)' 
   sxaddpar, newheader, 'RCAMLUT',  '11461-20131203', $
                        ' unique ID of LUT for camera 0'
   sxaddpar, newheader, 'TCAMLUT',  '13889-20131203', $
                        ' unique ID of LUT for camera 1'
   sxaddpar, newheader, 'RCAMFOCS', struct.rcamfocs, $
                        ' [mm] camera 0 focus position', format='(f9.4)'
   sxaddpar, newheader, 'TCAMFOCS', struct.tcamfocs, $
                        ' [mm] camera 1 focus position', format='(f9.4)'
   sxaddpar, newheader, 'MODLTRT',  struct.modltrt, $
                        ' [deg C] modulator temperature', format = '(f8.3)'
   sxaddpar, newheader, 'MODLTRID', struct.modltrid, $
                        ' unique ID of the current modulator'

   ;----------------------------------------------------------------------------
   ; Ben added keyword 'O1ID' (objective lens id) on June 18, 2014 
   ; to accommodate installation of Optimax objective lens.
   ;----------------------------------------------------------------------------

   IF (year LT 2014) THEN $
      sxaddpar, newheader, 'O1ID',     'Jenoptik', $
                           ' unique ID of objective (01) lens'

   IF (year EQ 2014) THEN $
   BEGIN ;{
      if (month lt 6) then $
         sxaddpar, newheader, 'O1ID',     'Jenoptik', $
	                      ' unique ID of objective (01) lens'
      if (month eq 6) and (day lt 17) then $
         sxaddpar, newheader, 'O1ID',     'Jenoptik', $
	                      ' unique ID of objective (01) lens'
      if (month eq 6) and (day ge 17) then $
         sxaddpar, newheader, 'O1ID',     'Optimax', $
	                      ' unique ID of objective (01) lens'
      if (month gt 6) then $
         sxaddpar, newheader, 'O1ID',     'Optimax', $
	                      ' unique ID of objective (01) lens'
   ENDIF ;}

   IF (year gt 2014) then $
      sxaddpar, newheader, 'O1ID',     struct.o1id, $
                           ' unique ID of objective (01) lens' 

   sxaddpar, newheader, 'O1FOCS',   struct.o1focs, $
                        ' [mm] objective lens (01) focus position', $
			format = '(f8.3)'
   sxaddpar, newheader, 'COVER',    struct.cover, $
                        ' cover in or out of the light beam'
   sxaddpar, newheader, 'OCCLTRID', struct.occltrid, $
                        ' unique ID of current occulter'
   sxaddpar, newheader, 'FILTERID', struct.filterid, $
                        ' unique ID of current bandpass filter'
   sxaddpar, newheader, 'SGSDIMV',  struct.sgsdimv, $
                        ' [V] mean Spar Guider Sys. (SGS) DIM signal', $
			format = '(f9.4)'
   sxaddpar, newheader, 'SGSDIMS',  struct.sgsdims, $
                        ' [V] SGS DIM signal standard deviation', $
			format = '(e11.3)'
   sxaddpar, newheader, 'SGSSUMV',  struct.sgssumv, $
                        ' [V] mean SGS sum signal',          format = '(f9.4)'
   sxaddpar, newheader, 'SGSRAV',   struct.sgsrav, $
                        ' [V] mean SGS RA error signal',     format = '(e11.3)'
   sxaddpar, newheader, 'SGSRAS',   struct.sgsras, $
                        ' [V] mean SGS RA error standard deviation', $
			format = '(e11.3)'
   sxaddpar, newheader, 'SGSRAZR',  struct.sgsrazr, $
                        ' [arcsec] SGS RA zeropoint offset', format = '(f9.4)'
   sxaddpar, newheader, 'SGSDECV',  struct.sgsdecv, $
                        ' [V] mean SGS DEC error signal',    format = '(e11.3)'
   sxaddpar, newheader, 'SGSDECS',  struct.sgsdecs, $
                        ' [V] mean SGS DEC error standard deviation', $
			format = '(e11.3)' 
   sxaddpar, newheader, 'SGSDECZR', struct.sgsdeczr, $ 
                        ' [arcsec] SGS DEC zeropoint offset', format = '(f9.4)'
   sxaddpar, newheader, 'SGSSCINT', struct.sgsscint, $
                        ' [arcsec] SGS scintillation seeing estimate', $
			format = '(f9.4)'
   sxaddpar, newheader, 'SGSLOOP',  struct.sgsloop, ' SGS loop closed fraction'
   sxaddpar, newheader, 'SGSSUMS',  struct.sgssums, $
                        ' [V] SGS sum signal standard deviation', $
			format = '(e11.3)'

   sxaddpar, newheader, 'COMMENT', $
      ' The COSMO K-coronagraph is a 20-cm aperture, internally occulted'
   sxaddpar, newheader, 'COMMENT', $
      ' coronagraph that observes the polarization brightness of the corona'
   sxaddpar, newheader, 'COMMENT', $
      ' with a field-of-view from ~1.05 to 3 solar radii in a wavelength range'
   sxaddpar, newheader, 'COMMENT', $
      ' from 720 to 750 nm. Nominal time cadence is 15 seconds.'
  
   ;----------------------------------------------------------------------------
   ; Add History.
   ;----------------------------------------------------------------------------

   sxaddhist, $
     'Level 1 processing performed: dark current subtracted, gain correction,',$
      newheader
   sxaddhist, $
     'polarimetric demodulation, coordinate transformation from cartesian to', $
      newheader
   sxaddhist, $
     'tangent/radial, preliminary removal of sky polarization, ',$
      newheader
   sxaddhist, $
     'image distortion correction, beams combined, Platescale calculated.', $
      newheader
   IF (struct.extend eq 0) then val_extend = 'F'
   IF (struct.extend eq 1) then val_extend = 'T'
   sxaddpar, newheader, 'EXTEND', 'F', ' No FITS extensions'

   ;----------------------------------------------------------------------------
   ; For FULLY CALIBRATED DATA:  ADD THESE WHEN READY
   ;  sxaddpar, newheader, 'BUNIT', '10^-6 Bsun', $
   ;                       ' Millionths of Solar brightness'
   ;  sxaddpar, newheader, 'BUNIT', 'MILLIONTHS', $
   ;                       ' Millions of brightness of solar disk'
   ;  sxaddpar, newheader, 'BOPAL', '1.38e-05', $
   ;                       ' Opal Transmission Calibration by Elmore at 775 nm'
   ; sxaddhist, $
   ; 'Level 2 processing performed: sky polarization removed, alignment to ', $
   ; newheader
   ; sxaddhist, $
   ; 'solar north calculated, polarization split in radial and tangential ', $
   ;  newheader
   ; sxaddhist, $
   ; 'components.  For detailed information see the COSMO K-coronagraph ', $
   ; newheader
   ; sxaddhist, 'data reduction paper (reference).', newheader
   ; sxaddpar, newheader, 'LEVEL', 'L2', ' Processing Level'
   ; sxaddpar, newheader, 'DATE-L2', datecal(), ' Level 2 processing date'
   ; sxaddpar, newheader, 'L2SWID', 'Calib Reduction Mar 31, 2014', $
   ;           ' Demodulation Software Version'
   ;----------------------------------------------------------------------------

   ;--- ADD IMAGE DISTORTION FILE KEYWORD.
  
   ;--- Write FITS image to disc.

   l1_file = strmid (l0_file, 0, 20) + '_l1.fts'
   writefits, l1_dir + l1_file, corona_int, newheader
   ;----------------------------------------------------------------------------

   ;----------------------------------------------------------------------------
   ; Now make low resolution GIF file:
   ;
   ; Use congrid to rebin to 768x768 (75% of original size) 
   ; and crop around center to 512 x 512 image.
   ;----------------------------------------------------------------------------

   rebin_img = fltarr (768, 768)
   rebin_img = congrid (corona_bias, 768, 768)

   crop_img = fltarr (512, 512)
   crop_img = rebin_img (128:639, 128:639)

;   window, 0, xs = 512, ys = 512, retain = 2

   set_plot='Z'
   erase
   device, set_resolution=[512,512], decomposed=0, set_colors=256, $
           z_buffering=0
   erase
   tv, bytscl ((crop_img)^exp, min = mini, max = maxi)

   xyouts, 4, 495, 'MLSO/HAO/KCOR', color = 255, charsize = 1.2, /device
   xyouts, 4, 480, 'K-Coronagraph', color = 255, charsize = 1.2, /device
   xyouts, 256, 500, 'North', color = 255, $
           charsize = 1.0, alignment = 0.5, /device
   xyouts, 507, 495, string (format = '(a2)', day) + ' ' + $
           string (format = '(a3)', name_month) + $
           ' ' + string(format = '(a4)', year), /device, alignment = 1.0, $
	   charsize = 1.0, color = 255
   xyouts, 500, 480, 'DOY ' + string (format = '(i3)', doy), $
           /device, alignment = 1.0, charsize = 1.0, color = 255
   xyouts, 507, 465, string (format = '(a2)', hour) + ':' + $
           string (format = '(a2)', minute) + ':' + $
	   string (format = '(a2)', second) + ' UT', /device, alignment = 1.0, $
	   charsize = 1.0, color = 255
   xyouts, 12, 256, 'East', color = 255, $
           charsize = 1.0, alignment = 0.5, orientation = 90., /device
   xyouts, 507, 256, 'West', color = 255, $
           charsize = 1.0, alignment = 0.5, orientation = 90., /device
   xyouts, 4, 34, 'Level 1 data', color = 255, charsize = 1.0, /device
   xyouts, 4, 20, 'min/max: ' + string (format = '(f3.1)', mini) + ', ' + $
           string (format = '(f3.1)', maxi), $
	   color = 255, charsize = 1.0, /device
   xyouts, 4, 6, 'scaling: Intensity ^ ' + string (format = '(f3.1)', exp), $
           color = 255, charsize = 1.0, /device
   xyouts, 508, 6, 'Circle = photosphere', color = 255, $
           charsize = 1.0, /device, alignment = 1.0

   r = r_photo*0.75    ;  image is rebined to 75% of original size
   tvcircle, r, 255.5, 255.5, color = 255, /device

   save = tvrd ()
   cgif_file = strmid (l0_file, 0, 20) + '_cropped.gif'
   write_gif, l1_dir + cgif_file, save, red, green, blue

   FLUSH, ULOG				; send buffered output to file.

   ; end of WHILE loop

   loop_time = TOC (lclock)
   PRINT,        '--- Loop  duration [sec]: ', loop_time
   PRINTF, ULOG, '--- Loop  duration [sec]: ', loop_time
ENDWHILE ;}

;--- Get system time & compute elapsed time since "TIC" command.

DONE: $
total_time = TOC ()
PRINT,        '--- Total duration [sec]: ', total_time
PRINTF, ULOG, '--- Total duration [sec]: ', total_time

IF (fnum NE 0)  THEN $
   image_time = total_time / fnum $
ELSE $
   image_time = 0.0

PRINT,        '    time/image:           ', image_time, '   # images: ', fnum
PRINTF, ULOG, '    time/image:           ', image_time, '   # images: ', fnum

;TOC, REPORT=report
;PRINT,       report[-1]
;PRINT, ULOG, report[-1]

PRINT,        '>>>>>>> End of kcorl1s <<<<<<<'
PRINTF, ULOG, '>>>>>>> End of kcorl1s <<<<<<<'
PRINTF, ULOG, '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'

CLOSE, ULIST
CLOSE, ULOG
FREE_LUN, ULIST
FREE_LUN, ULOG

END