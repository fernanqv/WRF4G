##Postprocessor for "operativo". Must be rewritten to use the CLWRF output to computed intra hourly extreme values.
#####################################################################################################################
#! /bin/bash
#
#PBS -q macc
#PBS -N post_operatorio

sdate=$1
syy=${sdate:0:4}
smm=${sdate:4:2}
sdd=${sdate:6:2}

cd /oceano/gmeteo/WORK/markel/experimentos/operativo_gfs

source /software/ScientificLinux/4.6/etc/bashrc
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/vols/oceano/software/CentOS/5.2/GMT/netcdf-3.6.3/lib
#source /software/etc/bashrc
weajdir="/oceano/gmeteo/WORK/markel/wrf4g/util/postprocess"
  weajpy="${weajdir}/wrfnc_extract_and_join.py"
  weajtbl="${weajdir}/wrfnc_extract_and_join.table"
  weajatt="${weajdir}/wrfnc_extract_and_join.gattr_operGFS"
outdir="/oceano/gmeteo/DATA/UC/OPERWRF12/${sdate}"
mkdir -p ${outdir}

cat << EOF > grid15.cdo
gridtype = lonlat
xsize = 97
ysize = 58
xfirst = -10.
xinc = 0.15
yfirst = 35.5
yinc = 0.15
EOF

cat << EOF > grid05.cdo
gridtype = lonlat
xsize = 174
ysize = 43
xfirst = -9.7
xinc = 0.05
yfirst = 41.95
yinc = 0.05
EOF

function get_nc_timerecords(){
  ncdump -h $1 | grep UNLIMITED | tr -d -c '0-9'
}


function procesa(){
  source /oceano/gmeteo/WORK/markel/shell/addattr.R.sh
  rea=$1
  dom=$2
  grid=$3
  python ${weajpy} \
  -v T2C,U10ER,V10ER,RAIN,SWDOWN \
  -o tmp.nc \
  -t ${weajtbl} \
  -a ${weajatt} \
  -r ${syy}-${smm}-${sdd}_12:00:00 \
  ${rea}/output/wrfout_${dom}*.nc
  cdo remapbil,${grid} tmp.nc ${outdir}/$(basename ${rea})_${dom}.nc

  addattr  ${outdir}/$(basename ${rea})_${dom}.nc  "height" "_CoordinateAxisType" "Height"
  addattr  ${outdir}/$(basename ${rea})_${dom}.nc  "heightv" "_CoordinateAxisType" "Height"
  
  #ntimes=$(get_nc_timerecords tmp2.nc)
  #ncap2 -O -s 'tas=T2-273.15;RAIN=RAINNC+RAINC;prh=RAIN(1:,:,:)-RAIN(:'$(($ntimes -2))',:,:);' tmp2.nc tmp.nc 
  #ncks -O -x -v RAIN,RAINC,RAINNC,T2 tmp.nc ${outdir}/$(basename ${rea})_${dom}.nc

  cdo -r settime,00:00 -daymax -selvar,tas ${outdir}/$(basename ${rea})_${dom}.nc tasmax.temp
  cdo -r settime,00:00 -daymin -selvar,tas ${outdir}/$(basename ${rea})_${dom}.nc tasmin.temp
  cdo -r settime,00:00 -daysum \
    -settaxis,${syy}-${smm}-${sdd},5:00:00,1hour \
    -selvar,pr ${outdir}/$(basename ${rea})_${dom}.nc ${outdir}/$(basename ${rea})_${dom}.pr.nc

  #cdo -r setreftime,${syy}-${smm}-${sdd},00:00:00 pr.temp ${outdir}/$(basename ${rea})_${dom}.pr.nc  
  #ncrename -v prh,pr ${outdir}/$(basename ${rea})_${dom}.pr.nc

  cdo chname,tas,tasmax tasmax.temp ${outdir}/$(basename ${rea})_${dom}.t2x.nc
  cdo chname,tas,tasmin tasmin.temp ${outdir}/$(basename ${rea})_${dom}.t2n.nc

  #Adds coordinate axis attributes so toolsui can read the grid correctly:

  addattr ${outdir}/$(basename ${rea})_${dom}.t2x.nc "height" "_CoordinateAxisType" "Height"
  addattr ${outdir}/$(basename ${rea})_${dom}.t2n.nc "heightv" "_CoordinateAxisType" "Height"

  rm -f tmp.nc tasmax.temp tasmin.temp

  # Temperature anomaly
  #phys=$(echo $(basename ${rea}) | sed -e 's/.*__//')
  #cdo selvar,tas ${outdir}/$(basename ${rea})_${dom}.nc ${outdir}/$(basename ${rea})_${dom}.tash.nc
  #cdo sub ${outdir}/$(basename ${rea})_${dom}.tash.nc $(dirname ${outdir})/tasref_${phys}_${dom}.nc ${outdir}/$(basename ${rea})_${dom}.tasanom.nc
  #rm ${outdir}/$(basename ${rea})_${dom}.tash.nc
  #ncrename -v tas,tasanom ${outdir}/$(basename ${rea})_${dom}.tasanom.nc
}


