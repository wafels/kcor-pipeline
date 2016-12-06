; docformat = 'rst'

;+
; Utility to insert values into the MLSO database table: kcor_img.
;
; Reads a list of L1 files for a specified date and inserts a row of data into
; 'kcor_img'.
;
; :Params:
;   date : in, required, type=string
;     date in the form 'YYYYMMDD'
;
; :Keywords:
;   run : in, required, type=object
;     `kcor_run` object
;
; :Examples:
;   For example::
;
;     kcor_img_insert, '20150324'
;
; :Author: 
;   Andrew Stanger
;   HAO/NCAR  K-coronagraph
;
; :History:
;   28 Sep 2015 IDL procedure created.  
;             Use /hao/mlsodata1/Data/raw/yyyymmdd/level1 directory.
;-
pro kcor_cal_insert, date, run=run
  compile_opt strictarr
  on_error, 2

  np = n_params() 
  if (np ne 1) then begin
    mg_log, 'missing date parameter', name='kcor/dbinsert', /error
    return
  endif

  ;--------------------------
  ; Connect to MLSO database.
  ;--------------------------

  db = mgdbmysql()
  db->connect, config_filename=run.database_config_filename, $
               config_section=run.database_config_section

  db->getProperty, host_name=host
  mg_log, 'connected to %s...', host, name='kcor/dbinsert', /info

  db->setProperty, database='MLSO'

  ;----------------------------------
  ; Print DB tables in MLSO database.
  ;----------------------------------

  ;print, db, format='(A, /, 4(A-20))'

  ;-------------------------------------------------------------------------------
  ; Delete all pre-existing rows with date_obs = designated date to be processed.
  ;-------------------------------------------------------------------------------

  year    = strmid(date, 0, 4)	; yyyy
  month   = strmid(date, 4, 2)	; mm
  day     = strmid(date, 6, 2)	; dd
  odate_dash = year + '-' + month + '-' + day + '%'

  db->execute, 'DELETE FROM kcor_cal WHERE date_obs like ''%s''', odate_dash, $
               status=status, error_message=error_message, sql_statement=sql_cmd
  mg_log, 'sql_cmd: %s', sql_cmd, name='kcor/dbinsert', /info
  mg_log, 'status: %d, error message: %s', status, error_message, $
          name='kcor/dbinsert', /info

  ;-----------------------
  ; Directory definitions.
  ;-----------------------

  fts_dir = filepath('level0', subdir=date, root=run.raw_basedir)

  ;----------------
  ; Move to fts_dir.
  ;----------------

  cd, current=start_dir
  cd, fts_dir

  ;------------------------------------------------
  ; Create list of fits files in current directory.
  ;------------------------------------------------

  fits_list = file_search('*kcor.fts*', count=nfiles)

  if (nfiles eq 0) then begin
    mg_log, 'No images in list file', name='kcor/dbinsert', /info
    goto, done
  endif

  i       = -1
  fts_file = 'img.fts'
  mg_log, 'nfiles: %d', nfiles, name='kcor/dbinsert', /info

  while (++i lt nfiles) do begin
    fts_file = fits_list[i]

    finfo = file_info(fts_file)         ; Get file information.

    ;--- Read FITS header.

    hdu   = headfits(fts_file, /silent) ; Read FITS header.

    datatype = 'unknown'
    instrume = 'missing_keyword'

    ; Extract desired items from header.

    date_obs   = sxpar(hdu, 'DATE-OBS', count=qdate_obs)
    date_end   = sxpar(hdu, 'DATE-END', count=qdate_end)
    telescop   = sxpar(hdu, 'TELESCOP', count=qtelescop)
    instrume   = sxpar(hdu, 'INSTRUME', count=qinstrume)
    datatype   = sxpar(hdu, 'DATATYPE', count=qdatatype)
    level      = sxpar(hdu, 'LEVEL',    count=qlevel)
    exptime    = sxpar(hdu, 'EXPTIME',  count=qexptime)
    numsum     = sxpar(hdu, 'NUMSUM',   count=qnumsum)
    cover      = sxpar(hdu, 'COVER',    count=qcover)
    darkshut   = sxpar(hdu, 'DARKSHUT', count=qdarkshut)
    diffuser   = sxpar(hdu, 'DIFFUSER', count=qdiffuser)
    calpol     = sxpar(hdu, 'CALPOL',   count=qcalpol)
    calpang    = sxpar(hdu, 'CALPANG',  count=qcalpang)

    datatype_str = strtrim(datatype, 2)
    if (datatype_str ne 'calibration') then continue   ; only process cal images.

    level_str = strtrim(string (level), 2)
    quality    = 'u'
    filetype   = 'fits'

    mg_log, 'date_obs: %s', date_obs, name='kcor/dbinsert', /debug
    mg_log, 'date_end: %s', date_end, name='kcor/dbinsert', /debug
    mg_log, 'telescop: %s', telescop, name='kcor/dbinsert', /debug
    mg_log, 'instrume: %s', instrume, name='kcor/dbinsert', /debug
    mg_log, 'datatype: %s', datatype, name='kcor/dbinsert', /debug
    mg_log, 'level:    %s', level, name='kcor/dbinsert', /debug
    mg_log, 'exptime:  %s', exptime, name='kcor/dbinsert', /debug
    mg_log, 'numsum:   %s', numsum, name='kcor/dbinsert', /debug
    mg_log, 'cover:    %s', cover, name='kcor/dbinsert', /debug
    mg_log, 'darkshut: %s', darkshut, name='kcor/dbinsert', /debug
    mg_log, 'diffuser: %s', diffuser, name='kcor/dbinsert', /debug
    mg_log, 'calpol:   %s', calpol, name='kcor/dbinsert', /debug
    mg_log, 'calplang: %s', calpang, name='kcor/dbinsert', /debug

    if (qdatatype eq 0) then begin
      mg_log, 'qdatatype: %s', qdatatype, name='kcor/dbinsert', /debug
      datatype = 'unknown'
    endif

    if (qinstrume eq 0) then begin
      mg_log, 'qinstrume: %s', qinstrume, name='kcor/dbinsert', /debug
      instrume = telescop
    endif

    ; Construct variables for database table fields.

    year  = strmid(date_obs, 0, 4)	; yyyy
    month = strmid(date_obs, 5, 2)	; mm
    day   = strmid(date_obs, 8, 2)	; dd
    
    ; Determine DOY.

    mday      = [0,31,59,90,120,151,181,212,243,273,304,334]
    mday_leap = [0,31,60,91,121,152,182,213,244,274,305,335] ; leap year 

    if ((fix(year) mod 4) eq 0) then begin
      doy = mday_leap[fix (month) - 1] + fix(day)
    endif else begin
      doy = mday[fix (month) - 1] + fix(day)
    endelse
    doy_str = string(doy, format='(%"%3d")')

    date_dash = strmid(date_obs, 0, 10)	     ; yyyy-mm-dd
    time_obs  = strmid(date_obs, 11, 8)	     ; hh:mm:ss
    date_img  = date_dash + ' ' + time_obs   ; yyyy-mm-dd hh:mm:ss

    date_dash = strmid(date_end, 0, 10)	     ; yyyy-mm-dd
    time_obs  = strmid(date_end, 11, 8)	     ; hh:mm:ss
    date_eod  = date_dash + ' ' + time_obs   ; yyyy-mm-dd hh:mm:ss

    fits_file = strmid(fts_file, 0, 27)	     ; remove '.gz' from file name.

    mg_log, 'date_img: %s', date_img, name='kcor/dbinsert', /debug
    mg_log, 'date_eod: %s', date_eod, name='kcor/dbinsert', /debug

    ; Encode index columns.

    instrume_results = db->query('SELECT * FROM instrume WHERE instrument=''%s''', $
                                 instrume, fields=fields)
    instrume_num = instrume_results.id
    mg_log, 'instrume:            %s', instrume, name='kcor/dbinsert', /debug
    mg_log, 'instrume_results.id: %s', instrume_results.id, name='kcor/dbinsert', /debug

    quality_results = db->query('SELECT * FROM quality WHERE quality=''%s''', $
                                quality, fields=fields)
    quality_num = quality_results.id
    mg_log, 'quality:             %s', quality, name='kcor/dbinsert', /debug
    mg_log, 'quality_results.id:  %s', quality_results.id, name='kcor/dbinsert', /debug

    filetype_results = db->query('SELECT * FROM filetype WHERE filetype=''%s''', $
                                 filetype, fields=fields)
    filetype_num = filetype_results.id
    mg_log, 'filetype:            %s', filetype, name='kcor/dbinsert', /debug
    mg_log, 'filetype_results.id: %s', filetype_results.id, name='kcor/dbinsert', /debug

    level_results = db->query('SELECT * FROM level WHERE level=''%s''', level, $
                              fields=fields)
    level_num = level_results.id
    mg_log, 'level:               %s', level, name='kcor/dbinsert', /debug
    mg_log, 'level_results.id:    %s', level_results.id, name='kcor/dbinsert', /debug

    ; DB insert command.

    db->execute, 'INSERT INTO kcor_cal (file_name, date_obs, date_end, instrument, level, numsum, exptime, cover, darkshut, diffuser, calpol, calpang) VALUES (''%s'', ''%s'', ''%s'', ''%s'', ''%s'', %d, %f, ''%s'', ''%s'', ''%s'', ''%s'', %f) ', $
                 fits_file, date_img, date_eod, instrume, level_str, numsum, $
                 exptime, cover, darkshut, diffuser, calpol, calpang, $
                 status=status, $
                 error_message=error_message, $
                 sql_statement=sql_cmd

    mg_log, '%s: status: %d, error message: %s', status, error_message, $
            name='kcor/dbinsert', /debug
    mg_log, 'sql_cmd: %s', sql_cmd, name='kcor/dbinsert', /debug
  endwhile

  done:
  obj_destroy, db

  mg_log, '*** end of kcor_cal_insert ***', name='kcor/dbinsert', /info
end
