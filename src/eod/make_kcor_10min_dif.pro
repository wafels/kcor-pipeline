pro make_kcor_10min_dif

;  1) Create averaged images from KCor level 1 data,
;     averaging up to 4 images if they are taken < 2 minutes apart
;  2) generate subtractions from averages that are >= 10 minutes apart in time.
;  3) create a subtraction every 5 minutes
;  4) check subtractions for quality by checking azimutal scan intensities at 1.15 Rsun 
;  5) save each subtraction as an annotated gif and a fits image with quality value in filename
;
;  J. Burkepile
;  Jan 2018
;
;  EXPECTS to READ IN A FILE CALLED 'list'
;  M. Galloy will pass in a list of *l1.fts.gz  or *l1.fts ... NOT NRGF fits
;
;  
;  SUBROUTINES used:
;  uses tscan.pro to do quality control check

;  Set up variables and arrays needed
l1_file=''
base_file=''
imglist='list'
fits_file=''
gif_file = ''

imgsave= fltarr(1024,1024,4)
aveimg = fltarr(1024,1024)
bkdimg = fltarr(1024,1024,12)
bkdtime=dblarr(12)
filetime = strarr(12)
imgtime = ''

subimg = fltarr(1024,1024)
timestring = ''

date_julian = dblarr(4)

; SET up julian date intervals for averaging, creating subtractions,
; and how often subtractions are created.
; Currently: 	average 4 images over a maximum of 2 minutes
; 		create a subtraction image every 5 minutes	
;  		create subtractions using averaged images 10 minutes apart
; ** NOTE: 2 minutes in julian date units = 1.38889e-03
; ** NOTE: 5 minutes in julian date units = 3.47222e-03
; ** NOTE:10 minutes in julian date units = 6.94445e-03

avginterval = 1.38889e-03       ; 2 minutes in julian units
time_between_subs = 3.47222e-03 ; 5 minutes in julian units
subinterval = 6.94445e-03      ; 10 minutes in julian units

close,3
openr,3,imglist

; set up counting variables

avgcount=0   ; keep track of number of averaged images 
bkdcount=0   ; keep track of number of background images up to 12 for stack storage
subtcount = 0 ; has a subtraction image been created?
stopavg = 0  ; set to 1 if images are more than 2 minutes apart (stop averaging)
newsub = 0


;-----------------------------------------------------------
; Read in images and generate subtractions ~10 minutes apart
;-----------------------------------------------------------

