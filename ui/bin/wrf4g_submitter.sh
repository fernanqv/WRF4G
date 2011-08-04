#! /bin/bash
#
# wrf4g_submitter
#
# function get_ni_vars()
# function get_nin_vars()
# function get_nim_vars()
# function cycle_chunks(realization_name, realization_start_date, realization_end_date)
# function cycle_hindcasts(realization_name, start_date, end_date)
# function cycle_time(realization_name, start_date, end_date)
#

nchunks=""
isdry="no"
justone="no"


 
if test ${#} -ge 1; then
  while test "$*"; do
    case $1 in
      --dry-run)
          isdry="yes"
	  WRF4G_FLAGS="$WRF4G_FLAGS --dry-run"
        ;;
      --run-just-one)
          justone="yes"
        ;;
      --nchunks)
	  nchunks=$2
          shift
        ;;      
      --reconfigure)
      	  reconfigure="yes"
          WRF4G_FLAGS="$WRF4G_FLAGS -r"
        ;;
      --verbose)
          verbose="yes"
          WRF4G_FLAGS="$WRF4G_FLAGS -v" 
        ;;
      --rerun)
          rerun="yes"
        ;;
      --force)
          force="yes"
        ;;
      --help)
          echo "Usage: $0  --dry-run --nchunks --verbose"
          exit 
          ;;
      *)
        echo "Unknown argument: $1"
        exit
        ;;
    esac
    shift
  done
fi

if test -z $WRF4G_LOCATION; then
   echo '$WRF4G_LOCATION variable not established. Please export WRF4G_LOCATION and try again'
   exit 1
fi

userdir=`pwd`

#
#  Prepare environment
#
export PATH=${WRF4G_LOCATION}/bin:${PATH}
export PYTHONPATH=${PYTHONPATH}:${WRF4G_LOCATION}/lib/python

#
#  Load configuration files
#
grep "DB_.*=" ${WRF4G_LOCATION}/etc/framework4g.conf | sed -e 's/\ *=\ */=/' > db4g.conf
export DB4G_CONF=`pwd`/db4g.conf ; source $DB4G_CONF

if test -f resources.wrf4g; then
  mv resources.wrf4g resources.wrf4g.orig
  sed -e 's/\ *=\ */=/' resources.wrf4g.orig > resources.wrf4g
else
  sed -e 's/\ *=\ */=/' ${WRF4G_LOCATION}/etc/resources.wrf4g | sed -e "s#\$WRF4G_LOCATION#$WRF4G_LOCATION#" >resources.wrf4g|| exit ${ERROR_MISSING_WRF4GSRC}
fi


export RESOURCES_WRF4G=${PWD}/resources.wrf4g ; source $RESOURCES_WRF4G
sed -e 's/\ *=\ */=/' experiment.wrf4g > source.it        || exit ${ERROR_MISSING_WRFINPUT}
source source.it && rm source.it
source ${WRF4G_LOCATION}/lib/bash/wrf_util.sh       || exit ${ERROR_MISSING_WRFUTIL}

export WRF4G_EXPERIMENT="${experiment_name}"


function get_ni_vars(){
  set | grep '^NI_' | sed -e 's/^NI_\(.*\)=.*$/\1/'
}

function get_nin_vars(){
  set | grep '^NIN_' | sed -e 's/^NIN_\(.*\)=.*$/\1/'
}

function get_nim_vars(){
  set | grep '^NIM_' | sed -e 's/^NIM_\(.*\)=.*$/\1/'
}

function is_dry_run(){
  test "${isdry}" = "yes"
}
function if_not_dry(){
  comando=$*
  if ! is_dry_run; then
    $comando
  fi
}

function cannot_mkdir(){
  dir=$1
  echo "Could not create directory ${dir}. Exiting..."
  exit
}

function rematch(){
  pattern=$1
  string=$2
  if test "${pattern:0:10}" = "from_file:"; then
    grep -q "$string" $(echo ${pattern} | sed -e 's/from_file://')
  else
    echo "$string" | grep -Eq "^${pattern}$"
  fi
}

