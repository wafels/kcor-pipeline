;+
; Project     :	STEREO
;
; Name        :	WCS_PROJ_AIR
;
; Purpose     :	Convert intermediate coordinates in AIR projection.
;
; Category    :	FITS, Coordinates, WCS
;
; Explanation :	This routine is called from WCS_GET_COORD to apply the Airy
;               (AIR) projection to intermediate relative coordinates.
;
; Syntax      :	WCS_PROJ_AIR, WCS, COORD
;
; Examples    :	See WCS_GET_COORD
;
; Inputs      :	WCS = A World Coordinate System structure, from FITSHEAD2WCS.
;               COORD = The intermediate coordinates, relative to the reference
;                       pixel (i.e. CRVAL hasn't been applied yet).
;
; Opt. Inputs :	None.
;
; Outputs     :	The projected coordinates are returned in the COORD array.
;
; Opt. Outputs:	None.
;
; Keywords    :	TOLERANCE  = Convergence tolerance for zeta, in terms of
;                            R_theta.  The default is 1E-8.
;
;               MAX_ITER   = Maximum number of iterations.  Default is 1000.
;
; Calls       :	TAG_EXIST, NTRIM
;
; Common      :	None.
;
; Restrictions:	Because this routine is intended to be called only from
;               WCS_GET_COORD, no error checking is performed.
;
;               This routine is not guaranteed to work correctly if the
;               projection parameters are non-standard.
;
; Side effects:	None.
;
; Prev. Hist. :	None.
;
; History     :	Version 1, 16-Dec-2005, William Thompson, GSFC
;
; Contact     :	WTHOMPSON
;-
;
pro wcs_proj_air, wcs, coord, tolerance=k_tolerance, max_iter=k_max_iter
on_error, 2
halfpi = !dpi / 2.d0
;
;  Calculate the conversion from coordinate units into radians.
;
cx = !dpi / 180.d0
case wcs.cunit[wcs.ix] of
    'arcmin': cx = cx / 60.d0
    'arcsec': cx = cx / 3600.d0
    'mas':    cx = cx / 3600.d3
    'rad':    cx = 1.d0
    else:     cx = cx
endcase
;
cy = !dpi / 180.d0
case wcs.cunit[wcs.iy] of
    'arcmin': cy = cy / 60.d0
    'arcsec': cy = cy / 3600.d0
    'mas':    cy = cy / 3600.d3
    'rad':    cy = 1.d0
    else:     cy = cy
endcase
;
;  Get the native longitude (phi0) and latitude (theta0) of the fiducial
;  point.  Look for the PV values from the FITS header.  If not found, use the
;  default values (0,90).
;
phi0 = 0.d0
if tag_exist(wcs, 'proj_names', /top_level) then begin
    name = 'PV' + ntrim(wcs.ix+1) + '_1'
    w = where(wcs.proj_names eq name, count)
    if count gt 0 then phi0 = wcs.proj_values[w[0]]
endif
;
theta0 = 90.d0
if tag_exist(wcs, 'proj_names', /top_level) then begin
    name = 'PV' + ntrim(wcs.ix+1) + '_2'
    w = where(wcs.proj_names eq name, count)
    if count gt 0 then theta0 = wcs.proj_values[w[0]]
endif
;
;  If PHI0 and THETA0 are non-standard, then signal an error.
;
if (phi0 ne 0) or (theta0 ne 90) then message, /informational, $
      'Non-standard PVi_1 and/or PVi_2 values -- ignored'
;
;  Convert phi0 and theta0 to radians
;
phi0   = (!dpi / 180.d0) * phi0
theta0 = (!dpi / 180.d0) * theta0
;
;  Get the projection parameter thetab.  If not found, use the default value
;  of 90 degrees.
;
thetab = 90.d0
if tag_exist(wcs, 'proj_names', /top_level) then begin
    name = 'PV' + ntrim(wcs.iy+1) + '_1'
    w = where(wcs.proj_names eq name, count)
    if count gt 0 then thetab = wcs.proj_values[w[0]]
endif
;
;  Convert thetab to radians.
;
thetab = (!dpi / 180.d0) * thetab
;
;  Get the celestial longitude and latitude of the fiducial point.
;
alpha0 = wcs.crval[wcs.ix] * cx
delta0 = wcs.crval[wcs.iy] * cy
;
;  Get the native longitude (phip) of the celestial pole.  Look for the LONPOLE
;  (or PVi_3) keyword.  If not found, use the default value.  Convert to
;  radians.
;
if delta0 ge theta0 then phip=0 else phip=180
if tag_exist(wcs, 'proj_names', /top_level) then begin
    w = where(wcs.proj_names eq 'LONPOLE', count)
    if count gt 0 then phip = wcs.proj_values[w[0]]
    name = 'PV' + ntrim(wcs.ix+1) + '_3'
    w = where(wcs.proj_names eq name, count)
    if count gt 0 then phip = wcs.proj_values[w[0]]
endif
if (phip ne 180) and (delta0 ne halfpi) then message, /informational, $
  'Non-standard LONPOLE value ' + ntrim(phip)
phip   = (!dpi / 180.d0) * phip
;
;  Calculate the native spherical coordinates.
;
phi = atan(cx*coord[wcs.ix,*],-cy*coord[wcs.iy,*])
r_theta = sqrt((cx*coord[wcs.ix,*])^2 + (cy*coord[wcs.iy,*])^2)
zetab = (halfpi - thetab) / 2.d0
if cos(zetab) eq 0 then begin
    c = 0.d0
end else if (cos(zetab) eq 1) or (tan(zetab) eq 0) then begin
    c = -0.5d0
end else c = alog(cos(zetab))/tan(zetab)^2
;
;  Reiteratively solve for zeta.
;
if n_elements(k_tolerance) eq 1 then tolerance = k_tolerance else $
  tolerance = 1d-8
if n_elements(k_max_iter) eq 1 then max_iter = k_max_iter else max_iter = 1000
zeta = atan(r_theta / 2.d0)
n_iter = 0
repeat begin
    n_iter = n_iter + 1
    diff = 0.d0*zeta
    w = where(zeta gt 0, n)
    diff[w] = alog(cos(zeta[w]))/tan(zeta[w])
    diff = -(r_theta + 2.d0*(diff + c*tan(zeta))) / $
      (2.d0*(1+alog(cos(zeta))*sin(zeta)^2 - c/cos(zeta)^2))
    zeta = zeta - diff
;
;  If zeta has grown too large, then generate a new random starting point.
;
    w = where(zeta ge halfpi, n)
    if n gt 0 then zeta[w] = (0.9+0.1*randomu(seed,n))*halfpi
endrep until (max(abs(diff)) lt tolerance) or (n_iter ge max_iter)
theta = halfpi - 2*zeta
;
;  Calculate the celestial spherical coordinates.
;
if delta0 ge halfpi then begin
    alpha = alpha0 + phi - phip - !dpi
    delta = theta
end else if delta0 le -halfpi then begin
    alpha = alpha0 - phi + phip
    delta = -theta
end else begin
    dphi = phi - phip
    cos_dphi = cos(dphi)
    sin_theta = sin(theta)
    cos_theta = cos(theta)
    alpha = alpha0 + atan(-cos_theta*sin(dphi), $
        sin_theta*cos(delta0)-cos_theta*sin(delta0)*cos_dphi)
    delta = asin(sin_theta*sin(delta0) + $
                 cos_theta*cos(delta0)*cos_dphi)
endelse
;
;  Convert back into the original units.
;
coord[wcs.ix,*] = alpha / cx
coord[wcs.iy,*] = delta / cy
;
end