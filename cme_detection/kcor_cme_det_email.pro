;+
; Project     :	MLSO - KCOR
;
; Name        :	KCOR_CME_DET_EMAIL
;
; Purpose     :	Send out MLSO K-cor alert emails
;
; Category    :	KCOR, CME, Detection
;
; Explanation : This routine is called from KCOR_CME_DET_ALERT to send out
;               alert emails to a distribution list by spawning the unix
;               command "mail".  The spawns are performed with nohup and with
;               an ampersand at the end so that the program does not need to
;               wait for the mail message to be sent before continuing.
;
; Syntax      :	KCOR_CME_DET_EMAIL, TIME, EDGE
;
; Examples    :	See KCOR_CME_DET_ALERT
;
; Inputs      :	TIME    = Detection time in string format
;               EDGE    = Height of leading edge in Rsun units.  Ignored if
;                         /OPERATOR keyword is set.
;
; Opt. Inputs :	None
;
; Outputs     :	The movies are written to the directory specified by the
;               environment variable KCOR_CME_DETECTION.
;
; Opt. Outputs:	None
;
; Keywords    :	OPERATOR = Flags that this is an operator alert, and not all
;                          the CME parameters are available.
;
; Calls       :	MK_TEMP_FILE, GET_TEMP_DIR, 
;
; Common      :	KCOR_CME_DETECTION defined in kcor_cme_detection.pro
;
; Restrictions:	Depending on the operating system, the Unix "mail" command may
;               or may not be able to add attachments through the "-a" switch.
;               However, attachments can also be added by using uuencode and
;               appending the text output to the temporary mail message file.
;
; Side effects:	None
;
; Prev. Hist. :	None
;
; History     :	Version 1, 22-Mar-2017, William Thompson, GSFC
;
; Contact     :	WTHOMPSON
;-
pro kcor_cme_det_email, time, edge, operator=operator
  compile_opt strictarr
  common kcor_cme_detection

  addresses = run.cme_email
  if (addresses eq '') then begin
    mg_log, 'no cme.email specified, not sending email', $
            name='kcor-cme', /warn
    return
  endif

  ; create filename for plot file
  if (~file_test(run.engineering_dir, /directory)) then begin
    file_mkdir, run.engineering_dir
  endif
  plot_file = filepath(string(simple_date, format='(%"%s.cme.profile.png")'), $
                       root=run.engineering_dir)

  ; create plot to attach to email
  original_device = !d.name
  set_plot, 'Z'
  loadct, 0

  device, decomposed=1, set_pixel_depth=24, set_resolution=[800, 360]

  itime = n_elements(leadingedge) - 1L
  map = mdiffs[*, *, itime] > 0
  i0 = itheta[0, itime]
  i1 = itheta[1, itime]
  if (i1 ge i0) then begin
    y = average(map[i0:i1, *], 1)
  endif else begin
    y = average(map[0:i1, *], 1) + average(map[i0:*, *], 1)
  endelse

  rsun = (pb0r(date0))[2]
  height = 60 * (lat + 90) / rsun
  plot, height, y, $
        color='000000'x, background='ffffff'x, $
        xstyle=1, $
        xtitle='Solar radii', $
        ytitle='Difference in pB', $
        title=string(angle, date_diff[itime].date_avg, $
                     format='(%"Radial plot at %0.1f degrees at %s")')

  im = tvrd(true=1)
  set_plot, original_device
  write_png, plot_file, im

  ; create a temporary file for the message
  mailfile = mk_temp_file(dir=get_temp_dir(), 'cme_mail.txt', /random)

  ; Write out the message to the temporary file. Different messages are sent
  ; depending on whether the alert was automatic or generated by the operator.
  openw, out, mailfile, /get_lun
  if (keyword_set(operator)) then begin
    printf, out, 'The Mauna Loa K-coronagraph operator has noticed a ' + $
            'CME in progress.'
    printf, out, 'Parameters for this CME have not yet been measured.'
  endif else begin
    printf, out, 'The Mauna Loa K-coronagraph has detected a possible CME at ' + $
            time + ' UT with the following parameters'
    printf, out
    format = '(F10.2)'
    printf, out, 'Radial distance from Sun center: ' + ntrim(edge, format) + ' Rsun'
    printf, out, 'Position angle: ' + ntrim(angle) + ' degrees'
    printf, out, 'Initial speed: ' + ntrim(speed, format) + ' km/s'
  endelse
  free_lun, out

  subject = string(simple_date, time, $
                   format='(%"MLSO K-Cor possible CME on %s at %s UT")')

  cmd = string(subject, plot_file, addresses, mailfile, $
               format='(%"mail -s \"%s\" -a %s %s < %s")')
  spawn, cmd, result, error_result, exit_status=status
  if (status eq 0L) then begin
    mg_log, 'alert sent to %s', addresses, name='kcor-cme', /info
  endif else begin
    mg_log, 'problem with mail command: %s', cmd, name='kcor-cme', /error
    mg_log, strjoin(error_result, ' '), name='kcor-cme', /error
  endelse

  ; delete the temporary file
  file_delete, mailfile
end