function cycle_chunks(){
  local realization_name
  local eyy emm edd ehh 
  local cyy cmm cdd chh current_date
  local fyy fmm fdd fhh final_date
  realization_name=$1
  id_rea=$2
  export WRF4G_REALIZATION="${realization_name}"
  realization_start_date=$3
  realization_end_date=$4
  current_date=${realization_start_date}
  
  echo -e "\t---> cycle_chunks: ${realization_name} ${realization_start_date} ${realization_end_date}">&2

  read cyy cmm cdd chh trash <<< $(echo ${current_date} | tr '_:T-' '    ')
  read eyy emm edd ehh trash <<< $(echo ${realization_end_date} | tr '_:T-' '    ')
  chunkno=1
  chunkjid=""
  while test ${cyy}${cmm}${cdd}${chh} -lt ${eyy}${emm}${edd}${ehh}
  do
    export WRF4G_CHUNK="$(printf '%04d' ${chunkno})"
    let hours=chh+chunk_size_h
    final_date=$(date +%Y-%m-%d_%H:%M:%S -u -d"${cyy}${cmm}${cdd} $hours hours")
    read fyy fmm fdd fhh trash <<< $(echo ${final_date} | tr '_:T-' '    ')
    if test ${fyy}${fmm}${fdd}${fhh} -gt ${eyy}${emm}${edd}${ehh}; then
      final_date=${realization_end_date}
      read fyy fmm fdd fhh trash <<< $(echo ${final_date} | tr '_:T-' '    ')
    fi
    
    echo -e "\t\t---> chunks ${chunkno}: ${realization_name} ${current_date} ${final_date}">&2
    id_chunk=$(WRF4G.py $WRF4G_FLAGS Chunk prepare id_rea=${id_rea},id_chunk=${chunkno},sdate=${current_date},edate=${final_date},wps=0,status=0)  

    current_date=${final_date}
    read cyy cmm cdd chh trash <<< $(echo ${current_date} | tr '_:T-' '    ')
    let chunkno++
    test "${justone}" = "yes" && exit
  done
}

function cycle_hindcasts(){
  realization_name=$1
  id_exp=$2
  start_date=$3
  end_date=$4
  multiparams_label=$5
  
  echo -e "\n---> cycle_hindcasts: $1 $2 $3 $4 $5">&2
  current_date=${start_date}
  read cyy cmm cdd chh trash <<< $(echo ${current_date} | tr '_:T-' '    ')
  read eyy emm edd ehh trash <<< $(echo ${end_date} | tr '_:T-' '    ')
  let hours=chh+simulation_length_h
  final_date=$(date +%Y-%m-%d_%H:%M:%S -u -d"${cyy}${cmm}${cdd} $hours hours")
  read fyy fmm fdd fhh trash <<< $(echo ${final_date} | tr '_:T-' '    ')
  while test ${cyy}${cmm}${cdd}${chh} -le ${eyy}${emm}${edd}${ehh}
  do
    let hours=chh+simulation_length_h
    final_date=$(date +%Y-%m-%d_%H:%M:%S -u -d"${cyy}${cmm}${cdd} $hours hours")
    read fyy fmm fdd fhh trash <<< $(echo ${final_date} | tr '_:T-' '    ')
    if test ${fyy}${fmm}${fdd}${fhh} -gt ${eyy}${emm}${edd}${ehh}; then
      break # new behavior (delete these line to go back)
      final_date=${end_date}
      read fyy fmm fdd fhh trash <<< $(echo ${final_date} | tr '_:T-' '    ')
    fi
    rea_name="${realization_name}__${cyy}${cmm}${cdd}${chh}_${fyy}${fmm}${fdd}${fhh}"
    #echo " ${realization_name}  $(printf "%4d" ${chunkno})  ${current_date}  ${final_date}"
    echo "WRF4G.py $WRF4G_FLAGS Realization prepare id_exp=${id_exp},name=${rea_name},sdate=${current_date},edate=${final_date},status=0,cdate=${current_date},multiparams_label=${multiparams_label}"
    id_rea=$(WRF4G.py $WRF4G_FLAGS Realization prepare id_exp=${id_exp},name=${rea_name},sdate=${current_date},edate=${final_date},status=0,cdate=${current_date},multiparams_label=${multiparams_label})
    if test $?  -ne 0; then
	 echo $id >&2
	 exit $?
    fi

    if test ${id_rea} -ge 0; then
        #create_wrf4g_realization(id_exp,name,sdate,edate,status,cdate)
        cycle_chunks  ${realization_name} ${id_rea} ${current_date} ${final_date}
    fi
    #
    #  Cycle dates
    #
    let hoursnext=chh+simulation_interval_h
    current_date=$(date +%Y-%m-%d_%H:%M:%S -u -d"${cyy}${cmm}${cdd} $hoursnext hours")
    read cyy cmm cdd chh trash <<< $(echo ${current_date} | tr '_:T-' '    ')
  done
}

