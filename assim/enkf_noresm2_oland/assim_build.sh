#!/bin/sh -e

# settings used for standalone build 
: ${ASSIMROOT:=`readlink -f \`dirname $0\``} 
: ${ASSIMCODE_ENKF:=$ASSIMROOT/EnKF}
: ${ASSIMCODE_PREP_OBS:=$ASSIMROOT/prep_obs}
: ${SETUPROOT:=../../setup/noresm2} ; . $SETUPROOT/settings/setmach.sh 
: ${ANALYSISROOT:=$WORK/noresm/assim_standalone/`basename $ASSIMROOT`} 

echo + build EnKF
mkdir -p $ANALYSISROOT/bld/EnKF/TMP
cd $ANALYSISROOT/bld/EnKF
cp -f $ASSIMROOT/shared/* . 
cp -f $ASSIMROOT/EnKF/* . 
make clean
make  

echo + build prep_obs
mkdir -p $ANALYSISROOT/bld/prep_obs/TMP
cd $ANALYSISROOT/bld/prep_obs
cp -f $ASSIMROOT/shared/* . 
cp -f $ASSIMROOT/prep_obs/* . 
make clean
make

echo + create empty file BLOM_DA to activate assimilation in BLOM 
cd $ANALYSISROOT
touch BLOM_DA

echo +  Link SM obs 
ln -sfn /cluster/shared/noresm/norcpm/Obs/SM/cci_sm_obs/ INPUT_SM

echo + create empty file CLM_DA to activate assimilation in CLM
cd $ANALYSISROOT
touch CLM_DA

# fresh private copy of the source, built where it will run
rm -rf "${ANALYSISROOT:?}/CLMDA_FORT"
rm -f  "${ANALYSISROOT:?}/clm5_da" "${ANALYSISROOT:?}/clm5_da.exe"     # no stale binaries
cp -rf $ASSIMROOT/CLMDA_FORT .

# Build in a SUBSHELL: the module purge/load below affects only this block and
# is gone afterwards, so it cannot conflict with the modules/toolchain of the model run.
(
  module purge
  module load netCDF-Fortran/4.5.2-iompi-2020a
  cd $ANALYSISROOT/CLMDA_FORT
  make clean
  make       || exit 1
  make check || exit 1
) || { echo "CLMDA_FORT build or check failed"; exit 1; }

cd $ANALYSISROOT
[ -x ./clm5_da ]     || { echo "clm5_da (wrapper) was not created"; exit 1; }
[ -x ./clm5_da.exe ] || { echo "clm5_da.exe was not created"; exit 1; }