while (not EOF(3) ) DO BEGIN ;{

numavg = 0

for i = 0,3 do begin   ; read in up to 4 images, get time, and average if images <= 2 min apart

   readf,3,l1_file
   img=readfits(l1_file,header,/silent)
   imgsave(*,*,i) = float(img)

;-----------------------------------------
; scaling information for quality scans
;-----------------------------------------

   rsun     = fxpar (header, 'RSUN')         ; solar radius [arcsec/Rsun]
   cdelt1   = fxpar (header, 'CDELT1')       ; resolution   [arcsec/pixel]
   pixrs = rsun / cdelt1
   r_photo = rsun/cdelt1
   xcen     = fxpar (header, 'CRPIX1')       ; X center
   ycen     = fxpar (header, 'CRPIX2')       ; Y center
   roll = 0.


;-----------------------------------------
; Find image time 
;-----------------------------------------

   date_obs = fxpar(header, 'DATE-OBS')   ; yyyy-mm-ddThh:mm:ss
   date     = strmid (date_obs,  0,10)          ; yyyy-mm-dd

;-----------------------------
;--- Extract fields from DATE_OBS.
;-----------------------------
   yr   = strmid (date_obs,  0, 4)
   mon  = strmid (date_obs,  5, 2)
   dy    = strmid (date_obs,  8, 2)
   hr   = strmid (date_obs, 11, 2)
   mnt = strmid (date_obs, 14, 2)
   sec = strmid (date_obs, 17, 2)
   imgtime =  string(format='(a2,a2,a2)',hr,mnt,sec)

;-----------------------------
; Convert strings to integers
;-----------------------------

   year   = fix (yr)
   month  = fix (mon)
   day    = fix (dy)
   hour   = fix (hr)
   minute = fix (mnt)
   second = fix (sec)

;-----------------------------
;find julian day
;-----------------------------

   date_julian(i) = julday(month,day,year,hour,minute,second)

   if (i eq 0) then begin ;{
      aveimg = imgsave(*,*,0)
      goodheader = header
      numavg = 1
   endif  ;}

;  --------------------------------------------------------------------------------
;  Once we have read more than one image we check that images are <= 2 minutes apart
;  ** NOTE: 2 minutes in julian date units = 1.38889e-03
;  If images are <= 2 minutes apart we average them together
;  If images are > 2 minutes apart we stop averaging, save avg. image and make a subtraction
;  --------------------------------------------------------------------------------

   if (i gt 0) then begin ;{

       difftime = date_julian(i) - date_julian(0)

       if (difftime le avginterval) then begin ;{ 
            aveimg = aveimg + imgsave(*,*,i)
	    goodheader = header   ; save header in case next image is > 2 min. in time 
	    numavg = numavg + 1
       endif ;}

       if (difftime gt avginterval) then begin ;{
          stopavg = 1  ; set flag to stop averaging
       endif ;}

      
   endif ;}

   if (stopavg eq 1) then break

endfor

   i = i-1

   stopavg = 0

; -----------------------------------------
; Make averaged fits image
; -----------------------------------------

   aveimg = aveimg/float(numavg)
   avgcount = avgcount + 1
   bkdcount = bkdcount + 1

; ------------------------------------------------------------------
; Build up a stack of up to 12 averaged images to use as future background images
; FIRST LOOP TO BUILD UP BACKGROUND IMAGE STACK: Initialize the stack with the first image only
; ------------------------------------------------------------------

   if (bkdcount eq 1) then begin ;{
      time_since_sub = date_julian(i)  
         for j = 0,11 do begin
            bkdimg(*,*,j) = aveimg
            bkdtime(j) = date_julian(i)
	    filetime(j) = imgtime
         endfor
   endif ;}

;  ------------------------------------------------
;  SECOND LOOP TO BUILD UP BACKGROUND IMAGE STACK:  
;  Next add later images to stack until we have 12 unique images in stack
;  Latest time is put into stack(0), oldest time is in stack(11)
;  Begin looking for images 10 minutes apart to make subtraction
;  ------------------------------------------------

   if (bkdcount gt 1 AND bkdcount le 12) then begin ;{
      counter = bkdcount - 2
      for k = 0,counter do begin   
         bkdtime(counter+1-k)= bkdtime(counter-k)
         bkdimg(*,*,counter+1-k) = bkdimg(*,*,counter-k)
         filetime(counter+1-k) = filetime(counter-k)
      endfor
      bkdimg(*,*,0) = aveimg          ; For first 10 images, Copy current image into 0 position (latest time)
      bkdtime(0) = date_julian(i)
      filetime(0) = imgtime
   endif ;}


; Create a difference image every 5 observing minutes
; Difference the current image from an image taken >= 10 minutes earlier
;
; ** NOTE: 5 minutes in julian date units = 3.47222e-03
; ** NOTE:10 minutes in julian date units = 6.94445e-03
; 
;  Has it been 5 minutes since the previous subtraction?
;  Go thru the stack of 10 images looking for the 'newest' time that is 10
;  minutes before the current image
; ----------------------------------------------------------------------

  if (avgcount ge 2 AND date_julian(i)-time_since_sub ge time_between_subs) then begin ;{
     for j = 0,11 do begin
        if (date_julian(i)-bkdtime(j) ge subinterval) then begin  
           subimg = aveimg - bkdimg(*,*,j)
           newsub = 1  ;  Need to write a new subtraction image
	   time_since_sub = date_julian(i)
	   timestring = filetime(j)     ;need this info to write into fits and gif filename
;   ----------------------------------------------------------
;   HAVE A NEW SUBTRACTION. NEED TO SHIFT THE BKD IMAGE STACK
;   ----------------------------------------------------------
	   for k = 0,10 do begin   
	      bkdtime(11-k)= bkdtime(10-k)
	      bkdimg(*,*,11-k) = bkdimg(*,*,10-k)
	      filetime(11-k) = filetime(10-k)
	   endfor
           bkdimg(*,*,0) = aveimg    ; save current image as the new bkd image 
           bkdtime(0) = date_julian(i) ; save current time as the new time of bkd image 
	   filetime(0) = imgtime
           if (newsub eq 1) then break
 	endif ;}
        if (newsub eq 1) then break
     endfor
   endif ;}

;  -------------------------------------------------------------------
; THIRD AND FINAL LOOP TO UPDATE BACKGROUND IMAGE STACK:  
; IF THERE WAS NO SUBTRACTION MADE WE need to 
; add each new average image to the bkd. stack 
; in newest slot (i.e. stack(0)) and shift older images up the stack
; This needs to be done whether or not we make a subtraction
; A 12-image stack of 1-minute averaged images ensures we have background 
; images that span > 10 minutes
; ----------------------------------------------------------------------

   if (newsub eq 0) then begin ;{
      if (bkdcount gt 13) then begin ;{
         for k = 0,10 do begin   
	    bkdtime(11-k)= bkdtime(10-k)
	    bkdimg(*,*,11-k) = bkdimg(*,*,10-k)
	    filetime(11-k) = filetime(10-k)
	 endfor
         bkdimg(*,*,0) = aveimg    ; save current image as the new bkd image 
         bkdtime(0) = date_julian(i) ; save current time as the new time of bkd image 
         filetime(0) = imgtime
      endif ;}
   endif ;}

;   ----------------------------------------------------------------------------------
;   If a subtraction image was created save:

;   1) perform a quality control check using an azimuthal scan at 1.15 solar radii
;    and checking the absolute values of the intensities. Flag the filenames with: good, pass, bad
;   2) Create annotation for the gif image
;   3) Create gif and fits images of the subtraction
;   ----------------------------------------------------------------------------------

