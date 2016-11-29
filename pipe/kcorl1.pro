;+
; pro kcorl1
;-------------------------------------------------------------------------------
; :Author: Joan Burkepile [JB]
;-------------------------------------------------------------------------------
; :Description: Make semi-calibrated kcor images.
;-------------------------------------------------------------------------------
; :History:
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
; 15 Mar 2015 [JB]  Updated ncdf file from Jan 1, 2015 to March 15, 2015. 
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
; 29 May 2015 [ALS] Generate NRGF file via "kcor_nrgf.pro".
;                   Ben Berkey installed painted occulter (1018.9 arcsec).
;                   new calibration file: 20150529_180919_cal_1.0ms.ncdf
; 01 Jun 2015 [ALS] L1SWID = 'kcorl1r.pro 01jun2015'
; 15 Jul 2015 [ALS] Change BSCALE parameter from 1.0 to 0.001.  Prior to this
;                   date, the value of BSCALE needs to be changed to 0.001 .
;                   Delete DATE-L1 keyword (replaced by DATE_DP).
;                   Delete L1SWID keyword (replaced by DPSWID).
;                   Add DPSWID  keyword (data processing software ID). 
;                   set DPSWID='kcorl1v.pro 16jul2015'.
;                   Add DATE_DP keyword (data processing date).
;                   Add DATE-BEG keyword (same as DATE-OBS).
;                   Add DATAMIN, DATAMAX keywords.
;                   Add DISPMIN, DISPMAX, DISPEXP keywords.
;                   Add XPOSURE keyword (total exposure for image).
;                   DATASUM & CHECKSUM keywords not yet implemented.
; 24 Sep 2015 [ALS] Add QUALITY keyword (image quality).
;                   Add RCAM_XCEN keyword (reflected camera x-center raw image).
;                   Add RCAM_YCEN keyword (reflected camera y-center raw image).
;                   Add RCAM_RAD keyword (reflected camera occ radius raw image)
;                   Add TCAM_XCEN keyword (transmit camera x-center raw image).
;                   Add TCAM_YCEN keyword (transmit camera y-center raw image).
;                   Add TCAM_RAD keyword (transmit camera occ radius raw image).
; 19 Oct 2015 [ALS] Replace DPSWID with L1SWID.
;                   Delete  DATE_DP keyword.
;                   Restore DATE-L1 keyword.
;                   Delete  DATE-BEG keyword.
;                   Delete  XPOSURE keyword.
;                   set L1SWID='kcorl1v.pro 19oct2015'.
;                   Rearrange keywords.
; 04 Nov 2015 [ALS] Add DATE_HST keyword (Hawaii Standart Time date: yyyy-mm-dd)
;                   Replace L1SWID  with DPSWID='kcorl1v.pro 04nov2015'.
;                   Replace DATE-L1 with DATE_DP.
; 10 Dec 2015 [ALS] Change name to kcorl1.pro.
;                   DPSWID='kcorl1.pro 10dec2015'.
; 14 Dec 2015 [ALS] Add comment to telescop keyword.
;                   set rcamfocs = tcamfocs = 0.0 if level0 values are 'NaN'.
;                   DPSWID='kcorl1.pro 14dec2015'.
; 26 Jan 2016 [ALS] Modify all paths to be in non-user directories.
;		    Use color table in /hao/acos/sw/idl/color.
; 04 Mar 2016 [ALS] Use kcor_nrgf.pro to generate both gif & FITS RG files.
;-------------------------------------------------------------------------------
;   Make semi-calibrated kcor images.
;-------------------------------------------------------------------------------
; 1. Uses a coordinate transform to a mk4-q like image. Need to find a better 
;    way to identify the phase angle.
;*** I am setting a variable called 'phase' to try to minimize coronal signal 
;    in unwanted polarization image.
;*** I have added a bias in order to help remove dark areas.
;*** Vignetting is OFF!!!!!!!
;*** Using only fraction of sky polarization removal.
;
;    I am only removing sky from Q and U. Need to remove it from I as well 
;    at a later date.
;
; 2. FUTURE: Alfred needs to add the Elmore calibration of Mk4 Opal 
; 3. Alfred still testing cameras to remove unwanted zeros in creating ncdf file
; 4. Need to streamline code and minimize number of interpolations.
; 5. Speed up vignetting BY using Giluiana's suggestion of creating a
;    vignetting image and doing matrix multiplication to apply to image.
;
; Order of processing: 
; 1. Apply Alfred's Demodulation Matrix
; 2. Find Image Centers for Each Camera
; 3. Apply Co-ordinate Transformation to get to Tangential (with respect to 
;    solar limb) Polarization ('mk4-q') and polarization 45 degrees from 
;    tangential ('mk4-u').
;    Ideally, tangential image will contain all corona + sky polarization and 
;    image polarized 45 deg.to tangential will contain only sky polarization.
;  
; FINAL CORONAL IMAGE: Only uses mk4-q like data. 
; There is still a small residual coronal signal in mk4-u like images,
; but they contain mostly noise.
;      
;--- History of instrument changes which affect calibration and processing ---
;
; [JB] I have hardwired certain parameters to best process images acquired 
; between Oct 2013 and present (May 2014).
; By 3rd week of Oct 2013, the instrument software was finally operating
; to give consistent sequences of polarization images by running socketcam
; continuously. Prior to that time, data may not be usable, since we are
; not sure of the order of polarization states 
;
; CHANGES: 
; BZERO in header Oct 15, and Oct 31 =  2147483648 = 2^15
; OCCLTRID value changes. Prior to ??? it was 'OC-1'. 
; I believe this is occulter 1018.9". Need to verify.
; On Oct 15, the header value for modulator temperture is 512.0 deg C. 
; That's nuts. It should be 35 deg C.
; Oct 20: Ben reports changing zero offset(BZERO). It was initially set at 
; 16 bit (65536, 32768)
;
; Other things to check: integrity of SGS values
;
; FUTURE: Need to check occulter size and exposure to determine appropriate 
; NCDF file.
; CURRENTLY: Hardwired.
; Short cut could be to read date of file to determine which ncdf calibration 
; file to pick up.
; As of now (May 2014), we have used 1 msec exposures as the standard,
; since the mk4 opal went in back in early November 2013, so all ncdf files
; so far have same exposure.
; Occulters: There are 3 Kcor occulters. Dates of changes are: 
; r = 1018.9" occulter installed 30 October 2013 21:02 to 28 March 2014 16:59
; r = 1006.9" installed for a few minutes only on 28 Jan 2014 01:09:13 
;             installed 28 March 2014 17:00:09 to 28 Apr 2014 16:42
; r =  996.1" installed 28 April 2014 16:43:47
;------------------------------------------------------------------------------
; Functions and other programs called: 
;------------------------------------------------------------------------------
; :Uses:
;
; apply_dist         (/hao/acos/sw/idl/kcor/pipe; tomczyk)
; datecal            (/hao/acos/sw/idl/kcor/pipe; sitongia)
; kcor_find_image    (/hao/acos/sw/idl/kcor/pipe; tomczyk/detoma)
; kcor_radial_der    (/hao/acos/sw/idl/kcor/pipe; tomczyk/detoma)
; fitcircle          (/hao/acos/sw/idl/kcor/pipe; Randy Meisner)
; fshift             (/hao/acos/sw/idl/kcor/pipe)
; jd_carr_long.pro   (/hao/acos/sw/idl/kcor/pipe)
;
; anytim2tai         (/hao/contrib/ssw/gen/idl/time)
; anytim2jd          (/hao/contrib/ssw/gen/idl/time)
; fitshead2struct    (/hao/contrib/ssw/gen/idl/fits)
; sun                (/hao/contrib/ssw/gen/idl/fund_lib/jhuapl)
;
; pb0r               (/hao/contrib/ssw/gen/idl/solar)
; ephem2             (/acos/sw/idl/gen dir)
;  
;-------------------------------------------------------------------------------
; Parameters used for various dates.
;-------------------------------------------------------------------------------
; --- 31 Oct 2013 ---
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
; :Params:
; date : in, required, type=string, 
;         format='yyyymmdd', where yyyy=year, mm=month, dd=day
;
; :Keywords:
; list : in, optional, type=string.  File containing a list of FITS Level0 files
;        
; base_dir: in, optional, type=string.  Directory containing Level 0 FITS files.
;
; append : in, optional.  If set, append log output to existing log file.
; 
; cal_dir : in, optional.  NCDF calibration file directory.
;
; cal_file : in, optional.  NCDF calibration file name.
;
; phase0 : in, optional.  Phase value for camera 0.
;
; phase1 : in, optional.  Phase value for camera 1.
;
; bias : in, optional.  Bias value.
;
; sky_factor: in, optional.  Sky factor value.
;
; dc_dir : in, optional.  Distortion correction directory.
;
; dc_file : in, optional.  Distorion correction file name.
;
; qual : in, optional, type=string.  Image quality.
;------------------------------------------------------------------------------
; :Examples:
; kcorl1, date_string, list='list_of_L0_files', $
;               base_dir='base_directory_path'
; kcorl1, 'yyyymmdd', list='L0_list', $
;               base_dir='/hao/mlsodata3/Data/KCor/raw/2015/'
; kcorl1, '20141101', list='list17'
; kcorl1, '20141101', list='list17', /append
; kcorl1, '20140731', list='doy212.ls',base_dir='/hao/mlsodata1/Data/KCor/work'
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
; All Level 1 files (fits & gif) will be stored in the sub-directory 'level1',
; under the date directory.
;------------------------------------------------------------------------------
;-