function cycle_time(){
  realization_name=$1
  id_exp=$2
  start_date=$3
  end_date=$4
  multiparams_label=$5
  
   
  case ${multiple_dates} in
    1)
      test -n "${simulation_length_h}" || exit
      test -n "${simulation_interval_h}" || exit
      cycle_hindcasts  ${realization_name} ${id_exp} ${start_date} ${end_date} ${multiparams_label}
      ;;
    0)
      echo "---> Continuous run">&2
      id_rea=$(WRF4G.py $WRF4G_FLAGS Realization prepare id_exp=${id_exp},name=${realization_name},sdate=${start_date},edate=${end_date},status=0,cdate=${start_date},multiparams_label=${multiparams_label})
      if test $?  -ne 0; then
           echo $id >&2
           exit $?exit
      fi

      if test ${id_rea} -ge 0; then
            cycle_chunks  ${realization_name} ${id_rea} ${start_date} ${end_date}
      fi
      ;;
  esac
}


echo -e "\n\t=========== PREPARING EXPERIMENT ${WRF4G_EXPERIMENT} ============\n">&2

# TODO: Rerun
if test "$rerun" == yes; then
   echo "rerun"
fi

#
#  Initial override of namelist values
#
if test "${multiple_parameters}" -ne "0"; then
    if [ -z ${multiparams_labels// /} ]; then
        mlabel=${multiparams_combinations// /}
        multiparams_labels=$(py_sort_mlabels ${mlabel})        
    else
        mlabel=${multiparams_labels// /}
        multiparams_labels=$(py_sort_mlabels ${mlabel})
    fi
else
   multiparams_labels=''   
fi

if test -z "${chunk_size_h}"; then
    sec=$(datediff_s ${end_date} ${start_date})
    let chunk_size_h=${sec}/3600
fi

if test "${multiple_dates}" -eq "0" -a -z "${NI_restart_interval}"; then
    let NI_restart_interval=${chunk_size_h}*60
fi

data="name=${experiment_name},sdate=${start_date},edate=${end_date},multiple_parameters=${multiple_parameters},multiple_dates=${multiple_dates},basepath=${WRF4G_BASEPATH},multiparams_labels=${multiparams_labels}"  #,experiment_description=\'${experiment_description}\'"
id=$(WRF4G.py $WRF4G_FLAGS Experiment  prepare $data )
if test $?  -ne 0; then
   echo $id >&2
   exit $?
fi

if test ${id} -ge 0; then
        echo "Preparing namelist...">&2
	if ! is_dry_run; then 
          wrf_ver=$( echo ${WRF_VERSION} | awk -F_ '{ print $1}' )
          namelist=${WRF4G_LOCATION}/etc/templates/${wrf_ver}/namelist.input
          if test -f ${namelist}; then
   	    cp ${namelist} ${userdir}/namelist.input.base
	    fortnml -wof namelist.input.base -s max_dom ${max_dom}
          else
            echo "There is not a namelist template for WRF ${wrf_ver} (File ${namelist} do not exists) "
            exit 10
          fi

	  for var in $(get_ni_vars); do
	    fnvar=${var/__/@}
	    fortnml -wof namelist.input.base -s $fnvar -- $(eval echo \$NI_${var})
	  done
	  for var in $(get_nim_vars); do
	    fnvar=${var/__/@}
	    fortnml -wof namelist.input.base -s $fnvar -- $(eval "echo \$NIM_${var} | tr ',' ' '")
	  done
	  for var in $(get_nin_vars); do
	    fnvar=${var/__/@}
	    fortnml -wof namelist.input.base -m $fnvar -- $(eval echo \$NIN_${var})
	  done
          cp namelist.input.base namelist.input
      
	fi
    
	#
	#  Multiparams support. Physical parameters overwritten!
	#
        mlabels=${multiparams_labels}
	if test "${multiple_parameters}" -ne "0"; then
          icomb=1
          for mpid in $(echo ${multiparams_combinations} | tr '/' ' '); do
            realabel=$(tuple_item ${multiparams_labels//\//,} ${icomb})
            echo -e "\n--->Realization: multiparams=${realabel} ${start_date} ${end_date}">&2
            if_not_dry cp namelist.input.base namelist.input
            iparam=1
            for var in $(echo ${multiparams_variables} | tr ',' ' '); do
              thisparam=$(tuple_item ${mpid} ${iparam})
              if echo ${thisparam} | grep -q ':' ; then
                if_not_dry fortnml_setm namelist.input $var ${thisparam//:/ }
              else
                nitems=$(tuple_item ${multiparams_nitems} ${iparam})
               if_not_dry fortnml_setn namelist.input $var ${nitems} ${thisparam}
              fi
              let iparam++
            done           
	    cycle_time "${experiment_name}__${realabel}" ${id} ${start_date} ${end_date} ${realabel}
            let icomb++
           done 


	else
	  echo -e "\n---> Single params run">&2
	  cycle_time "${experiment_name}" ${id} ${start_date} ${end_date}
        fi
	if_not_dry rm namelist.input namelist.input.base
else 
   if test "$force" != "yes"; then
        echo "This simulation has already been submitted. Are you sure you want to submit it again? (y/n)?"
        read a
        if [[ $a == "Y" || $a == "y" ]]; then
          echo "Relaunching experiment" 
        else
          exit 5
        fi
   fi
fi



echo -e "\n\t========== SUBMITTING EXPERIMENT ${WRF4G_EXPERIMENT} ===========\n">&2
id_exp=$(WRF4G.py $WRF4G_FLAGS Experiment get_id_from_name name=${WRF4G_EXPERIMENT})

if ! is_dry_run; then 
  mkdir -p .${WRF4G_EXPERIMENT}/bin
  cd .${WRF4G_EXPERIMENT}
   cp ../db4g.conf ../resources.wrf4g ../experiment.wrf4g .
   #o=$(vcp ${WRF4G_BASEPATH}/${WRF4G_EXPERIMENT}/db4g.conf . )
   #o=$(vcp ${WRF4G_BASEPATH}/${WRF4G_EXPERIMENT}/resources.wrf4g .)
   #o=$(vcp ${WRF4G_BASEPATH}/${WRF4G_EXPERIMENT}/experiment.wrf4g . )
   cp ${WRF4G_LOCATION}/bin/vcp bin/
   tar -czf sandbox.tar.gz db4g.conf resources.wrf4g experiment.wrf4g bin/
   rm -rf wrf* bin
   cp ${WRF4G_LOCATION}/etc/templates/WRF4G_ini.sh .
fi

#Submit jobs
id=$(WRF4G.py $WRF4G_FLAGS Experiment run id=${id_exp} $nchunks)
if ! is_dry_run; then 
  cd ..
#  rm -rf tar_temp
else
  id=$(WRF4G.py $WRF4G_FLAGS Experiment delete id=${id_exp}) 
fi

rm -f $RESOURCES_WRF4G $DB4G_CONF

if test -f resources.wrf4g.orig; then
  mv resources.wrf4g.orig resources.wrf4g
fi