; docformat = 'rst'

;+
; Create a cropped GIF of an image.
;
; :Params:
;   im : in, required, type="fltarr(1024, 1024)"
;     image data
;   date_obs : in, required, type=structure
;     structure with fields doy, year, month, day, hour, minute, second, ehour,
;     and month_name
;
; :Keywords:
;   run : in, required, type=object
;     `kcor_run` object
;-
pro kcor_cropped_gif, im, date, date_obs, run=run
  compile_opt strictarr

  start_index = 256L
  end_index   = 1024L - start_index - 1L
  width       = end_index - start_index + 1L
  height      = end_index - start_index + 1L
  crop_image  = im[start_index:end_index, start_index:end_index]

  original_device = !d.name
  set_plot, 'Z'

  erase

  ; configure device
  device, get_decomposed=original_decomposed
  device, set_resolution=[width, height], $
          decomposed=0, $
          set_colors=256, $
          z_buffering=0

  ; load black and white color table
  loadct, 0, /silent

  min = run->epoch('cropped_display_min')
  max = run->epoch('cropped_display_max')
  exp = run->epoch('cropped_display_exp')

  ; display image
  tv, bytscl(crop_image^exp, min=min, max=max)

  ; print annotations
  xyouts, 4, 495, 'MLSO/HAO/KCOR', color=255, charsize=1.2, /device

  xyouts, 507, 495, $
          string(date_obs.day, date_obs.month_name, date_obs.year, $
                 date_obs.hour, date_obs.minute, date_obs.second, $
                 format='(%"%02d %s %04d %02d:%02d:%02d UT")'), $
          /device, alignment=1.0, charsize=1.0, color=255

  xyouts, 4, 6, string(min, max, $
                       format='(%"min/max: %5.2f, %3.1f")'), $
          color=255, charsize=1.0, /device
  xyouts, 507, 6, string(exp, $
                         format='(%"scaling: Intensity ^ %3.1f")'), $
          color=255, charsize=1.0, /device, alignment=1.0

  mlso_sun, date_obs.year, date_obs.month, date_obs.day, date_obs.ehour, $
            sd=radsun
  r_photosphere = radsun / run->epoch('plate_scale')
  tvcircle, r_photosphere, 255.5, 255.5, color=255, /device

  raster = tvrd(true=0)
  tvlct, red, green, blue, /get

  l1_dir = filepath('level1', subdir=date, root=run.raw_basedir)
  cgif_basename = string(date_obs.year, date_obs.month, date_obs.day, $
                         date_obs.hour, date_obs.month, date_obs.second, $
                         format='(%"%04d%02d%02d_%02d%02d%02d_kcor_l1_cropped.gif")')
  write_gif, filepath(cgif_basename, root=l1_dir), raster, red, green, blue

  done:
  device, decomposed=original_decomposed
  set_plot, original_device
end


; main-level example program

date = '20180423'
l1_basename = '20180424_000420_kcor_l1.fts.gz'

config_filename = filepath('kcor.mgalloy.mahi.latest.cfg', $
                           subdir='../../config', $
                           root=mg_src_root())
run = kcor_run(date, config_filename=config_filename)

l1_filename = filepath(l1_basename, $
                       subdir=[date, 'level1'], $
                       root=run.raw_basedir)

im = readfits(l1_filename, header, /silent)
date_obs = sxpar(header, 'DATE-OBS')
date_obs = kcor_parse_dateobs(date_obs)

kcor_cropped_gif, im, date, date_obs, run=run

obj_destroy, run

end