;   ----------------------------------------------------------------------------------
;   1) SET UP SCAN PARAMETERS and perform quality control scan: 
;   ----------------------------------------------------------------------------------

  thmin = 0.
  thmax = 359.
  thinc = 0.5
  radius = 1.15
  pointing_ck = 0
  good_value = 100
  pass_value = 250


  if (newsub eq 1) then begin ;{  

      tscan,l1_file, subimg, pixrs,roll, xcen, ycen, thmin, thmax, thinc, radius, scan, scandx, ns

      for i = 0, ns - 1 do begin
           if (abs(scan(i)) gt .01) then pointing_ck = pointing_ck + 1
      endfor

;   ----------------------------------------------------------------------------------
;   2) Create annotation for gif image
;   ----------------------------------------------------------------------------------

    ; convert month from integer to name of month
    name_month = (['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', $
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'])[month - 1]

    date_img = dy + ' ' + name_month + ' ' + yr + ' ' $
               + hr + ':' + mnt + ':'  + sec

    ; compute DOY [day-of-year]
    mday      = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
    mday_leap = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]   ; leap year

    if ((year mod 4) eq 0) then begin
      doy = (mday_leap[month - 1] + day)
    endif else begin
      doy = (mday[month] - 1) + day
    endelse


;   ----------------------------------------------------------------------------------
;   3) Create gif and fits images
;   ----------------------------------------------------------------------------------

    set_plot,'Z'
    device, set_resolution=[1024, 1024], decomposed=0, set_colors=256, $
            z_buffering=0
    display_min = -.02
    display_max = .02
    
    tv,bytscl(subimg,display_min,display_max)

    xyouts, 4, 990, 'MLSO/HAO/KCOR', color=255, charsize=1.5, /device
    xyouts, 4, 970, 'K-Coronagraph', color=255, charsize=1.5, /device
    xyouts, 512, 1000, 'North', color=255, charsize=1.2, alignment=0.5, $
            /device
    xyouts, 1018, 995, string(format='(a2)', dy) + ' ' $
              + string(format='(a3)', name_month) $
              + ' ' + string(format = '(a4)', yr), $
            /device, alignment=1.0, $
            charsize=1.2, color=255
    xyouts, 1010, 975, 'DOY ' + string(format='(i3)', doy), /device, $
            alignment=1.0, charsize=1.2, color=255
    xyouts, 1018, 955, string(format='(a2)', hr) + ':' $
                         + string(format = '(a2)', mnt) $
                         + ':' + string(format='(a2)', sec) + ' UT', $
            /device, alignment=1.0, charsize=1.2, color=255
    xyouts, 1010, 935, 'MINUS', /device, alignment=1.0, charsize=1.2, color=255
    xyouts, 1018, 915, string(format='(a2)', strmid(timestring,0,2)) + ':' $
                         + string(format = '(a2)', strmid(timestring,2,2)) $
                         + ':' + string(format='(a2)', strmid(timestring,4,2)) + ' UT', $
            /device, alignment=1.0, charsize=1.2, color=255
   
    xyouts, 22, 512, 'East', color=255, charsize=1.2, alignment=0.5, $
            orientation=90., /device
    xyouts, 1012, 512, 'West', color=255, charsize=1.2, alignment=0.5, $
            orientation=90., /device
    xyouts, 4, 46, 'Subtraction', color=255, charsize=1.2, /device
    xyouts, 4, 26, string(format='("min/max: ", f6.3, ", ", f6.3)',display_min,display_max), $
            color=255, charsize=1.2, /device
    xyouts, 1018, 6, 'Circle = photosphere.', $
            color=255, charsize=1.2, /device, alignment=1.0

    ; image has been shifted to center of array
    ; draw circle at photosphere
    tvcircle, r_photo, 511.5, 511.5, color=255, /device


      device,decomposed = 1 
      save=tvrd()
      if (pointing_ck le good_value) then gif_file = strmid(l1_file, 0, 20) + '_minus_' + timestring + '_good.gif'
      if (pointing_ck gt good_value AND pointing_ck le pass_value) then gif_file = strmid(l1_file, 0, 20) + '_minus_' + timestring + '_pass.gif'
      if (pointing_ck gt pass_value) then gif_file = strmid(l1_file, 0, 20) + '_minus_' + timestring + '_bad.gif'
      write_gif, gif_file, save

      name= strmid(l1_file, 0, 20)
      if (pointing_ck le good_value) then fits_file= string(format='(a20,"_minus_",a6,"_good.fts")',name,timestring)
      if (pointing_ck gt good_value AND pointing_ck le pass_value) then fits_file= string(format='(a20,"_minus_",a6,"_pass.fts")',name,timestring)
      if (pointing_ck gt pass_value) then fits_file= string(format='(a20,"_minus_",a6,"_bad.fts")',name,timestring)
      writefits,fits_file,subimg,goodheader,/silent

      newsub = 0

  endif ;}



endwhile ;}

;*******************************************************************************
; end of WHILE loop
;*******************************************************************************

close,2
close,3

end
