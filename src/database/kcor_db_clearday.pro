; docformat = 'rst'

;+
; Delete entries for a day, e.g., before reprocessing that day.
;
; :Keywords:
;   run : in, required, type=object
;     `kcor_run` object
;   obsday_index : in, required, type=integer
;     index into mlso_numfiles database table
;   database : in, optional, type=MGdbMySql object
;     database connection to use
;-
pro kcor_db_clearday, run=run, database=database, obsday_index=obsday_index
  compile_opt strictarr

  ; Note: The connect procedure accesses DB connection information in the file
  ;       .mysqldb. The "config_section" parameter specifies which group of data
  ;       to use.
  if (obj_valid(database)) then begin
    db = database

    db->getProperty, host_name=host
    mg_log, 'already connected to %s...', host, name='kcor/dbinsert', /info
  endif else begin
    db = mgdbmysql()
    db->connect, config_filename=run.database_config_filename, $
                 config_section=run.database_config_section

    db->getProperty, host_name=host
    mg_log, 'connected to %s...', host, name='kcor/dbinsert', /info
  endelse

  ; kcor_img
  db->execute, 'DELETE FROM kcor_img WHERE obs_day=''%s''', obsday_index, $
               status=status, error_message=error_message, sql_statement=sql_cmd

  mg_log, 'sql_cmd: %s', sql_cmd, name='kcor/dbinsert', /info
  mg_log, 'status: %d, error message: %s', status, error_message, $
          name='kcor/dbinsert', /info

  ; TODO: kcor_eng, kcor_cal

  done:
  if (~obj_valid(database)) then obj_destroy, db

  mg_log, 'done', name='kcor/dbinsert', /info
end


; main-level example

date = '20161127'

run = kcor_run(date, $
               config_filename=filepath('kcor.mgalloy.mahi.latest.cfg', $
                                        subdir=['..', '..', 'config'], $
                                        root=mg_src_root()))

obsday_index = mlso_obsday_insert(date, run=run, database=db)
kcor_db_clearday, run=run, database=db, obsday_index=obsday_index

obj_destroy, db

end
