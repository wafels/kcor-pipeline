;
;  Name: kcor_find_image
;
;  Description:
;    procedure to find either the edge of the occulting disk 
;    Modified from comp_find_image.pro
;    
;  Input Parameters:
;    data - the data array in which to locatethe image
;    radius_guess - the guess of the radius based on the occulter size
;
;  Keyword Parameters:
;    center_guess - guess for the center coordinates. 
;                   if set uses horizontal/vertical scans to guess center
;                   if not set uses center of the array                 
;    drad - the +/- size of the radius which to scan
;    neg_pol - if set, negative discontinuities will be found
;    
;  Output:
;    A 3-element array is returned containing:
;      The x_center, y_center and radius of the occulter
;      chi^2 (chisq) is optionally returned.
;    
;  Routines Called:
;    kcor_radial_der - makes radial scans of the intensity and takes the derivative of these 
;      to locate the discontinuities associated with the occulter edge
;   fitcircle - R. Maisner code to fit a circle 
;  
;  Author: Tomczyk
;  Modifier: de Toma 
;
;  Modification History:
;         changed to double precision to find derivative correctly 11/07/2014 GdT
;         added radius_guess as input  11/07/2014 GdT
;         added keyword center_guess  11/07/2014 GdT
;         changed to fitcircle because faster 11/12/2014 GdT
;-

 function kcor_find_image, data, radius_guess, center_guess=center_guess, drad=drad, chisq=chisq, debug=debug

default, debug, 0
default, center_guess, 0 
default, drad, 40

  ;  Function to find position of image

  ;  A 3-element array is returned containing:
  ;  chi^2 (chisq) is optionally returned.


  data=double(data)

  if debug eq 1 then begin 
  datamax=25000 
  if max(data) lt datamax then datamax=2000
  window, xs=1024,ys=1024, retain=2
  loadct, 0 & tv, bytscl(data, 0, datamax)
  wait, 1 
  endif
  
  isize=size(data)
  xdim = isize(1)
  ydim = isize(2)

  xcen = fix( ( float(xdim) * 0.5 ) - 0.5)
  ycen = fix( ( float(ydim) * 0.5 ) - 0.5)
  
  if keyword_set(center_guess) then begin 
  ;find guess coordinates for the image center

  ;extract cords:

  xtest  = data(*, ycen)
  xtest2 = data(*, ycen-50)
  xtest3 = data(*, ycen+50)
  ytest  = data(xcen-60, *)
  ytest2 = data(xcen+60, *)
               
  xmaxl = max(xtest(0   :xcen)  , xl)
  xmaxr = max(xtest(xcen:xdim-1), xr) & xr=xr+xcen
  xmaxl = max(xtest2(0   :xcen)  , xl2)
  xmaxr = max(xtest2(xcen:xdim-1), xr2) & xr2=xr2+xcen
  xmaxl = max(xtest3(0   :xcen)  , xl3)
  xmaxr = max(xtest3(xcen:xdim-1), xr3) & xr3=xr3+xcen

  ymaxb = max(ytest(0   :ycen)  , yb)
  ymaxt = max(ytest(ycen:ydim-1), yt) & yt=yt+ycen
  ymaxb = max(ytest2(0   :ycen)  , yb2)
  ymaxt = max(ytest2(ycen:ydim-1), yt2) & yt2=yt2+ycen

  xcen_guess = (xl + (xr-xl)*0.5  +  xl2 + (xr2-xl2)*0.5  +  xl3 + (xr3-xl3)*0.5)  /3.
  ycen_guess = (yb + (yt-yb)*0.5  +  yb2 + (yt2-yb2)*0.5)  *.5
  
; if center is more than 40 pixels off the center of the array, use  center of the array 

  if abs(xcen_guess-xcen) ge 40 then xcen_guess = xcen
  if abs(ycen_guess-ycen) ge 40 then ycen_guess = ycen
  
     if debug eq 1 then begin 
      !p.multi=[0,1,4]
      plot, xtest, charsize=2
      plot, xtest3, charsize=2
      plot, ytest, charsize=2
      plot, ytest2, charsize=2
      !p.multi=[0,1,1]
      wait, 1      
    endif

  endif else begin 

  xcen_guess = xcen
  ycen_guess = ycen

  endelse

    if debug eq 1 then begin 
     loadct, 0 & tv, bytscl(data, 0, datamax)
     loadct, 39 & draw_circle, xcen_guess, ycen_guess, radius_guess, /dev, color =50, thick=2
     wait, 1 
    endif

  ; find limb positions, array of angles (theta) and limb positions (cent) 
  ; needs double precision for KCor

  kcor_radial_der, data, xcen_guess, ycen_guess, radius_guess, drad, theta, cent

  ; find circle that fits the inflaction points

  x=cent*cos(theta) & x=transpose(x)
  y=cent*sin(theta) & y=transpose(y)
  fitcircle, x,y, xc, yc, r

  
;  Check if fitting routine failed. If so, try fitting using larger radius range 
;  if it fails again, replace fit values with array center and radius_guess

  if(finite(xc) eq 0 or finite(yc) eq 0) then begin
  print, '  WARNING: CENTER NOT FOUND......TRYING LARGER RANGE'
  drad=52
  kcor_radial_der, data, xcen_guess, ycen_guess, radius_guess, drad, theta, cent
  x=cent*cos(theta) & x=transpose(x)
  y=cent*sin(theta) & y=transpose(y)
  fitcircle, x,y, xc, yc, r
  if(finite(xc) eq 0 or finite(yc) eq 0) then begin
  xc= 511.5 - xcen_guess
  yc= 511.5 - ycen_guess
  r = radius_guess
  print, '  WARNING: CENTER NOT FOUND !!!!! '
; ANDREW: add something in the logs so we capture we did not find the center'
  endif
  endif

    a = [ xcen_guess+xc, ycen_guess+yc, r ]

   if debug eq 1 then begin 
    loadct,0 & tv, bytscl(data, 0, datamax)
    loadct,39 & draw_circle, a(0), a(1), a(2), /dev, color=250, thick=1
    print, xcen_guess, ycen_guess, radius_guess
    print, xc, yc, r 
    print, a 
   endif
 
    return, a


end
  