for rea in /oceano/gmeteo/SCRATCH/MDM.UC/experiments/oper_gfs${sdate}/*; do
  echo "Processing: $rea"
  procesa ${rea} d01 grid15.cdo
  procesa ${rea} d02 grid05.cdo

  #Makes a file with 3-hourly data ready to be plotted as a meteogram by Imeteo.
  
  phys=$(echo $(basename $rea) | awk -F__ '{print $2}')

  #Accumulated precipitation.

  cdo shifttime,+1hour \
    -seltimestep,$(seq -s, 2 3 107) \
    -runsum,3 \
    -selvar,pr ${outdir}/$(basename ${rea})_d01.nc ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc.temp1

  #Temperature.

  cdo seltimestep,$(seq -s, 4 3 109) \
    -selvar,tas ${outdir}/$(basename ${rea})_d01.nc ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc.temp2

  #Maximum temperature.

  cdo chname,tas,tasmax \
    -shifttime,+1hour \
    -seltimestep,$(seq -s, 2 3 108) \
    -runmax,3 \
    -selvar,tas ${outdir}/$(basename ${rea})_d01.nc ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc.temp3

  #Minimum temperature.

  cdo chname,tas,tasmin \
    -shifttime,+1hour \
    -seltimestep,$(seq -s, 2 3 108) \
    -runmin,3 \
    -selvar,tas ${outdir}/$(basename ${rea})_d01.nc ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc.temp4

  #10m instantáneous winds

  cdo seltimestep,$(seq -s, 4 3 109) \
    -selvar,uas ${outdir}/$(basename ${rea})_d01.nc ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc.temp5

  cdo seltimestep,$(seq -s, 4 3 109) \
    -selvar,vas ${outdir}/$(basename ${rea})_d01.nc ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc.temp6

  cdo merge ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc.temp1 \
	    ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc.temp2 \
	    ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc.temp3 \
            ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc.temp4 \
            ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc.temp5 \
            ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc.temp6 \
            ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc

  rm ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc.temp*

  #Adds the appropiate attributes to the variables (Soon extract and joint should do this).

  addattr ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc "height" "_CoordinateAxisType" "Height"
  addattr ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc "heightv" "_CoordinateAxisType" "Height"
  addattr ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc "tasmax" "cell_method" "time:maximum"
  addattr ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc "tasmin" "cell_method" "time:minimum"
  addattr ${outdir}/oper_gfs_mgrama_${sdate}__${phys}_d01.nc "pr"     "cell_method" "time:sum"

done

#Generates a nclm to merge the 2 physics creating a new dimension "ensemble".

cd ${outdir}

cat << __EOF > oper_gfs_mgrama_${sdate}_d01.ncml

  <netcdf xmlns="http://www.unidata.ucar.edu/namespaces/netcdf/ncml-2.2">
	  <variable name="ensemble" type="String">
	  <attribute name="long_name" value="Ensemble of physics perturbations"/>
	  <attribute name="_CoordinateAxisType" value="Ensemble" />
	  </variable>
	  <aggregation dimName="ensemble" type="joinNew">
		  <variableAgg name="tasmin"/>
		  <variableAgg name="tasmax"/>
		  <variableAgg name="pr"/>
		  <variableAgg name="uas"/>
		  <variableAgg name="vas"/>
		  <variableAgg name="tas"/>
		  <netcdf location="oper_gfs_mgrama_${sdate}__4_1_1_1_1_1_1_d01.nc" coordValue="4_1_1_1_1_1_1"/>
		  <netcdf location="oper_gfs_mgrama_${sdate}__5_1_1_1_2_2_2_d01.nc" coordValue="5_1_1_1_2_2_2"/>
      </aggregation>
  </netcdf>

__EOF

java="/oceano/gmeteo/users/markel/usr/jre1.6.0_13/bin/java"
netcdf_java="/oceano/gmeteo/users/markel/usr/netcdfAll-4.1.jar"

${java} -Xmx512m -classpath ${netcdf_java} ucar.nc2.dataset.NetcdfDataset \
 -in oper_gfs_mgrama_${sdate}_d01.ncml -out oper_gfs_mgrama_${sdate}_d01.nc


rm -f grid15.cdo
rm -f grid05.cdo
#rm -f ${outdir}/oper_gfs_mgrama_${sdate}_d01.nc.temp