pro kcorl1, date_str, list=list, $
             base_dir=base_dir, append=append, $
             cal_dir=cal_dir, cal_file=cal_file, $
             phase0=phase0, phase1=phase1, bias=bias, $
             sky_factor=sky_factor, $
	     dc_dir=dc_dir, dc_file=dc_file, $
	     qual=qual

;--- Use TIC & TOC to determine elapsed duration of procedure execution.

TIC

;-------------------------------------------------------------------------------
; Default values for optional keywords.
;-------------------------------------------------------------------------------

default, cal_dir,   '/hao/mlsodata1/Data/KCor/calib_files'

; default, cal_file,  '20150101_190612_kcor_cal_1.0ms.ncdf' ; < 10 Mar 2015.
; Use 20150315 file >= March 10, 2015 due to color corrector lens changes
; by Dennis G.
;
;default, cal_file,  '20150315_202646_kcor_cal_1.0ms.ncdf'   
;
; Use 20150403_203428_ALL_ANGLES_kcor_1ms_new_dark.ncdf after 03 Apr 2015 20:12.
; default, cal_file,  '20150403_203428_ALL_ANGLES_kcor_1ms_new_dark.ncdf'   
;
; Use 20150529_180919_cal_1.0ms.ncdf for 29 May 2015 & beyond.

default, cal_file,  '20150529_180919_cal_1.0ms.ncdf'   

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

;--------------------
; Define directories.
;--------------------

if NOT KEYWORD_SET (base_dir) then base_dir = '/hao/mlsodata1/Data/KCor/raw'

l0_dir   = base_dir + '/' + date_str			; level 0
l1_dir   = base_dir + '/' + date_str + '/level1/'	; level 1
l0_file  = ''
dc_path  = dc_dir + '/' + dc_file	; distortion correction pathname.

if (NOT FILE_TEST (l1_dir, /DIRECTORY)) then FILE_MKDIR, l1_dir

;-------------------------------------------------------------------------------
; Move to the processing directory.
;-------------------------------------------------------------------------------

cd, current=start_dir			; Save current directory.
cd, l0_dir				; Move to L0 processing directory

;-------------------------------------------------------------------------------
; Identify list of L0 files.
;-------------------------------------------------------------------------------

get_lun, ULIST
close,   ULIST

if (KEYWORD_SET (list)) then $
begin ;{
   listfile = list   
end $ ;}
else $
begin ;{
   listfile = l0_dir + 'l0_list'

;   openw,   ULIST, listfile
;   printf,  ULIST, 'test.fts'
;   close,   ULIST

   spawn, 'ls *kcor.fts* > l0_list'
end ;}

;-------------------------
; Get current date & time.
;-------------------------

current_time = systime (/UTC)

;-------------------------------------------------------------------------------
; Open log file.
;-------------------------------------------------------------------------------

logfile = date_str + '_l1_' + listfile + '.log'
get_lun, ULOG
close,   ULOG
if (keyword_set (append)) then $
   openw,   ULOG, l1_dir + logfile, /append $
else	$
   openw,   ULOG, l1_dir + logfile

;print,        '--- kcorl1 ', date_str, ' --- ', current_time
;print,        'l0_dir: ', l0_dir
;print,        'l1_dir: ', l1_dir

printf, ULOG, '--- kcorl1 ', date_str, ' --- ', current_time

;printf, ULOG, 'l0_dir: ', l0_dir
;printf, ULOG, 'l1_dir: ', l1_dir

;-------------------------------------------------------------------------------
; Check for empty list file.
;-------------------------------------------------------------------------------

nfiles = fix (file_lines (listfile))		; # files in list file.
if (nfiles EQ 0) then $
begin ;{
   print,        listfile, ' empty.  No files to process.'
   printf, ULOG, listfile, ' empty.  No files to process.'
   GOTO, DONE
end   ;}

;-------------------------------------------------------------------------------
; Extract information from calibration file.
;-------------------------------------------------------------------------------

calpath = cal_dir + '/' + cal_file

print,        'calpath: ', calpath
printf, ULOG, 'calpath: ', calpath

unit = ncdf_open (calpath)
  ncdf_varget, unit, 'Dark', dark_alfred
  ncdf_varget, unit, 'Gain', gain_alfred
  ncdf_varget, unit, 'Modulation Matrix', mmat
  ncdf_varget, unit, 'Demodulation Matrix', dmat
ncdf_close, unit

; FUTURE: Check matrix for any elements > 1.0
; I am only printing matrix for one pixel.

;print, 'Mod Matrix = camera 0'
;print, reform (mmat(100, 100, 0, *, *))
;print, 'Mod Matrix = camera 1'
;print, reform (mmat(100, 100, 1, *, *))

;printf, ULOG, 'Mod Matrix = camera 0'
;printf, ULOG, reform (mmat(100, 100, 0, *, *))
;printf, ULOG, 'Mod Matrix = camera 1'
;printf, ULOG, reform (mmat(100, 100, 1, *, *))

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

for b = 0, 1 do $
begin ;{
   gain_temp = double (reform (gain_alfred (*, *, b)))
   filter = mean_filter (gain_temp, 5, 5, invalid = gain_negative , missing=1)
   bad = WHERE (gain_temp EQ gain_negative, nbad)

   if (nbad GT 0) then $
   begin ;{
      gain_temp (bad) = filter (bad)
      gain_alfred (*, *, b) = gain_temp
   endif ;}
endfor ;}
gain_temp = 0

;----------------------------------------
; Find center and radius for gain images.
;----------------------------------------

; Set guess for radius - needed to find center.

radius_guess = 178		; average radius for occulter.

;printf, ULOG, 'radius_guess ', radius_guess

info_gain0 = kcor_find_image (gain_alfred (*, *, 0), radius_guess)
info_gain1 = kcor_find_image (gain_alfred (*, *, 1), radius_guess)

;------------------------------------------
; Define coordinate arrays for gain images.
;------------------------------------------

gxx0 = findgen (xsize, ysize) mod (xsize) - info_gain0 (0)
gyy0 = transpose (findgen (ysize, xsize) mod (ysize) ) - info_gain0 (1)

gxx0 = double (gxx0)  &  gyy0 = double (gyy0)
grr0 = sqrt (gxx0^2.0 + gyy0^2.0)  

gxx1 = findgen (xsize, ysize) mod (xsize) - info_gain1 (0)
gyy1 = transpose (findgen (ysize, xsize) mod (ysize) ) - info_gain1 (1)

gxx1 = double (gxx1)  &  gyy1 = double (gyy1)
grr1 = sqrt (gxx1^2.0 + gyy1^2.0)  

printf, ULOG, 'Gain 0 center and radius : ' , info_gain0
printf, ULOG, 'Gain 1 center and radius : ' , info_gain1

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

lct, '/hao/acos/sw/idl/color/quallab_ver2.lut'	; color table.
tvlct, red, green, blue, /get

;*******************************************************************************
;*******************************************************************************
; Image file loop.
;*******************************************************************************
;*******************************************************************************

fnum = 0
openr, ULIST, listfile

