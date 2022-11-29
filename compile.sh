#!/bin/bash

check_error()
{
  error_no=$?
  if [ $error_no != 0 ];then
    exit $error_no
  fi
}

check_env()
{
  if [ ! -n ${MAPLE_ROOT} ];then
     echo "plz cd to maple root dir and source build/envsetup.sh arm release/debug"
     exit -2
  fi

  if [ ! -f ${BIN_HIR2MPL} ] || [ ! -f ${BIN_MAPLE} ];then
     echo "plz make to ${MAPLE_ROOT} and make tool chain first!!!"
     exit -3
  fi
}

init_parameter()
{
  OUT="a.out"
  LINK_OPTIONS=
  ROOT_DIR=$(cd "$(dirname $0)"; pwd)
  ROOT_OUTPUT=${ROOT_DIR}/output
  MAPLE_ROOT=${ROOT_DIR}/compiler/OpenArkCompiler

  BIN_HIR2MPL=${ROOT_OUTPUT}/bin/hir2mpl
  BIN_MAPLE=${ROOT_OUTPUT}/bin/maple
  BIN_CLANG=${ROOT_OUTPUT}/bin/clang
  OPT_LEVEL="-O2"
  DEBUG="false"
  DEBUG_OPTION=
  CFLAGS=
}

prepare_options()
{
 if [ "${DEBUG}" == "true" ]; then
   DEBUG_OPTION="-g"
 fi
}

# $1 cfilePath
# $2 cfileName
generate_ast()
{
  set -x
  $BIN_CLANG ${CFLAGS} -I ${MAPLE_ROOT}/tools/gcc-linaro-7.5.0/aarch64-linux-gnu/libc/usr/include/ --target=aarch64-linux-gnu -emit-ast $1 -o "$2.ast"
  check_error
  set +x
}

# $1 cfileName
generate_mpl()
{
  set -x
  LD_LIBRARY_PATH=${ROOT_OUTPUT}/lib ${BIN_HIR2MPL} "$1.ast" -o "${1}.mpl"
  check_error
  set +x
}

# $1 cfileName
generate_s()
{
  set -x
  ${BIN_MAPLE} ${OPT_LEVEL} ${DEBUG_OPTION} --genVtableImpl --save-temps "${1}.mpl"
  check_error
  set +x
}

# $@ sFilePaths
link()
{
  set -x
  aarch64-linux-gnu-gcc ${OPT_LEVEL} -static -std=c89 ${LINK_OPTIONS} -o $OUT $@
  check_error
  set +x
}

help()
{
  echo
  echo "USAGE"
  echo "    ./compile.sh [options=...] files..."
  echo
  echo "EXAMPLE"
  echo "    ./compile.sh out=test.out ldflags=\"-lm -pthread\" test1.c test2.c"
  echo
  echo "OPTIONS"
  echo "    out:           binary output path, default is a.out"
  echo "    ldflags:       ldflags"
  echo "    optlevel:      -O0 -O1 -O2(default)"
  echo "    debug:         true(-g), false(default)"
  echo "    cflags:        cflags"
  echo "    help:          print help"
  echo
  exit -1
}

parse_cmdline()
{
 while [ -n "$1" ]
 do
   OPTIONS=`echo "$1" | sed 's/\(.*\)=\(.*\)/\1/'`
   PARAM=`echo "$1" | sed 's/.*=//'`
   case "$OPTIONS" in
   out) OUT=$PARAM;;
   ldflags) LINK_OPTIONS=$PARAM;;
   optlevel) OPT_LEVEL=$PARAM;;
   debug) DEBUG=$PARAM;;
   cflags) CFLAGS=$PARAM;;
   help) help;;
   *) if [ `echo "$1" | sed -n '/.*=/p'` ];then
        echo "Error!!! the parttern \"$OPTIONS=$PARAM\" can not be recognized!!!"
        help;
      fi
      break;;
   esac
   shift
 done
 files=$@
 if [ ! -n "$files" ];then
    help
 fi
}

main()
{
 init_parameter
 check_env
 parse_cmdline $@
 prepare_options
 s_files=`echo ${files}|sed 's\.c\.s\g'`
 for i in $files
 do
   fileName=${i//.c/}
   generate_ast $i $fileName
   generate_mpl $fileName
   generate_s $fileName
 done
 link $s_files
}

main $@ 2>&1 | tee log.txt

