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
;   fits_list : in, required, type=strarr
;     array of FITS files to insert into the database
;
; :Keywords:
;   run : in, required, type=object
;     `kcor_run` object
;   obsday_index : in, required, type=integer
;     index into mlso_numfiles database table
;   database : in, optional, type=MGdbMySql object
;     database connection to use
;
; :Examples:
;   For example::
;
;     date = '20170204'
;     filelist = ['20170204_205610_kcor_l1_nrgf.fts.gz', '20170204_205625_kcor_l1.fts.gz']
;     kcor_img_insert, date, filelist, run=run, obsday_index=obsday_index
;
;   See the main-level program in this file for a detailed example.
;
; :Author: 
;   Andrew Stanger
;   HAO/NCAR  K-coronagraph
;   Major edits beyond creation: Don Kolinski
;
; :History:
;   11 Sep 2015 IDL procedure created.  
;               Use /hao/mlsodata1/Data/raw/yyyymmdd/level1 directory.
;   14 Sep 2015 Use /hao/acos/year/month/day directory.
;   28 Sep 2015 Add date_end field.
;   7 Feb 2017 DJK - Starting to edit for new table fields and noting new changes to come (search for TODO)
;-
pro kcor_img_insert, date, fits_list, $
                     run=run, $
                     database=database, $
                     obsday_index=obsday_index
  compile_opt strictarr
  on_error, 2

  if (n_params() ne 2) then begin
    mg_log, 'missing date or filelist parameters', name='kcor/rt', /error
    return
  endif

  ; connect to MLSO database

  ; Note: The connect procedure accesses DB connection information in the file
  ;       .mysqldb. The "config_section" parameter specifies which group of data
  ;       to use.
  if (obj_valid(database)) then begin
    db = database

    db->getProperty, host_name=host
    mg_log, 'using connection to %s...', host, name='kcor/rt', /debug
  endif else begin
    db = mgdbmysql()
    db->connect, config_filename=run.database_config_filename, $
                 config_section=run.database_config_section

    db->getProperty, host_name=host
    mg_log, 'connected to %s...', host, name='kcor/rt', /info
  endelse

  year    = strmid (date, 0, 4)	; yyyy
  month   = strmid (date, 4, 2)	; mm
  day     = strmid (date, 6, 2)	; dd

  l1_dir = filepath('level1', subdir=date, root=run.raw_basedir)
  cd, current=start_dir 
  cd, l1_dir

  ; step through list of fits files passed in parameter
  nfiles = n_elements(fits_list)
  if (nfiles eq 0) then begin
    mg_log, 'no images in fits list', name='kcor/rt', /info
    goto, done
  endif

  i = -1
  n_pb_added = 0L
  n_nrgf_added = 0L
  while (++i lt nfiles) do begin
    fts_file = fits_list[i]

    is_nrgf = strpos(file_basename(fts_file), 'nrgf') ge 0L
    fts_file += '.gz'

    if (~file_test(fts_file)) then begin
      mg_log, '%s not found', fts_file, name='kcor/rt', /warn
      continue
    endif else begin
      mg_log, 'ingesting %s', fts_file, name='kcor/rt', /info
    endelse

    ; extract desired items from header
    hdu   = headfits(fts_file, /silent)   ; read FITS header
    date_obs   = sxpar(hdu, 'DATE-OBS', count=qdate_obs)
    date_end   = sxpar(hdu, 'DATE-END', count=qdate_end)
    exptime    = sxpar(hdu, 'EXPTIME',  count=qexptime)
    numsum     = sxpar(hdu, 'NUMSUM',   count=qnumsum)
    quality    = sxpar(hdu, 'QUALITY',  count=qquality)

    if (strtrim(quality, 2) eq 'ok') then begin 
      quality = 75
    endif

    level      = strtrim(sxpar(hdu, 'LEVEL',    count=qlevel),2)
    ; TODO: Older NRGF headers have 'NRGF' appended to level string, but newer headers
    ;   will have another keyword added to header for producttype
    os = strpos(level, 'NRGF')
    if (os ne -1) then begin
      level = strmid(level, 0, os)
    endif	

    ; get product type from filename
    ; TODO: are there any more? Parse from header when new producttype keyword
    ; is added.
    p = strpos(fts_file, 'nrgf')
    if (p ne -1) then begin	
      producttype = 'nrgf'
    endif else begin
      producttype = 'pB'
    endelse

    ; The decision is to not include non-FITS in the database because raster
    ; files (GIFs) will be created for every image in database. However, since
    ; we may add them later, or other file types, we'll keep the field in the
    ; kcor_img database table.
    filetype   = 'fits'

    fits_file = file_basename(fts_file, '.gz') ; remove '.gz' from file name.

    ; get IDs from relational tables
    producttype_count = db->query('SELECT count(producttype_id) FROM mlso_producttype WHERE producttype=''%s''', $
                                  producttype, fields=fields)
    if (producttype_count.count_producttype_id_ eq 0) then begin
      ; if given producttype is not in the mlso_producttype table, set it to
      ; 'unknown' and log error
      producttype = 'unknown'
      mg_log, 'producttype: %s', producttype, name='kcor/rt', /error
    endif
    producttype_results = db->query('SELECT * FROM mlso_producttype WHERE producttype=''%s''', $
                                    producttype, fields=fields)
    producttype_num = producttype_results.producttype_id	
		
    filetype_count = db->query('SELECT count(filetype_id) FROM mlso_filetype WHERE filetype=''%s''', $
                               filetype, fields=fields)
    if (filetype_count.count_filetype_id_ eq 0) then begin
      ; if given filetype is not in the mlso_filetype table, set it to 'unknown'
      ; and log error
      filetype = 'unknown'
      mg_log, 'filetype: %s', filetype, name='kcor/rt', /error
    endif
    filetype_results = db->query('SELECT * FROM mlso_filetype WHERE filetype=''%s''', $
                                 filetype, fields=fields)
    filetype_num = filetype_results.filetype_id	

    level_count = db->query('SELECT count(level_id) FROM kcor_level WHERE level=''%s''', $
                            level, fields=fields)
    if (level_count.count_level_id_ eq 0) then begin
      ; if given level is not in the kcor_level table, set it to 'unknown' and
      ; log error
      level = 'unk'
      mg_log, 'level: %s', level, name='kcor/rt', /error
    endif
    level_results = db->query('SELECT * FROM kcor_level WHERE level=''%s''', $
                              level, fields=fields)
    level_num = level_results.level_id	

    ; DB insert command
    db->execute, 'INSERT INTO kcor_img (file_name, date_obs, date_end, obs_day, level, quality, producttype, filetype, numsum, exptime) VALUES (''%s'', ''%s'', ''%s'', %d, %d, %d, %d, %d, %d, %f) ', $
                 fits_file, date_obs, date_end, obsday_index, level_num, quality, producttype_num, $
                 filetype_num, numsum, exptime, $
                 status=status, error_message=error_message, sql_statement=sql_cmd

    if (status eq 0L) then begin
      if (is_nrgf) then n_nrgf_added += 1 else n_pb_added += 1
    endif else begin
      mg_log, 'error inserting in kcor_img table', name='kcor/rt', /error
      mg_log, 'status: %d, error message: %s', status, error_message, $
              name='kcor/rt', /error
      mg_log, 'SQL command: %s', sql_cmd, name='kcor/rt', /error
    endelse
  endwhile

  ; update number of files in mlso_numfiles
  num_files_results = db->query('SELECT * FROM mlso_numfiles WHERE day_id=''%d''', obsday_index)
  n_pb_files = num_files_results.num_kcor_pb_fits + n_pb_added
  n_nrgf_files = num_files_results.num_kcor_nrgf_fits + n_nrgf_added

  db->execute, 'UPDATE mlso_numfiles SET num_kcor_pb_fits=''%d'', num_kcor_nrgf_fits=''%d'', num_kcor_pb_lowresgif=''%d'', num_kcor_pb_fullresgif=''%d'', num_kcor_nrgf_lowresgif=''%d'', num_kcor_nrgf_fullresgif=''%d'' WHERE day_id=''%d''', $
               n_pb_files, n_nrgf_files, $
               n_pb_files, n_pb_files, n_nrgf_files, n_nrgf_files, $
               obsday_index, $
               status=status, error_message=error_message, sql_statement=sql_cmd
  if (status ne 0L) then begin
    mg_log, 'error updating mlso_numfiles table', name='kcor/rt', /error
    mg_log, 'status: %d, error message: %s', status, error_message, $
            name='kcor/rt', /error
    mg_log, 'SQL command: %s', sql_cmd, name='kcor/rt', /error
  endif

  done:
  if (~obj_valid(database)) then obj_destroy, db
  cd, start_dir

  mg_log, 'done', name='kcor/rt', /info
end


; main-level example program

;date = '20170204'
;filelist = ['20170204_205610_kcor_l1_nrgf.fts.gz','20170204_205625_kcor_l1.fts.gz','20170204_205640_kcor_l1.fts.gz','20170204_205656_kcor_l1.fts.gz','20170204_205711_kcor_l1.fts.gz']
date = '20170305'
filelist = ['20170305_185807_kcor_l1_nrgf.fts.gz','20170305_185822_kcor_l1.fts.gz','20170305_185837_kcor_l1.fts.gz']

run = kcor_run(date, $
               config_filename=filepath('kcor.kolinski.mahi.latest.cfg', $
                                        subdir=['..', '..', 'config'], $
                                        root=mg_src_root()))
kcor_img_insert, date, filelist, run=run

end