while (not EOF (ULIST) ) do $
begin ;{
   fnum += 1
   lclock = TIC ('Loop_' + STRTRIM (fnum, 2))

   ;-------------------------
   ; Get current date & time.
   ;-------------------------

   current_time = systime (/UTC)

   bdate   = bin_date (current_time)
   cyear   = strtrim (string (bdate (0)), 2)
   cmonth  = strtrim (string (bdate (1)), 2)
   cday    = strtrim (string (bdate (2)), 2)
   chour   = strtrim (string (bdate (3)), 2)
   cminute = strtrim (string (bdate (4)), 2)
   csecond = strtrim (string (bdate (5)), 2)
   if (bdate (1) LT 10) then cmonth  = '0' + cmonth
   if (bdate (2) LT 10) then cday    = '0' + cday
   if (bdate (3) LT 10) then chour   = '0' + chour
   if (bdate (4) LT 10) then cminute = '0' + cminute
   if (bdate (5) LT 10) then csecond = '0' + csecond
   date_dp = cyear + '-' + cmonth + '-' + cday + 'T' $
           + chour + ':' + cminute + ':' + csecond

   readf, ULIST,   l0_file
;   print, 'l0_file: ', l0_file
   img  = readfits (l0_file, header, /SILENT)
   img  = float (img)
   img0 = reform (img (*, *, 0, 0))	; camera 0 [reflected]
   img1 = reform (img (*, *, 0, 1))	; camera 1 [transmitted] 
   TYPE = ''
   TYPE = fxpar (header, 'DATATYPE')

   print,        '>>>>>>> ', l0_file, '  ', fnum, '  ', TYPE, ' <<<<<<<'
   printf, ULOG, '>>>>>>> ', l0_file, '  ', fnum, '  ', TYPE, ' <<<<<<<'

   ;--------------------------
   ; Read date of observation.  (needed to compute ephemeris info)
   ;--------------------------

   date_obs = SXPAR  (header, 'DATE-OBS') 	; yyyy-mm-ddThh:mm:ss
   date     = strmid (date_obs,  0,10)		; yyyy-mm-dd

   ;-----------------------------------------
   ; Create string data for annotating image.
   ;-----------------------------------------

   ;--- Extract fields from DATE_OBS.

   syear   = strmid (date_obs,  0, 4)
   smonth  = strmid (date_obs,  5, 2)
   sday    = strmid (date_obs,  8, 2)
   shour   = strmid (date_obs, 11, 2)
   sminute = strmid (date_obs, 14, 2)
   ssecond = strmid (date_obs, 17, 2)

;   print,         'date_obs: ', date_obs
;   printf, ULOG,  'date_obs: ', date_obs

   ;--- Convert month from integer to name of month.

   if (smonth EQ '01') then name_month = 'Jan'
   if (smonth EQ '02') then name_month = 'Feb'
   if (smonth EQ '03') then name_month = 'Mar'
   if (smonth EQ '04') then name_month = 'Apr'
   if (smonth EQ '05') then name_month = 'May'
   if (smonth EQ '06') then name_month = 'Jun'
   if (smonth EQ '07') then name_month = 'Jul'
   if (smonth EQ '08') then name_month = 'Aug'
   if (smonth EQ '09') then name_month = 'Sep'
   if (smonth EQ '10') then name_month = 'Oct'
   if (smonth EQ '11') then name_month = 'Nov'
   if (smonth EQ '12') then name_month = 'Dec'

   date_img = sday + ' ' + name_month + ' ' + syear + ' ' $
            + shour + ':' + sminute + ':'  + ssecond

;   print,        'date_img: ', date_img
;   printf, ULOG, 'date_img: ', date_img

   ;---------------------------
   ; Compute DOY [day-of-year].
   ;---------------------------

    mday      = [0,31,59,90,120,151,181,212,243,273,304,334]   
    mday_leap = [0,31,60,91,121,152,182,213,244,274,305,335] ;leap year

    if ( (fix (syear) mod 4) EQ 0 ) then $
       odoy = ( mday_leap (fix (smonth) - 1) + fix (sday) ) $
    else $
       odoy = (mday (fix (smonth) - 1) + fix (sday))

   ;-----------------------------
   ; Convert strings to integers.
   ;-----------------------------

   oyear   = fix (syear)
   omonth  = fix (smonth)
   oday    = fix (sday)
   ohour   = fix (shour)
   ominute = fix (sminute)
   osecond = fix (ssecond)

   ehour   = float (ohour) + ominute / 60.0 + osecond / 3600.0

;   print, 'oyear, odoy, omonth, oday : ', oyear, odoy, omonth, oday
;   print, 'ohour, ominute, osecond :   ', ohour, ominute, osecond

   ;--- Determine observing time at MLSO [HST time zone].

   hdoy    = odoy
   hyear   = oyear
   hmonth  = omonth
   hday    = oday
   hhour   = ohour - 10
   hminute = ominute
   hsecond = osecond

;   print, 'hyear, hmonth, hday, hdoy : ', hyear, hmonth, hday, hdoy
;   print, 'hhour, hminute, hsecond :   ', hhour, hminute, hsecond

   if (ohour LT 5) then $		; previous HST day if UTC hour < 5.
   begin ;{
      hhour += 24
      hdoy  -=  1

      ydn2md, hyear, hdoy, hmon, hday	; convert DOY to month & day.

      if (hdoy EQ 0) then $		; 31 Dec of previous year if DOY = 0.
      begin ;{ 
         hyear -=  1 
	 hmonth = 12
	 hday   = 31
      end   ;}
   end   ;}

;   print, 'hyear, hmonth, hday, hdoy: ', hyear, hmonth, hday, hdoy
;   print, 'hhour, hminute, hsecond:   ', hhour, hminute, hsecond

   hst_year   = strtrim (string (hyear,   format='(i04)'), 2)
   hst_month  = strtrim (string (hmonth,  format='(i02)'), 2)
   hst_day    = strtrim (string (hday,    format='(i02)'), 2)

   hst_hour   = strtrim (string (hhour,   format='(i02)'), 2)
   hst_minute = strtrim (string (hminute, format='(i02)'), 2)
   hst_second = strtrim (string (hsecond, format='(i02)'), 2)

   ;--------------------------------------------
   ; Create MLSO [HST] date: yyyy-mm-ddThh:mm:ss
   ;--------------------------------------------

   date_hst = hst_year + '-' + hst_month  + '-' + hst_day + 'T' + $
              hst_hour + ':' + hst_minute + ':' + hst_second

   print,         'date_obs: ', date_obs, '    date_hst: ', date_hst
   printf, ULOG,  'date_obs: ', date_obs, '    date_hst: ', date_hst

   ;----------------------------------------------------------------------------
   ; Put the Level-0 FITS header into a structure.
   ;----------------------------------------------------------------------------

   struct = fitshead2struct ((header), DASH2UNDERSCORE = dash2underscore)

;   window, 0, xs = 1024, ys = 1024, retain = 2
;   window, 0, xs = 1024, ys = 1024, retain = 2, xpos = 512, ypos = 512

   device, set_resolution=[1024,1024], decomposed=0, set_colors=256, $
           z_buffering=0
   erase

;  print,        'year, month, day, hour, minute, second: ', $
;           syear, ' ', smonth, ' ', sday, ' ', shour, ' ', sminute, ' ', second
;  printf, ULOG, 'year, month, day, hour, minute, second: ', $
;          syear, ' ', smonth, ' ', sday, ' ', shour, ' ', sminute, ' ', ssecond

   ; ----------------------------------
   ; Solar radius, P and B angle.
   ; ---------------------------------
   
   ;ephem  = pb0r (date_obs, /earth)
   ;pangle = ephem (0)      
   ;bangle = ephem (1)
   ;radsun = ephem (2)    ; arcmin

   ; --------------------------------
   ; Ephemeris data.
   ;---------------------------------
   
   sun, oyear, omonth, oday, ehour, sd=radsun, pa=pangle, lat0=bangle, $
        true_ra=sol_ra, true_dec=sol_dec, $
        carrington=carrington, long0=carrington_long

   sol_ra = sol_ra * 15.0		; Convert from hours to degrees.
   carrington_rotnum = fix (carrington)

;   julian_date = julday (omonth, oday, oyear, ohour, ominute, osecond)

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
   if (occulter eq 1018.0) then occulter = 1018.9
   if (occulter eq 1006.0) then occulter = 1006.9

;   print,        'occulter size [arcsec] : ', occulter
;   printf, ULOG, 'occulter size [arcsec] : ', occulter

   radius_guess = occulter / platescale			; pixels

   ;----------------------------------------------------------------------------
   ; Find image centers & radii of raw images.
   ;----------------------------------------------------------------------------
 
   ; Camera 0. (reflected)
    
   info_raw  = kcor_find_image (img (*, *, 0, 0), $
                                       radius_guess, /center_guess)
   xcen0    = info_raw (0)
   ycen0    = info_raw (1)
   radius_0 = info_raw (2)

   xx0 = findgen (xsize, ysize) mod (xsize) - xcen0   
   yy0 = transpose (findgen (ysize, xsize) mod (ysize) ) - ycen0

   xx0 = double (xx0)  &  yy0 = double (yy0)
   rr0 = sqrt (xx0^2.0 + yy0^2.0)

   theta0 = (atan (-yy0, -xx0)) 
   theta0 = theta0 + !pi

;   pick0 = where (rr0 gt radius_0 -1.0 and rr0 lt 506.0 )
;   mask_occulter0 = fltarr (xsize, ysize)
;   mask_occulter0 (*) = 0
;   mask_occulter0 (pick0) = 1.

   ; Camera 1. (transmitted)

   info_raw = kcor_find_image (img (*, *, 0, 1), $
                                      radius_guess, /center_guess)
   xcen1    = info_raw (0)
   ycen1    = info_raw (1)
   radius_1 = info_raw (2)

   xx1 = findgen (xsize, ysize) mod (xsize) - xcen1  
   yy1 = transpose (findgen (ysize, xsize) mod (ysize) ) - ycen1

   xx1 = double (xx1) &  yy1 = double (yy1)
   rr1 = sqrt (xx1^2.0 + yy1^2.0)

   theta1 = (atan (-yy1, -xx1)) 
   theta1 = theta1 + !pi

;   pick1 = where (rr1 ge radius_1 -1.0 and rr1 lt 506.0)
;   mask_occulter1 = fltarr (xsize, ysize)
;   mask_occulter1 (*) = 0
;   mask_occulter1 (pick1) = 1.0

;   printf, ULOG, 'CAMERA CENTER INFO FOR RAW IMAGES'
   printf, ULOG, 'Camera 0 center and radius: ', xcen0, ycen0, radius_0
   printf, ULOG, 'Camera 1 center and radius: ', xcen1, ycen1, radius_1

   ;--------------------------------------------
   ; Create new gain to account for image shift.
   ;--------------------------------------------
   ; Region of missing data is set to a constant for now.
   ; It should be replaced with the values from the gain we took without
   ; occulter in.

   ;--- camera 0:

   replace = WHERE (rr0 GT radius_0 -4. AND grr0 LE info_gain0 (2) + 4.0, $
                    nrep)
   if (nrep GT 0) then $
   begin ;{
      gain_temp = gain_alfred (*, *, 0)
      gain_replace = shift (gain_alfred (*, *, 0), $
                            xcen0 - info_gain0 (0), $
                            ycen0 - info_gain0 (1) )
      gain_temp (replace) = gain_replace (replace)  ;gain_no_occulter0 (replace)
      gain_shift (*, *, 0) = gain_temp
;      printf, ULOG, 'Gain for CAMERA 0 shifted to image position.'     
   endif ;}

   ;--- camera 1:

   replace = WHERE (rr1 GT radius_1 -4. AND grr1 LE info_gain1 (2) + 4.0, $
                    nrep)
   if (nrep GT 0) then $
   begin ;{
      gain_temp =  gain_alfred (*, *, 1)
      gain_replace = shift (gain_alfred (*, *, 1), $
                            xcen1 - info_gain1 (0), $
			    ycen1 - info_gain1 (1) )
      gain_temp (replace) = gain_replace (replace) ; gain_no_occulter1 (replace)
      gain_shift (*, *, 1) = gain_temp
;      printf, ULOG, 'Gain for CAMERA 1 shifted to image position.'
   endif ;}

   gain_temp    = 0
   gain_replace = 0
   img_cor      = img

   ;----------------------------------------------------------------------------
   ; Apply dark and gain correction.
   ;----------------------------------------------------------------------------
   ; (Set negative values (after dark subtraction) to zero.)

   FOR b = 0, 1 DO $
   begin  ;{ 
      FOR s = 0, 3 DO $
      begin  ;{
;         img (*, *, s, b) = $
;            (img (*, *, s, b) - dark_alfred (*, *, b)) / gain_shift (*, *, b)

         img_cor (*, *, s, b) = img (*, *, s, b) - dark_alfred (*, *, b)
	 img_temp = reform (img_cor (*, *, s, b))
	 img_temp (WHERE (img_temp LE 0, /NULL)) = 0
	 img_cor (*, *, s, b)  = img_temp
         img_cor (*, *, s, b) /= gain_shift (*, *, b)
      endfor ;}
   endfor ;}

   img_temp = 0

;   printf, ULOG, 'Applied dark and gain correction.'  

   ;----------------------------------------------------------------------------
   ; Apply demodulation matrix to get I, Q, U images from each camera.
   ;----------------------------------------------------------------------------

   ;--- Method 27 Feb 2015.

;   FOR y = 0, ysize - 1 do begin
;      FOR x = 0, xsize - 1 do begin
;         if (mask_occulter0 (x, y) EQ 1) then $
;         cal_data (x, y, 0, *) = reform (   dmat (x, y, 0, *, *)) $
;                              ## reform (img_cor (x, y, *, 0))
;         if (mask_occulter1 (x, y) EQ 1) then $
;         cal_data (x, y, 1, *) = reform (   dmat (x, y, 1, *, *)) $
;                              ## reform (img_cor (x, y, *, 1))
;      endfor
;   endfor

  ;--- New method using M. Galloy C-language code. (04 Mar 2015).

   dclock = TIC ('demod_matrix')

   a = transpose (   dmat, [3, 4, 0, 1, 2])
   b = transpose (img_cor, [2, 0, 1, 3])
   result = kcor_batched_matrix_vector_multiply (a, b, 4, 3, xsize * ysize * 2)
   cal_data = reform (transpose (result), xsize, ysize, 2, 3)

   demod_time = TOC (dclock)

   print,        '--- demod matrix   [sec]:  ', demod_time 
   printf, ULOG, '--- demod matrix   [sec]:  ', demod_time 

;  print,        'Applied demodulation.'
;  printf, ULOG, 'Applied demodulation.'

   ;----------------------------------------------------------------------------
   ; Apply distortion correction for raw images.
   ;----------------------------------------------------------------------------

   img0 = reform  (img (*, *, 0, 0))		; camera 0 [reflected]
   img0 = reverse (img0, 2)			; y-axis inversion.
   img1 = reform  (img (*, *, 0, 1))		; camera 1 [transmitted]

;   restore, '/hao/acos/sw/idl/kcor/pipe/dist_coeff.sav'

   restore, dc_path			; distortion correction file.

   dat1 = img0
   dat2 = img1
   apply_dist, dat1, dat2, dx1_c, dy1_c, dx2_c, dy2_c
   cimg0 = dat1
   cimg1 = dat2

   ;----------------------------------------------------------------------------
   ; Find image centers of distortion-corrected images.
   ;----------------------------------------------------------------------------
   ;--- Camera 0:

   info_dc0 = kcor_find_image (cimg0, radius_guess, /center_guess)
   xcc0    = info_dc0 (0)
   ycc0    = info_dc0 (1)
   radius_0 = info_dc0 (2)

   if (doplot EQ 1) then $
   begin ;{
      tv, bytscl (cimg0, 0, 20000)
      loadct, 39
      draw_circle, xcc0, ycc0, radius_0, /dev, color=250
      loadct, 0
      print, 'center camera 0 ', info_dc0
      wait, 1  
   endif ;}

   ;--- Camera 1:

   info_dc1 = kcor_find_image (cimg1, radius_guess, /center_guess)
   xcc1    = info_dc1 (0)
   ycc1    = info_dc1 (1)
   radius_1 = info_dc1 (2)

   xx1 = findgen (xsize, ysize) mod (xsize) - xcc1
   yy1 = transpose (findgen (ysize, xsize) mod (ysize) ) - ycc1

   xx1 = double (xx1)
   yy1 = double (yy1)
   rad1 = sqrt (xx1^2.0 + yy1^2.0)

   theta1 = atan (-yy1, -xx1)
   theta1 = theta1 + !pi

   if (doplot EQ 1) then $
   begin ;{
      tv, bytscl (cimg1, 0, 20000)
      loadct, 39
      draw_circle, xcc1, ycc1, radius_1, /dev, color=250
      loadct, 0
      print, 'center camera 1 ', info_dc1
      wait, 1  
   endif ;}

   ;----------------------------------------------------------------------------
   ; Combine I, Q, U images from camera 0 and camera 1.
   ;----------------------------------------------------------------------------

   radius = (radius_0 + radius_1) * 0.5

   ;--- To shift camera 0 to canera 1:

   deltax = xcc1 - xcc0
   deltay = ycc1 - ycc0

;   print, 'combine beams'

   ;-----------------------------------------------
   ; Invert calibrated data for camera 0 in Y-axis.
   ;-----------------------------------------------

   FOR s = 0, 2 DO $
   begin  ;{
      cal_data (*, *, 0, s) = reverse (cal_data (*, *, 0, s), 2, /overwrite)
   endfor ;}

   ;------------------------------------------------
   ; Apply distortion correction to calibrated data.
   ;------------------------------------------------

   restore, dc_path			; distortion correction file.

   FOR s = 0, 2 DO $
   begin  ;{
      dat1 = cal_data (*, *, 0, s)
      dat2 = cal_data (*, *, 1, s)
      apply_dist, dat1, dat2, dx1_c, dy1_c, dx2_c, dy2_c
      cal_data (*, *, 0, s) = dat1
      cal_data (*, *, 1, s) = dat2
   endfor ;}

   ;----------------------------------------------------------------------------
   ; Compute image average from cameras 0 & 1.
   ;----------------------------------------------------------------------------

   cal_data_combined = dblarr (xsize, ysize, 3)

   FOR s = 0, 2 DO $
   begin  ;{
      cal_data_combined (*, *, s) = $
         ( fshift (cal_data (*, *, 0, s), deltax, deltay) $
	         + cal_data (*, *, 1, s) ) * 0.5
   endfor ;}

   if (doplot EQ 1) then $
   begin ;{
      tv, bytscl (cal_data_combined (*, *, 0), 0, 100)
      draw_circle, xcc1, ycc1, radius_1, /dev, color=0
      wait, 1
   endif ;}

   phase = -17 / !radeg
;   phase = 0.0

   ;--- Polar coordinate images (mk4 scheme).

   qmk4 = - cal_data_combined (*, *, 1) * sin (2.0 * theta1 + phase) $
          + cal_data_combined (*, *, 2) * cos (2.0 * theta1 + phase)
;   qmk4 = -1.0 * qmk4

   umk4 =   cal_data_combined (*, *, 1) * cos (2.0 * theta1 + phase) $
          + cal_data_combined (*, *, 2) * sin (2.0 * theta1 + phase)

   intensity = cal_data_combined (*, *, 0)

   if (doplot EQ 1) then $
   begin ;{
      tv, bytscl (umk4, -0.5, 0.5)
      wait, 1
   endif ;}

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
   if (shift_center EQ 1) then $
   begin ;{
      cal_data_combined_center = dblarr (xsize, ysize, 3)

      FOR s = 0, 2 DO $
      begin ;{
         cal_data_new (*, *, 0, s) = rot (reverse (cal_data (*, *, 0, s), 1), $
	                                  pangle, 1, xsize - 1 - xcc0, ycc0, $
					  cubic=-0.5)
         cal_data_new (*, *, 1, s) = rot (reverse (cal_data (*, *, 1, s), 1), $
                                          pangle, 1, xsize - 1 - xcc1, ycc1, $
					  cubic=-0.5)

         cal_data_combined_center (*, *, s) = (cal_data_new (*, *, 0, s)  $
	                                    +  cal_data_new (*, *, 1, s)) * 0.5
      endfor ;}

      xx1    = findgen (xsize, ysize) mod (xsize) - 511.5
      yy1    = transpose (findgen (ysize, xsize) mod (ysize) ) - 511.5

      xx1    = double (xx1)
      yy1    = double (yy1)
      rad1   = sqrt ( xx1^2.0 + yy1^2.0 )

      theta1 = atan (-yy1, -xx1)
      theta1 = theta1 + !pi
      theta1 = rot (reverse (theta1), pangle, 1)

      xcc1  = 511.5
      ycc1  = 511.5

;      print, 'finished combined beams center'

      if (doplot EQ 1) then $
      begin ;{
         window, 1, xs = xsize, ys = ysize, retain = 2
         wset,1
         tv, bytscl (cal_data_combined_center (*, *, 0), 0, 100)
         draw_circle,  xcc1, ycc1, radius, /dev, color=0
         wset,1
      endif ;}

      ;--- Polar coordinates.

      qmk4 = - cal_data_combined_center (*, *, 1) * sin (2.0 * theta1 + phase) $
             + cal_data_combined_center (*, *, 2) * cos (2.0 * theta1 + phase)
;      qmk4 = -1.0 * qmk4

      umk4 =   cal_data_combined_center (*, *, 1) * cos (2.0 * theta1 + phase) $
             + cal_data_combined_center (*, *, 2) * sin (2.0 * theta1 + phase)

      intensity = cal_data_combined_center (*, *, 0)

      if (doplot EQ 1) then $
      begin ;{
         tv, bytscl (umk4, -0.5, 0.5)
      endif ;}

   endif ;}

   ; -------------------------------------------------------------------------
   ; Sky polarization removal on coordinate-transformed data.
   ; -------------------------------------------------------------------------

;   print, 'Remove sky polarization.'

   r_init = 1.8
   rnum   = 11 

   radscan    = fltarr (rnum)
   amplitude1 = fltarr (rnum)
   phase1     = fltarr (rnum)

;   numdeg = 360
;   numdeg = 180

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
;   As we loop, we will use the parameters from the previous fit as a guess.

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
   begin ;{
      angle_ave_u (*) = 0d0
      angle_ave_q (*) = 0d0

      ; Use solar radius: radsun = radius in arcsec.  

      radstep = 0.10
      r_in    = (r_init + ii * radstep)
      r_out   = (r_init + ii * radstep + radstep)
      radius_beg = r_in
      radius_end = r_out

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
      begin ;{
         angle = float (i)
         pick1 = where (rr1 GE r_in AND rr1 LE r_out $
	                AND theta1_deg GE angle $
                        AND theta1_deg LT angle + stepdeg, nnl1)
         if (nnl1 GT 0) then $
         begin ;{
            angle_ave_u (j) = mean ( umk4_int (pick1) )
            angle_ave_q (j) = mean ( qmk4_int (pick1) )
         endif ;}
         j = j + 1
      endfor ;}

      sky_polar_cam1 = curvefit (degrees, double (angle_ave_u), weights, a, $
                                 FUNCTION_NAME = 'sine2theta_new')

;      print, 'angle_ave_u (0)', angle_ave_u (0)
;      print, 'radius_beg/end : ', radius_beg, radius_end
;      print, 'fit coeff :   ', a (0), a (1) * !radeg

      amplitude1 (ii) = a (0)
      phase1 (ii)     = a (1)
      mini = -0.15
      maxi =  0.15

      skyplot = 0
      if (skyplot EQ 1) then $
      begin ;{
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
      endif ;}

   endfor ;}
   ;----------------------------------------------------------------------------

   mean_phase1 = mean (phase1)

;   radial_amplitude1 = interpol (amplitude1, radscan, rr1,/spline)
;   radial_amplitude1 = interpol (amplitude1, radscan, rr1, /quadratic)

   ;--- Force the fit to be a straight line.

   afit_amplitude    = poly_fit (radscan, amplitude1, 1, afit)
   radial_amplitude1 = interpol (afit, radscan, rr1, /quadratic)

;   afit_bias  = poly_fit (radscan, bias_sky, 1, biasfit)
;   bias_image = interpol (biasfit, radscan, rr1, /quadratic)

   if (doplot EQ 1) then $
   begin ;{
      plot, rr1 (*, 500) * platescale / (radsun), $
            radial_amplitude1 (*, 500), $
	    xtitle='distance (solar radii)', $
            ytitle='amplitude', title='CAMERA 1'
      oplot, radscan * platescale / (radsun), amplitude1, psym=2
      wait,1
   endif ;}

   radial_amplitude1 = reform (radial_amplitude1, xsize, ysize)

;   bias_image        = reform (bias_image, xsize, ysize)
;   tv, bytscl (bias_image, 0.0, 0.002)
;   save = tvrd ()
;   write_gif, 'bias_image.gif', save

   if (doplot EQ 1)then $
   begin ;{
      tvscl, radial_amplitude1
      wait, 1
   end   ;} 

   sky_polar_u1 = radial_amplitude1 * sin (2.0 * theta1 + mean_phase1)
   sky_polar_q1 = radial_amplitude1 * sin (2.0 * theta1 + 90.0 / !radeg $
                                           + mean_phase1 ) + bias

;   sky_polar_q1 = radial_amplitude1 * sin (2.0 * theta1 + 90.0 / !radeg $
;                                           + mean_phase1 ) + bias_image

   qmk4_new = qmk4 - factor * sky_polar_q1 * intensity
   umk4_new = umk4 - factor * sky_polar_u1 * intensity

   if (doplot EQ 1) then $
   begin ;{
      tv, bytscl (qmk4_new, -1, 1)
      draw_circle, xcc1, ycc1, radius_1, thick=4, color=0,  /dev
      FOR i  = 0, rnum-1   DO draw_circle, xcc1, ycc1, radscan (i), /dev
      FOR ii = 0, numdeg-1 DO plots, [xcc1, xcc1 + 500 * cos (degrees(ii))], $
                                  [ycc1, ycc1 + 500 * sin (degrees(ii))], $
				  /dev
      pause
      wait,1
   endif ;}

;   print, 'Finished sky polarization removal.'

   ; Add beams Q and U - withOUT sky polarization correction = linear pol.

   corona0 = sqrt (qmk4^2 + umk4^2)	

   ; Add beams Q and U - WITH sky polarization correction = linear pol.

   corona2 = sqrt (qmk4_new^2 + umk4_new^2)           

   ; Add beams only Q - with sky polarization correction = pB.

   corona =  sqrt (qmk4_new^2)                        

   ;-------------------------------
   ; Use mask to build final image.
   ;-------------------------------

   r_in  = fix (occulter / platescale) + 5.0
   r_out = 504.0

   mask = where (rad1 LT r_in OR rad1 GE r_out)	; pixels beyond field of view.
   corona  (mask) = 0
   corona2 (mask) = 0
   corona0 (mask) = 0

   cbias = 0.02
   corona_bias = corona + cbias
   corona_bias (mask) = 0

   if (doplot EQ 1) then $
   begin ;{
      wset,0
      tv, bytscl (sqrt (corona), 0.0, 1.5)
      pause
   end   ;}

   lct, '/hao/acos/sw/idl/color/quallab_ver2.lut'      ; color table.
   tvlct, red, green, blue, /get

   mini = 0.00
   maxi = 1.20

   test = (corona + 0.03) ^ 0.8
   test (mask) = 0

   if (doplot EQ 1) then $
   begin ;{
      tv, bytscl (test,  min = mini, max = maxi)
      pause
   end   ;}

;   print, 'Finished.'

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
; End of new beam combination modifications.
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

   ; photosphere height = apparent diameter of sun [arcseconds] 
   ;                      divided by platescale [arcseconds / pixel]
   ;                    * radius of occulter [pixels] :

   r_photo = radsun / platescale

;   print,        'Radius of photosphere [pixels] : ', r_photo
;   printf, ULOG, 'Radius of photosphere [pixels] : ', r_photo

   ;--- Load color table.

   lct,   '/hao/acos/sw/idl/color/quallab_ver2.lut'	; color table.
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
   corona_int = fix (1000 * corona)	; Multiply by 1000 to store as integer.

   corona_min    = min (corona)
   corona_max    = max (corona)
   corona_median = median (corona)

   icorona_min    = min (corona_int)
   icorona_max    = max (corona_int)
   icorona_median = median (corona_int)

   datamin = icorona_min
   datamax = icorona_max
   dispmin = mini
   dispmax = maxi
   dispexp = exp

;   print, 'corona      min, max, median :', $
;          corona_min, corona_max, corona_median
;   print, 'corona*1000 min, max, median :', $
;          icorona_min, icorona_max, icorona_median
;   print, 'mini, maxi, exp: ', mini, maxi, exp
;
;   print, minmax (corona), median (corona)
;   print, minmax (corona_int), median (corona_int)
;
;   printf, ULOG, 'corona      min, max, median :', $
;                 corona_min, corona_max, corona_median
;   printf, ULOG, 'corona*1000 min, max, median :', $
;                 icorona_min, icorona_max, icorona_median
;   printf, ULOG, 'mini, maxi, exp: ', mini, maxi, exp
;
;   printf, ULOG, minmax (corona), median (corona)
;   printf, ULOG, minmax (corona_int), median (corona_int)

   xyouts, 4, 990, 'MLSO/HAO/KCOR', color = 255, charsize = 1.5, /device
   xyouts, 4, 970, 'K-Coronagraph', color = 255, charsize = 1.5, /device
   xyouts, 512, 1000, 'North', color = 255, charsize = 1.2, alignment = 0.5, $
           /device
   xyouts, 1018, 995, string (format = '(a2)', sday) + ' ' + $
           string (format = '(a3)', name_month) + $
           ' ' + string(format = '(a4)', syear), /device, alignment = 1.0, $
	   charsize = 1.2, color = 255
   xyouts, 1010, 975, 'DOY ' + string(format = '(i3)', odoy), /device, $
           alignment = 1.0, charsize = 1.2, color = 255
   xyouts, 1018, 955, string (format = '(a2)', shour) + ':' + $
           string (format = '(a2)', sminute) + $
           ':' + string(format = '(a2)', ssecond) + ' UT', /device, $
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
   ;****************************************************************************
   ; BUILD NEW HEADER: reorder old header and insert new information.
   ;****************************************************************************
   ; Enter the info from the level 0 header and insert ephemeris and comments
   ; in proper order. Remove information from level 0 header that is 
   ; NOT correct for level 1 and 2 images.
   ; For example:  NAXIS = 4 for level 0 but NAXIS =  2 for level 1&2 data. 
   ; Therefore NAXIS3 and NAXIS4 fields are not relevent for level 1 and 2 data.
   ;----------------------------------------------------------------------------
   ; Issues of interest: 
   ;----------------------------------------------------------------------------
   ; 1. 01ID objective lens id added on June 18, 2014 
   ; 2. On June 17, 2014 19:30 Allen reports the Optimax 01 was installed. 
   ;    Prior to that date the 01 was from Jenoptik
   ;    NEED TO CHECK THE EXACT TIME NEW OBJECTIVE WENT IN BY OBSERVING 
   ;    CHANGES IN ARTIFACTS.  IT MAY HAVE BEEN INSTALLED EARLIER IN DAY.
   ; 3. IDL stuctures turn boolean 'T' and 'F' into integers (1, 0); 
   ;    Need to turn back to boolean to meet FITS headers standards.
   ; 4. Structures don't accept dashes ('-') in keywords which are FITS header 
   ;    standards (e.g. date-obs). 
   ;    use /DASH2UNDERSCORE  
   ; 5. Structures don't save comments. Need to type them back in.
   ;----------------------------------------------------------------------------

   bscale = 0.001			; pB * 1000 is stored in FITS image.
   bunit  = 'quasi-pB'
   datacite = 'ww2.hao.ucar.edu/mlso/instruments/mlso-kcor-coronagraph'
   datacite = 'http://ezid.cdlib.org/id/doi:10.5065/D69G5JV8'
   img_quality = 'ok'
   newheader    = strarr (200)
   newheader(0) = header(0)         ; contains SIMPLE keyword

   ;-------------------------
   ; Image array information.
   ;-------------------------

   fxaddpar, newheader, 'BITPIX',   struct.bitpix, ' bits per pixel'
   fxaddpar, newheader, 'NAXIS', 2, ' number of dimensions; FITS image' 
   fxaddpar, newheader, 'NAXIS1',   struct.naxis1, ' (pixels) x dimension'
   fxaddpar, newheader, 'NAXIS2',   struct.naxis2, ' (pixels) y dimension'
   if (struct.extend eq 0) then val_extend = 'F'
   if (struct.extend eq 1) then val_extend = 'T'
   fxaddpar, newheader, 'EXTEND', 'F', ' No FITS extensions'

   ;-------------------------
   ; Observation information.
   ;-------------------------

   fxaddpar, newheader, 'DATE-OBS', struct.date_d$obs, ' UTC observation start'
;   fxaddpar, newheader, 'DATE-BEG', struct.date_d$obs, ' UTC observation start'
   fxaddpar, newheader, 'DATE-END', struct.date_d$end, ' UTC observation end'
   fxaddpar, newheader, 'TIMESYS',  'UTC', $
                        ' date/time system: Coordinated Universal Time'
   fxaddpar, newheader, 'DATE_HST', date_hst, ' MLSO observation date [HST]
   fxaddpar, newheader, 'LOCATION', 'MLSO', $
                        ' Mauna Loa Solar Observatory, Hawaii'
   fxaddpar, newheader, 'ORIGIN',   struct.origin, $
                        ' Nat.Ctr.Atmos.Res. High Altitude Observatory'
   fxaddpar, newheader, 'TELESCOP', 'COSMO K-Coronagraph', $
                        ' COSMO: COronal Solar Magnetism Observatory' 
   fxaddpar, newheader, 'INSTRUME', 'COSMO K-Coronagraph'
   fxaddpar, newheader, 'OBJECT',   struct.object, $
                        ' white light polarization brightness'
   fxaddpar, newheader, 'DATATYPE', struct.datatype, ' type of data acquired'
   fxaddpar, newheader, 'OBSERVER', struct.observer, $
                        ' name of Mauna Loa observer'

   ;---------------------
   ; Mechanism positions.
   ;---------------------

   fxaddpar, newheader, 'DARKSHUT', struct.darkshut, $
                        ' dark shutter open(out) or closed(in)'
   fxaddpar, newheader, 'COVER',    struct.cover, $
                        ' cover in or out of the light beam'
   fxaddpar, newheader, 'DIFFUSER', struct.diffuser, $
                        ' diffuser in or out of the light beam'
   fxaddpar, newheader, 'CALPOL',   struct.calpol, $
                        ' calibration polarizer in or out of beam'
   fxaddpar, newheader, 'CALPANG',  struct.calpang, $
                        ' calibration polarizer angle', format='(f9.3)'
   fxaddpar, newheader, 'EXPTIME',  struct.exptime*1.e-3, $
                        ' [s] exposure time for each frame', format = '(f10.4)'
;   fxaddpar, newheader, 'XPOSURE',  struct.exptime * 1.e-3 * struct.numsum, $
;                        ' [s] total exposure for image', format = '(f10.4)'
   fxaddpar, newheader, 'NUMSUM',   struct.numsum, $
                        ' # frames summed per camera & polarizer state'

   ;----------------------
   ; Software information.
   ;----------------------

   fxaddpar, newheader, 'QUALITY',  img_quality, ' Image quality'
   fxaddpar, newheader, 'LEVEL',    'L1', $
                        ' Level 1 intensity is quasi-calibrated'

;   fxaddpar, newheader, 'DATE-L1', datecal(), ' Level 1 processing date'
;   fxaddpar, newheader, 'L1SWID',  'kcorl1.pro 10nov2015', $
;                        ' Level 1 software'

   fxaddpar, newheader, 'DATE_DP', date_dp,    ' L1 processing date (UTC)'
   fxaddpar, newheader, 'DPSWID',  'kcorl1.pro 14dec2015', $
                        ' L1 data processing software'

   fxaddpar, newheader, 'CALFILE', cal_file, $
                        ' calibration file'
;                        ' calibration file:dark, opal, 4 pol.states'
   fxaddpar, newheader, 'DISTORT', dc_file, ' distortion file'
   fxaddpar, newheader, 'DMODSWID', '18 Aug 2014', $
                        ' date of demodulation software'
   fxaddpar, newheader, 'OBSSWID',  struct.obsswid, $
                        ' version of the observing software'

   fxaddpar, newheader, 'BUNIT', bunit, $
             ' note: Level-1 intensities are quasi-pB.'

   fxaddpar, newheader, 'BZERO',    struct.bzero, $
                        ' offset for unsigned integer data'
   fxaddpar, newheader, 'BSCALE',   bscale, $
             ' physical = data * BSCALE + BZERO', format = '(f8.3)'

   ;--------------------------
   ; Data display information.
   ;--------------------------

   fxaddpar, newheader, 'DATAMIN', datamin, ' minimum  value of  data'
   fxaddpar, newheader, 'DATAMAX', datamax, ' maximum  value of  data'
   fxaddpar, newheader, 'DISPMIN', dispmin, ' minimum  value for display', $
                        format='(f10.2)'
   fxaddpar, newheader, 'DISPMAX', dispmax, ' maximum  value for display', $
                        format='(f10.2)'
   fxaddpar, newheader, 'DISPEXP', dispexp, $
                        ' exponent value for display (d=b^dispexp)', $
                        format='(f10.2)'
  
   ;-------------------------------
   ; Coordinate system information.
   ;-------------------------------

   fxaddpar, newheader, 'WCSNAME',  'helioprojective-cartesian', $
                        'World Coordinate System (WCS) name'
   fxaddpar, newheader, 'CTYPE1',   'HPLN-TAN', $
                        ' [deg] helioprojective west angle: solar X'
   fxaddpar, newheader, 'CRPIX1',   xcen, $
                        ' [pixel]  solar X sun center (origin=1)', $
			format='(f9.2)'
   fxaddpar, newheader, 'CRVAL1',   0.00, ' [arcsec] solar X sun center', $
			format='(f9.2)'
   fxaddpar, newheader, 'CDELT1',   platescale, $
                        ' [arcsec/pix] solar X increment = platescale', $
			format='(f9.4)'
   fxaddpar, newheader, 'CUNIT1',   'arcsec'
   fxaddpar, newheader, 'CTYPE2',   'HPLT-TAN', $
                        ' [deg] helioprojective north angle: solar Y'
   fxaddpar, newheader, 'CRPIX2',   ycen, $
                        ' [pixel]  solar Y sun center (origin=1)', $
			format='(f9.2)'
   fxaddpar, newheader, 'CRVAL2',   0.00, ' [arcsec] solar Y sun center', $
			format='(f9.2)'
   fxaddpar, newheader, 'CDELT2',   platescale, $
                        ' [arcsec/pix] solar Y increment = platescale', $
			format='(f9.4)'
   fxaddpar, newheader, 'CUNIT2',   'arcsec'
   fxaddpar, newheader, 'INST_ROT', 0.00, $
                        ' [deg] rotation of the image wrt solar north', $
			format='(f9.3)'
   fxaddpar, newheader, 'PC1_1',    1.00, $
                        ' coord transform matrix element (1, 1) WCS std.', $
			format='(f9.3)'
   fxaddpar, newheader, 'PC1_2',    0.00, $
                        ' coord transform matrix element (1, 2) WCS std.', $
			format='(f9.3)'
   fxaddpar, newheader, 'PC2_1',    0.00, $
                        ' coord transform matrix element (2, 1) WCS std.', $
			format='(f9.3)'
   fxaddpar, newheader, 'PC2_2',    1.00, $
                        ' coord transform matrix element (2, 2) WCS std.', $
			format='(f9.3)'

   ;--------------------------------------------------
   ; Raw camera occulting center & radius information.
   ;--------------------------------------------------

   fxaddpar, newheader, 'RCAMXCEN', xcen0 + 1, $
                        ' [pixel] camera 0 raw X-coord occulting center', $
			format='(f8.3)'
   fxaddpar, newheader, 'RCAMYCEN', ycen0 + 1, $
                        ' [pixel] camera 0 raw Y-coord occulting center', $
			format='(f8.3)'
   fxaddpar, newheader, 'RCAM_RAD',  radius_0, $
                        ' [pixel] camera 0 raw occulter radius', $
			format='(f8.3)'
   fxaddpar, newheader, 'TCAMXCEN', xcen1 + 1, $
                        ' [pixel] camera 1 raw X-coord occulting center', $
			format='(f8.3)'
   fxaddpar, newheader, 'TCAMYCEN', ycen1 + 1, $
                        ' [pixel] camera 1 raw Y-coord occulting center', $
			format='(f8.3)'
   fxaddpar, newheader, 'TCAM_RAD',  radius_1, $
                        ' [pixel] camera 1 raw occulter radius', $
			format='(f8.3)'

   ;--------------------
   ; Add ephemeris data.
   ;--------------------

   fxaddpar, newheader, 'RSUN',     radsun, $
                        ' [arcsec] solar radius', format = '(f9.3)'
   fxaddpar, newheader, 'SOLAR_P0', pangle, $
                        ' [deg] solar P angle',   format = '(f9.3)'
   fxaddpar, newheader, 'CRLT_OBS', bangle, $
                        ' [deg] solar B angle: Carrington latitude ', $
			format = '(f8.3)'
   fxaddpar, newheader, 'CRLN_OBS', carrington_long, $
                        ' [deg] solar L angle: Carrington longitude', $
			format = '(f9.3)'
   fxaddpar, newheader, 'CAR_ROT',  carrington_rotnum, $
                        ' Carrington rotation number', format = '(i4)'
   fxaddpar, newheader, 'SOLAR_RA', sol_ra, $
                        ' [h]   solar Right Ascension (hours)', $
			format = '(f9.3)'
   fxaddpar, newheader, 'SOLARDEC', sol_dec, $
                        ' [deg] solar Declination (deg)', format = '(f9.3)'

   ;------------------------
   ; Wavelength information.
   ;------------------------

   fxaddpar, newheader, 'WAVELNTH', 735, $
                        ' [nm] center wavelength   of bandpass filter', $
	                format = '(i4)'
   fxaddpar, newheader, 'WAVEFWHM', 30, $
                        ' [nm] full width half max of bandpass filter', $
	                format = '(i3)'
   ;------------------
   ; Engineering data.
   ;------------------

   rcamfocs = struct.rcamfocs
   srcamfocs = strmid (string (struct.rcamfocs), 0, 3)
   if (srcamfocs EQ 'NaN') then rcamfocs = 0.0
   tcamfocs = struct.tcamfocs
   stcamfocs = strmid (string (struct.tcamfocs), 0, 3)
   if (stcamfocs EQ 'NaN') then tcamfocs = 0.0

   fxaddpar, newheader, 'O1FOCS',   struct.o1focs, $
                        ' [mm] objective lens (01) focus position', $
			format = '(f8.3)'
   fxaddpar, newheader, 'RCAMFOCS', rcamfocs, $
                        ' [mm] camera 0 focus position', format='(f9.3)'
   fxaddpar, newheader, 'TCAMFOCS', tcamfocs, $
                        ' [mm] camera 1 focus position', format='(f9.3)'
   fxaddpar, newheader, 'MODLTRT',  struct.modltrt, $
                        ' [deg C] modulator temperature', format = '(f8.3)'
   fxaddpar, newheader, 'SGSDIMV',  struct.sgsdimv, $
                        ' [V] mean Spar Guider Sys. (SGS) DIM signal', $
			format = '(f9.4)'
   fxaddpar, newheader, 'SGSDIMS',  struct.sgsdims, $
                        ' [V] SGS DIM signal standard deviation', $
			format = '(e11.3)'
   fxaddpar, newheader, 'SGSSUMV',  struct.sgssumv, $
                        ' [V] mean SGS sum signal',          format = '(f9.4)'
   fxaddpar, newheader, 'SGSRAV',   struct.sgsrav, $
                        ' [V] mean SGS RA error signal',     format = '(e11.3)'
   fxaddpar, newheader, 'SGSRAS',   struct.sgsras, $
                        ' [V] mean SGS RA error standard deviation', $
			format = '(e11.3)'
   fxaddpar, newheader, 'SGSRAZR',  struct.sgsrazr, $
                        ' [arcsec] SGS RA zeropoint offset', format = '(f9.4)'
   fxaddpar, newheader, 'SGSDECV',  struct.sgsdecv, $
                        ' [V] mean SGS DEC error signal',    format = '(e11.3)'
   fxaddpar, newheader, 'SGSDECS',  struct.sgsdecs, $
                        ' [V] mean SGS DEC error standard deviation', $
			format = '(e11.3)' 
   fxaddpar, newheader, 'SGSDECZR', struct.sgsdeczr, $ 
                        ' [arcsec] SGS DEC zeropoint offset', format = '(f9.4)'
   fxaddpar, newheader, 'SGSSCINT', struct.sgsscint, $
                        ' [arcsec] SGS scintillation seeing estimate', $
			format = '(f9.4)'
   fxaddpar, newheader, 'SGSLOOP',  struct.sgsloop, ' SGS loop closed fraction'
   fxaddpar, newheader, 'SGSSUMS',  struct.sgssums, $
                        ' [V] SGS sum signal standard deviation', $
			format = '(e11.3)'
   ;-----------------------
   ; Component identifiers.
   ;-----------------------
   fxaddpar, newheader, 'CALPOLID', struct.calpolid, $
                        ' ID polarizer'
   fxaddpar, newheader, 'DIFFSRID', struct.diffsrid, $
                        ' ID diffuser'
   fxaddpar, newheader, 'FILTERID', struct.filterid, $
                        ' ID bandpass filter'
   ;--------------------------------------------------------------------
   ; Ben Berkey added keyword 'O1ID' (objective lens id) on 18 June 2014 
   ; to accommodate installation of Optimax objective lens.
   ;--------------------------------------------------------------------

   if (oyear LT 2014) then $
      fxaddpar, newheader, 'O1ID',     'Jenoptik', $
                           ' ID objective (01) lens'

   if (oyear EQ 2014) then $
   begin ;{
      if (month lt 6) then $
         fxaddpar, newheader, 'O1ID',     'Jenoptik', $
	                      ' ID objective (01) lens'
      if (month eq 6) and (day lt 17) then $
         fxaddpar, newheader, 'O1ID',     'Jenoptik', $
	                      ' ID objective (01) lens'
      if (month eq 6) and (day ge 17) then $
         fxaddpar, newheader, 'O1ID',     'Optimax', $
	                      ' ID objective (01) lens'
      if (month gt 6) then $
         fxaddpar, newheader, 'O1ID',     'Optimax', $
	                      ' ID objective (01) lens'
   endif ;}

   if (oyear gt 2014) then $
      fxaddpar, newheader, 'O1ID',     struct.o1id, $
                           ' ID objective (01) lens' 

   fxaddpar, newheader, 'OCCLTRID', struct.occltrid, $
                        ' ID occulter'

   fxaddpar, newheader, 'MODLTRID', struct.modltrid, $
                           ' ID modulator'

   fxaddpar, newheader, 'RCAMID',   'MV-D1024E-CL-11461', $
                        ' ID camera 0 (reflected)'
   fxaddpar, newheader, 'TCAMID',   'MV-D1024E-CL-13889', $
                        ' ID camera 1 (transmitted)' 
   fxaddpar, newheader, 'RCAMLUT',  '11461-20131203', $
                        ' ID LUT for camera 0'
   fxaddpar, newheader, 'TCAMLUT',  '13889-20131203', $
                        ' ID LUT for camera 1'

   ;-------------------
   ; Data citation URL.
   ;-------------------
   fxaddpar, newheader, 'DATACITE', datacite, ' URL for DOI'
 
;   fxaddpar, newheader, 'DATASUM', datasum,   ' data checksum'
;   fxaddpar, newheader, 'CHECKSUM', checksum, ' HDU  checksum'

   ;---------------------
   ; Instrument comments.
   ;---------------------

   fxaddpar, newheader, 'COMMENT', $
      ' The COSMO K-coronagraph is a 20-cm aperture, internally occulted'
   fxaddpar, newheader, 'COMMENT', $
      ' coronagraph, which observes the polarization brightness of the corona'
   fxaddpar, newheader, 'COMMENT', $
      ' with a field-of-view from ~1.05 to 3 solar radii in a wavelength range'
   fxaddpar, newheader, 'COMMENT', $
      ' from 720 to 750 nm. Nominal time cadence is 15 seconds.'
  
   ;--------------------------
   ; Data Processing comments.
   ;--------------------------

   sxaddhist, $
     ' Level 1 processing : dark current subtracted, gain correction,',$
      newheader
   sxaddhist, $
     ' polarimetric demodulation, coordinate transformation from cartesian', $
      newheader
   sxaddhist, $
     ' to tangent/radial, preliminary removal of sky polarization, ',$
      newheader
   sxaddhist, $
     ' image distortion correction, beams combined, platescale calculated.', $
      newheader

   ;----------------------------------------------------------------------------
   ; For FULLY CALIBRATED DATA:  Add these when ready.
   ;----------------------------------------------------------------------------
   ;  fxaddpar, newheader, 'BUNIT', '10^-6 Bsun', $
   ;                       ' Brightness with respect to solar disc.'
   ;  fxaddpar, newheader, 'BOPAL', '1.38e-05', $
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
   ; fxaddpar, newheader, 'LEVEL', 'L2', ' Processing Level'
   ; fxaddpar, newheader, 'DATE-L2', datecal(), ' Level 2 processing date'
   ; fxaddpar, newheader, 'L2SWID', 'Calib Reduction Mar 31, 2014', $
   ;           ' Demodulation Software Version'
   ;----------------------------------------------------------------------------

   ;--- Write FITS image to disc.

   l1_file = strmid (l0_file, 0, 20) + '_l1.fts'
   writefits, l1_dir + l1_file, corona_int, newheader

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
   xyouts, 507, 495, string (format = '(a2)', sday) + ' ' + $
           string (format = '(a3)', name_month) + $
           ' ' + string(format = '(a4)', syear), /device, alignment = 1.0, $
	   charsize = 1.0, color = 255
   xyouts, 500, 480, 'DOY ' + string (format = '(i3)', odoy), $
           /device, alignment = 1.0, charsize = 1.0, color = 255
   xyouts, 507, 465, string (format = '(a2)', shour) + ':' + $
           string (format = '(a2)', sminute) + ':' + $
	   string (format = '(a2)', ssecond) + ' UT', /device, alignment = 1.0,$
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

   ;----------------------------------------------------------------------------
   ; Create NRG (normalized, radially-graded) GIF image.
   ;----------------------------------------------------------------------------

   cd, l1_dir
   if (osecond LT 15 AND fix (ominute / 2)* 2 EQ ominute) then $
      kcor_nrgf, l1_file

   cd, l0_dir

   ;----------------------------------------------------------------------------

   FLUSH, ULOG				; send buffered output to file.

   loop_time = TOC (lclock)		; save loop time.
   print,        '--- Loop  duration [sec]: ', loop_time
   printf, ULOG, '--- Loop  duration [sec]: ', loop_time
endwhile ;}
;*******************************************************************************
; end of WHILE loop
;*******************************************************************************

;--- Get system time & compute elapsed time since "TIC" command.

DONE: $
total_time = TOC ()
print,        '--- Total duration [sec]: ', total_time
printf, ULOG, '--- Total duration [sec]: ', total_time

if (fnum NE 0)  then $
   image_time = total_time / fnum $
else $
   image_time = 0.0

print,        '    time/image:           ', image_time, '   # images: ', fnum
printf, ULOG, '    time/image:           ', image_time, '   # images: ', fnum

;TOC, REPORT=report
;print,       report[-1]
;print, ULOG, report[-1]

print,        '>>>>>>> End of kcorl1 <<<<<<<'
printf, ULOG, '>>>>>>> End of kcorl1 <<<<<<<'
printf, ULOG, '- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'

close, ULIST
close, ULOG
free_lun, ULIST
free_lun, ULOG

END