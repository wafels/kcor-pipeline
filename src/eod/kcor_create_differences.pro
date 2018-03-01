; docformat = 'rst'

;+
;  1) Create averaged images from KCor level 1 data, averaging up to 4 images
;     if they are taken < 2 minutes apart
;  2) generate subtractions from averages that are >= 10 minutes apart in time.
;  3) create a subtraction every 5 minutes
;  4) check subtractions for quality by checking azimutal scan intensities at
;     1.15 Rsun
;  5) save each subtraction as an annotated gif and a fits image with quality
;     value in filename
;
; :History:
;   J. Burkepile (Jan 2018)
;
; :Uses:
;   tscan
;
; :Params:
;   date : in, required, type=string
;     date in the form "YYYYMMDD"
;   l1_files : in, required, type=strarr
;     array of L1 filenames
;
; :Keywords:
;   run : in, required, type=object
;     `kcor_run` object
;-
pro kcor_create_differences, date, l1_files, run=run
  compile_opt strictarr

  mg_log, 'creating difference movies', name='kcor/eod', /info

  date_parts = kcor_decompose_date(date)
  fullres_dir = filepath('', subdir=date_parts, root=run.fullres_basedir)
  cropped_dir = filepath('', subdir=date_parts, root=run.croppedgif_basedir)
  if (run.distribute) then begin
    if (~file_test(fullres_dir, /directory)) then file_mkdir, fullres_dir
    if (~file_test(cropped_dir, /directory)) then file_mkdir, fullres_dir
  endif

  l1_dir = filepath('level1', subdir=date, root=run.raw_basedir)

  cd, current=current
  cd, l1_dir

  ; set up variables and arrays needed
  l1_file = ''
  base_file = ''
  fits_file = ''
  gif_file = ''

  imgsave = fltarr(1024, 1024, 4)
  aveimg = fltarr(1024, 1024)
  bkdimg = fltarr(1024, 1024, 12)
  bkdtime = dblarr(12)
  filetime = strarr(12)
  imgtime = ''

  subimg = fltarr(1024, 1024)
  timestring = ''

  date_julian = dblarr(4)

  ; set up julian date intervals for averaging, creating subtractions, and how
  ; often subtractions are created.

  ; currently:  average 4 images over a maximum of 2 minutes
  ;             create a subtraction image every 5 minutes	
  ;             create subtractions using averaged images 10 minutes apart

  avginterval = run.diff_average_interval / 60.0D / 60.0D / 24.0D
  time_between_subs = run.diff_cadence / 60.0D / 60.0D / 24.0D
  subinterval = run.diff_interval / 60.0D / 60.0D / 24.0D

  ; set up counting variables

  avgcount  = 0   ; keep track of number of averaged images 
  bkdcount  = 0   ; keep track of number of background images up to 12 for stack storage
  subtcount = 0   ; has a subtraction image been created?
  stopavg   = 0   ; set to 1 if images are more than 2 minutes apart (stop averaging)
  newsub    = 0

  ; read in images and generate subtractions ~10 minutes apart
  f = 0L
  while (f lt n_elements(l1_files)) do begin
    numavg = 0

    ; read in up to 4 images, get time, and average if images <= 2 min apart
    for i = 0, 3 do begin
      if (f ge n_elements(l1_files)) then break

      l1_file = file_basename(l1_files[f])
      img = readfits(l1_file, header, /silent, /noscale)

      f += 1

      imgsave[*, *, i] = float(img)

      ; scaling information for quality scans
      rsun    = fxpar(header, 'RSUN')         ; solar radius [arcsec/Rsun]
      cdelt1  = fxpar(header, 'CDELT1')       ; resolution   [arcsec/pixel]
      pixrs   = rsun / cdelt1
      r_photo = rsun / cdelt1
      xcen    = fxpar(header, 'CRPIX1')       ; X center
      ycen    = fxpar(header, 'CRPIX2')       ; Y center
      roll    = 0.0

      ; find image time
      date_obs = fxpar(header, 'DATE-OBS')    ; yyyy-mm-ddThh:mm:ss

      ; extract fields from DATE_OBS
      yr  = strmid(date_obs,  0, 4)
      mon = strmid(date_obs,  5, 2)
      dy  = strmid(date_obs,  8, 2)
      hr  = strmid(date_obs, 11, 2)
      mnt = strmid(date_obs, 14, 2)
      sec = strmid(date_obs, 17, 2)
      imgtime = string(hr, mnt, sec, format='(a2,a2,a2)')

      ; convert strings to integers
      year   = fix(yr)
      month  = fix(mon)
      day    = fix(dy)
      hour   = fix(hr)
      minute = fix(mnt)
      second = fix(sec)

      ; find julian day
      date_julian[i] = julday(month, day, year, hour, minute, second)

      if (i eq 0) then begin
        aveimg = imgsave[*, *, 0]
        goodheader = header
        numavg = 1
      endif

      ;  Once we have read more than one image we check that images are <= 2
      ;  minutes apart

      ;  ** NOTE: 2 minutes in julian date units = 1.38889e-03

      ;  If images are <= 2 minutes apart we average them together
      ;  If images are > 2 minutes apart we stop averaging, save avg. image and
      ;     make a subtraction
      if (i gt 0) then begin
        difftime = date_julian[i] - date_julian[0]

        if (difftime le avginterval) then begin
          aveimg += imgsave[*, *, i]
          goodheader = header ; save header in case next image is > 2 min. in time
          numavg += 1
        endif

        if (difftime gt avginterval) then begin
          stopavg = 1   ; set flag to stop averaging
        endif
      endif

      if (stopavg eq 1) then break
    endfor

    i -= 1
    stopavg = 0

    ; Make averaged FITS image
    aveimg = aveimg / float(numavg)
    avgcount += 1
    bkdcount += 1

    ; Build up a stack of up to 12 averaged images to use as future background
    ; images.

    ; FIRST LOOP TO BUILD UP BACKGROUND IMAGE STACK: Initialize the stack with
    ; the first image only.
    if (bkdcount eq 1) then begin
      time_since_sub = date_julian[i]  
      for j = 0, 11 do begin
        bkdimg[*, *, j] = aveimg
        bkdtime[j] = date_julian[i]
        filetime[j] = imgtime
      endfor
    endif

    ; SECOND LOOP TO BUILD UP BACKGROUND IMAGE STACK:
    ; Next add later images to stack until we have 12 unique images in stack
    ; Latest time is put into stack[0], oldest time is in stack[11]
    ; Begin looking for images 10 minutes apart to make subtraction
    if (bkdcount gt 1 && bkdcount le 12) then begin
      counter = bkdcount - 2
      for k = 0, counter do begin   
        bkdtime[counter + 1 - k] = bkdtime[counter - k]
        bkdimg[*, *, counter + 1 - k] = bkdimg[*, *, counter - k]
        filetime[counter + 1 - k] = filetime[counter - k]
      endfor
      ; for first 10 images, copy current image into 0 position (latest time)
      bkdimg[*, *, 0] = aveimg
      bkdtime[0] = date_julian[i]
      filetime[0] = imgtime
    endif

    ; Create a difference image every 5 observing minutes
    ; Difference the current image from an image taken >= 10 minutes earlier

    ; ** NOTE: 5 minutes in julian date units = 3.47222e-03
    ; ** NOTE:10 minutes in julian date units = 6.94445e-03

    ;  Has it been 5 minutes since the previous subtraction?
    ;  Go thru the stack of 10 images looking for the 'newest' time that is 10
    ;  minutes before the current image
    if ((avgcount ge 2) $
          && ((date_julian[i] - time_since_sub) ge time_between_subs)) then begin
      for j = 0, 11 do begin
        if (date_julian[i] - bkdtime[j] ge subinterval) then begin  
          subimg = aveimg - bkdimg[*, *, j]
          newsub = 1  ;  need to write a new subtraction image
          time_since_sub = date_julian[i]
          ; need this info to write into FITS and GIF filename
          timestring = filetime[j]

          ; HAVE A NEW SUBTRACTION. NEED TO SHIFT THE BKD IMAGE STACK
          for k = 0, 10 do begin   
            bkdtime[11 - k] = bkdtime[10 - k]
            bkdimg[*, *, 11 - k] = bkdimg[*, *, 10 - k]
            filetime[11 - k] = filetime[10 - k]
          endfor
          ; save current image as the new bkd image 
          bkdimg[*, *, 0] = aveimg
          ; save current time as the new time of bkd image
          bkdtime[0] = date_julian[i]
          filetime[0] = imgtime
          if (newsub eq 1) then break
        endif
        if (newsub eq 1) then break
      endfor
    endif

    ; THIRD AND FINAL LOOP TO UPDATE BACKGROUND IMAGE STACK:  
    ; IF THERE WAS NO SUBTRACTION MADE WE need to 
    ; add each new average image to the bkd. stack 
    ; in newest slot (i.e. stack(0)) and shift older images up the stack
    ; This needs to be done whether or not we make a subtraction
    ; A 12-image stack of 1-minute averaged images ensures we have background 
    ; images that span > 10 minutes
    if (newsub eq 0) then begin
      if (bkdcount gt 13) then begin
        for k = 0, 10 do begin   
          bkdtime[11 - k] = bkdtime[10 - k]
          bkdimg[*, *, 11 - k] = bkdimg[*, *, 10 - k]
          filetime[11 - k] = filetime[10 - k]
        endfor
        ; save current image as the new bkd image
        bkdimg[*, *, 0] = aveimg
        ; save current time as the new time of bkd image
        bkdtime[0] = date_julian[i]
        filetime[0] = imgtime
      endif
    endif
    
    ; If a subtraction image was created save:

    ; 1) perform a quality control check using an azimuthal scan at 1.15
    ;    solar radii and checking the absolute values of the intensities.
    ;    Flag the filenames with: good, pass, bad
    ; 2) Create annotation for the GIF image
    ; 3) Create GIF and FITS images of the subtraction

    ; 1) SET UP SCAN PARAMETERS and perform quality control scan

    theta_min       = 0.0
    theta_max       = 359.0
    theta_increment = 0.5
    radius          = 1.15

    good_value  = run.diff_good_max
    pass_value  = run.diff_pass_max
    threshold_intensity = run.diff_threshold_intensity

    pointing_ck = 0

    if (newsub eq 1) then begin
      tscan, l1_file, subimg, pixrs, roll, xcen, ycen, $
             theta_min, theta_max, theta_increment, radius, $
             scan, scandx, ns

      for i = 0, ns - 1 do begin
        if (abs(scan[i]) gt threshold_intensity) then pointing_ck += 1
      endfor

      ; 2) Create annotation for GIF image

      ; convert month from integer to name of month
      name_month = (['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', $
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'])[month - 1]

      date_img = string(dy, name_month, yr, hr, mnt, sec, $
                        format='(%"%s %s %s %sx:%s:%s")')

      ; compute DOY (day-of-year)
      mday      = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
      mday_leap = [0, 31, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]   ; leap year

      if ((year mod 4) eq 0) then begin
        doy = (mday_leap[month - 1] + day)
      endif else begin
        doy = (mday[month] - 1) + day
      endelse

      ; 3) Create gif and fits images

      set_plot, 'Z'
      device, set_resolution=[1024, 1024], decomposed=0, set_colors=256, $
              z_buffering=0
      display_min = -0.02
      display_max =  0.02
    
      tv, bytscl(subimg, display_min, display_max)

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
      xyouts, 1018, 915, string(format='(a2)', strmid(timestring, 0, 2)) + ':' $
              + string(format = '(a2)', strmid(timestring, 2, 2)) $
              + ':' + string(format='(a2)', strmid(timestring, 4, 2)) + ' UT', $
              /device, alignment=1.0, charsize=1.2, color=255

      xyouts, 22, 512, 'East', color=255, charsize=1.2, alignment=0.5, $
              orientation=90., /device
      xyouts, 1012, 512, 'West', color=255, charsize=1.2, alignment=0.5, $
              orientation=90., /device
      xyouts, 4, 46, 'Subtraction', color=255, charsize=1.2, /device
      xyouts, 4, 26, string(display_min, display_max, $
                            format='("min/max: ", f6.3, ", ", f6.3)'), $
              color=255, charsize=1.2, /device
      xyouts, 1018, 6, 'Circle = photosphere.', $
              color=255, charsize=1.2, /device, alignment=1.0

      ; image has been shifted to center of array
      ; draw circle at photosphere
      tvcircle, r_photo, 511.5, 511.5, color=255, /device

      device, decomposed = 1 
      save = tvrd()

      case 1 of
        pointing_ck le good_value: status = 'good'
        pointing_ck le pass_value: status = 'pass'
        else: status = 'bad'
      endcase

      name = strmid(file_basename(l1_file), 0, 20)

      mg_log, 'writing %s-%s GIF/FTS file (%s)', $
              strmid(name, 9, 6), timestring, status, $
              name='kcor/eod', /info

      gif_basename = string(name, timestring, status, format='(%"%s_minus_%s_%s.gif")')
      write_gif, gif_basename, save

      fits_basename = string(name, timestring, status, format='(%"%s_minus_%s_%s.fts")')
      writefits, fits_basename, subimg, goodheader

      if (run.distribute) then begin
        ; TODO: eventually these will be distributed
        ;file_copy, gif_basename, fullres_dir, /overwrite
        ;file_copy, fits_basename, fullres_dir, /overwrite
      endif

      newsub = 0
    endif
  endwhile

  ; create mp4 of difference images
  difference_gif_filenames = file_search('*minus*', $
                                         count=n_difference_gif_files)
  if (n_difference_gif_files gt 0L) then begin
    mg_log, 'creating difference mp4', name='kcor/eod', /info
    difference_mp4_filename = string(date, format='(%"%s_kcor_minus.mp4")')
    kcor_create_mp4, difference_gif_filenames, difference_mp4_filename, $
                     run=run, status=status
    if (status eq 0 && run.distribute) then begin
      ; TODO: distribute when the quality of these is correct
      ;file_copy, difference_mp4_filename, fullres_dir, /overwrite
    endif
  endif else begin
    mg_log, 'no difference GIFs, not creating difference mp4', $
            name='kcor/eod', /info
  endelse

  done:
  cd, current
  mg_log, 'done', name='kcor/eod', /info
end


; main-level example program

date = '20180104'
config_filename = filepath('kcor.mgalloy.mahi.latest.cfg', $
                           subdir=['..', '..', 'config'], $
                           root=mg_src_root())
run = kcor_run(date, config_filename=config_filename)

l1_files = file_search(filepath('*_l1.fts.gz', $
                                subdir=[date, 'level1'], $
                                root=run.raw_basedir), $
                       count=n_l1_files)

kcor_create_differences, date, l1_files, run=run

obj_destroy, run

end
