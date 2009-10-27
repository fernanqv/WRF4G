
RFLAG="-R-11/5/35.5/44"
RFLAG4GS="-R-12/6/35/45"
RJFLAG="${RFLAG} -JM13c"
BFLAG="-Bf1a3/f1a3WeSn"

NCFILE=$1
var=$(basename ${NCFILE//*_/} .nc)
cptfile="cpts/${var}.cpt"

shift
has_height_dim=0
is_curvilinear=0
national_bound=0
no_nn=0
rec=0
zmin=0
zmax=0
dz=0
anglectl=0.5
sysize=0.33c
title=""
out=""
while test "$*"
do
  case $1 in
    has_height_dim) has_height_dim=1;;
    is_curvilinear) is_curvilinear=1;;
    national_bound) national_bound=1;;
    no_nn) no_nn=1;;
    label) label=$2; shift;;
    cpt) cptfile=$2; shift;;
    var) var=$2; shift;;
    rec) rec=$2; shift;;
    zmin) zmin=$2; shift;;
    zmax) zmax=$2; shift;;
    dz) dz=$2; shift;;
    anglectl) anglectl=$2; shift;;
    sysize) sysize=$2; shift;;
    title) title=$2; shift;;
    out) out=$2; shift;;
  esac
  shift
done

if test -n "$out"; then
  FNAMEOUT="$out"
else
  FNAMEOUT="$(basename $NCFILE .nc)${label}.eps"
fi
XYZFILE=$(basename $NCFILE .nc)${label}.xyz

function py_getxyz_curv(){
  ncfilevar=$1
  irec=$2
python << End_Of_Python
from Scientific.IO.NetCDF import *
from Numeric import array
import os, sys, time
dataset = "${ncfilevar}"   # file.nc:var
irec = ${irec}
ifile, varname = dataset.split(":")
nc = NetCDFFile(ifile, "r")
var = nc.variables[varname]
lats = nc.variables["lat"]
lons = nc.variables["lon"]
try:    sf = var.scale_factor
except: sf = 1.
for i in range(len(lats)):
  for j in range(len(lats[0])):
    if ${has_height_dim}:
      print "%9.4f %9.4f %.5e" % (lons[i,j], lats[i,j], array(var[irec,0,i,j])*sf)
    else:
      print "%9.4f %9.4f %.5e" % (lons[i,j], lats[i,j], array(var[irec,i,j])*sf)
End_Of_Python
}

function py_getxyz(){
  ncfilevar=$1
  irec=$2
python << End_Of_Python
from Scientific.IO.NetCDF import *
from Numeric import array
import os, sys, time
dataset = "${ncfilevar}"   # file.nc:var
irec = ${irec}
ifile, varname = dataset.split(":")
nc = NetCDFFile(ifile, "r")
var = nc.variables[varname]
try:
  lats = nc.variables["lat"]
  lons = nc.variables["lon"]
except KeyError:
  lats = nc.variables["latitude"]
  lons = nc.variables["longitude"]
try:    sf = var.scale_factor
except: sf = 1.
for i in range(len(lons)):
  for j in range(len(lats)):
    if ${has_height_dim}:
      print "%10.5f %10.5f %.5e" % (lons[i], lats[j], sf * array(var[irec,0,j,i]))
    else:
      print "%10.5f %10.5f %.5e" % (lons[i], lats[j], sf * array(var[irec,j,i]))
End_Of_Python
}

gmtset PAPER_MEDIA a4+
gmtset PLOT_DEGREE_FORMAT dddF
gmtset PAGE_ORIENTATION portrait

echo "Plotting file $NCFILE ..."

if [ ${no_nn} -eq 0 ]; then
  if [ ${is_curvilinear} -ne 0 ]; then
    py_getxyz_curv $NCFILE:${var} ${rec} > $XYZFILE
  else
    py_getxyz $NCFILE:${var} ${rec} > $XYZFILE
  fi
  awk '$1>180 {print $1-360,$2,$3} $1<=180 {print $1,$2,$3}' $XYZFILE > ${XYZFILE}.tmp
  gmtselect ${RFLAG4GS} ${XYZFILE}.tmp | awk '$3 > -1e30' > $XYZFILE
  rm ${XYZFILE}.tmp
fi

minmax $XYZFILE

cres="-Di"

function pysymbol(){
  python << end_of_py
print "%.2f %.2f M" % (-0.5+${anglectl},            -0.50)
print "%.2f %.2f D" % (            0.50, -0.5+${anglectl})
print "%.2f %.2f D" % ( 0.5-${anglectl},             0.50)
print "%.2f %.2f D" % (           -0.50,  0.5-${anglectl})
print "%.2f %.2f D" % (-0.5+${anglectl},            -0.50)
end_of_py
}
function pysymbolsq(){
  python << end_of_py
print "%.2f %.2f M" % (-0.5+${anglectl},           -0.50)
print "%.2f %.2f D" % ( 0.5-${anglectl},            -0.5)
print "%.2f %.2f D" % ( 0.5-${anglectl},             0.5)
print "%.2f %.2f D" % (-0.5+${anglectl},            0.50)
print "%.2f %.2f D" % (-0.5+${anglectl},           -0.50)
end_of_py
}

if test $zmin -ne $zmax; then
  makecpt -C$cptfile -T${zmin}/$zmax/$dz -Z > pepe.cpt
  cptfile=pepe.cpt
fi

psxy /dev/null $RJFLAG -K > $FNAMEOUT
pscoast $RJFLAG -Gc -A0/0/1 ${cres} -O -K >> $FNAMEOUT
  if [ ${is_curvilinear} -ne 0 ]; then
    pysymbol > tile.def
    psxy ${XYZFILE} $RJFLAG -C${cptfile} -Sktile/$sysize -N -O -K >> $FNAMEOUT
  else
    pysymbolsq > tile.def
    psxy ${XYZFILE} $RJFLAG -C${cptfile} -Sktile/$sysize -N -O -K >> $FNAMEOUT
  fi
  if [ ${national_bound} -eq 1 ]; then
    pscoast $RJFLAG -A0/0/1 ${cres} -N1/5,white -O -K >> $FNAMEOUT
  fi
pscoast $RJFLAG -Q -O -K >> $FNAMEOUT
pscoast $RJFLAG $BFLAG -A0/0/1 ${cres} -W3 -O -K >> $FNAMEOUT
if [ -n "${title}" ]; then
  pstext $RJFLAG -O -K >> $FNAMEOUT << EOF
    -4.5 43.5 20 0 0 CM $title
EOF
fi
psxy /dev/null $RJFLAG -O >> $FNAMEOUT

psscale -D8c/10c/18c/1c -C${cptfile} -E > ${FNAMEOUT/.eps/.scale.eps}
fixbb ${FNAMEOUT/.eps/.scale.eps} tmp.eps
mv tmp.eps ${FNAMEOUT/.eps/.scale.eps}

# Convert to JPG and drop the eps.
#fpng="figs/$(basename $FNAMEOUT .eps).jpg"
#convert -density 200 $FNAMEOUT ${fpng}
#mogrify -crop 900x660+286+1308 ${fpng}
#mogrify -fill white -draw 'rectangle 600,500 900,660' ${fpng}
#rm -f $FNAMEOUT

rm -f ${XYZFILE} tile.def .gmt*
rm -f pepe.cpt
