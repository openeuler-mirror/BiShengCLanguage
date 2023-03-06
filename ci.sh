#!/bin/bash
set -e

ROOT_DIR=$(cd "$(dirname $0)"; pwd)
SUB_LLVM_DIR=${ROOT_DIR}/fe/llvm-project
SUB_LLVM_BUILD_DIR=${SUB_LLVM_DIR}/build
SUB_LLVM_INSTALL_DIR=${SUB_LLVM_DIR}/install
SUB_OAC_DIR=${ROOT_DIR}/compiler/OpenArkCompiler
TARGET=${SUB_OAC_DIR}/tools/clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-18.04-enhanced
THREADS=$(cat /proc/cpuinfo | grep -c processor) # FIXME: this does not work for macos

access_token=$1
LLVM_PRID=""
OAC_PRID=""

LLVM_OWNER=""
LLVM_BRANCH=""
LLVM_COMMITID=""
OAC_OWNER=""
OAC_BRANCH=""
OAC_COMMITID=""

function build_llvm() {
  cd ${SUB_LLVM_DIR}
  mkdir -p build
  mkdir -p install
  cd build
  cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=../install/ -DLLVM_TARGETS_TO_BUILD="X86;AArch64" -DLLVM_ENABLE_PROJECTS="clang;lld" -DLLVM_USE_LINKER=gold -DLLVM_BUILD_DOCS=Off -DLLVM_ENABLE_BINDINGS=Off -G "Unix Makefiles" ../llvm
  make -j${THREADS} | tee ${ROOT_DIR}/build_llvm.log
  make install
}

function install_llvm() {
  mkdir -p ${TARGET}/bin
  cp -r ${SUB_LLVM_DIR}/install/bin/* ${TARGET}/bin/
  cp -r ${SUB_LLVM_DIR}/build/bin/FileCheck ${TARGET}/bin/
  cp -r ${SUB_LLVM_DIR}/install/include ${TARGET}
  cp -r ${SUB_LLVM_DIR}/install/lib ${TARGET}
  cp -r ${SUB_LLVM_DIR}/install/libexec ${TARGET}
  cp -r ${SUB_LLVM_DIR}/install/share ${TARGET}
}

function build_oac() {
  cd ${SUB_OAC_DIR}
  source build/envsetup.sh arm release
  make setup
  make 2>&1 | tee ${ROOT_DIR}/build_oac.log
}

function copy_output() {
  mkdir -p ${ROOT_DIR}/output/
  cp -r ${SUB_LLVM_INSTALL_DIR}/* ${ROOT_DIR}/output/
  cp -r ${SUB_OAC_DIR}/output/aarch64-clang-release/bin/* ${ROOT_DIR}/output/bin
}

function update_submodule() {
  cd ${ROOT_DIR}
  git submodule update --init
}

function install_tools() {
  sudo yum clean all
  sudo yum makecache
  sudo yum -y install python3 cmake git g++ dkms dpkg rsync glibc-devel glibc --nobest
  sudo ln -sf /usr/lib/dkms/lsb_release /usr/bin/lsb_release
  sudo cp -rf ${ROOT_DIR}/script/Centos-Base.repo /etc/yum.repos.d/
  sudo yum makecache
  sudo yum -y install glibc-devel.i686 ncurses-compat-libs
  sudo ln -sf /lib64/libtinfo.so.5.9 /lib64/libtinfo.so.5
  sudo pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
  sudo pip install paramiko
}

function get_branch_code() {
  rm -rf ${SUB_LLVM_DIR}
  cd ${ROOT_DIR}/fe
  if [ "${LLVM_PRID}" != "" ]; then
    git clone -b ${LLVM_BRANCH} https://gitee.com/${LLVM_OWNER}/llvm-project.git
    cd ${SUB_LLVM_DIR}
    git remote add upstream https://gitee.com/bisheng_c_language_dep/llvm-project.git
    git fetch upstream
    git rebase upstream/bishengc/12.0.1
  else
    git clone https://gitee.com/bisheng_c_language_dep/llvm-project.git
    cd ${SUB_LLVM_DIR}
    git checkout -b bishenghc/12.0.1 origin/bishengc/12.0.1
  fi

  rm -rf ${SUB_OAC_DIR}
  cd ${ROOT_DIR}/compiler
  if [ "${OAC_PRID}" != "" ]; then
    git clone -b ${OAC_BRANCH} https://gitee.com/${OAC_OWNER}/OpenArkCompiler.git
    cd ${SUB_OAC_DIR}
    git remote add upstream https://gitee.com/bisheng_c_language_dep/OpenArkCompiler.git
    git fetch upstream
    git rebase upstream/bishengc
  else
    git clone https://gitee.com/bisheng_c_language_dep/OpenArkCompiler.git
    cd ${SUB_OAC_DIR}
    git checkout -b bishengc origin/bishengc
  fi
}

function get_owner_info() {
  cd ${ROOT_DIR}
  git log > commit.log
  tmp=`sed -n '/_llvm_/p' commit.log`
  tmp=${tmp#*\_llvm\_}
  llvm=${tmp%%\_*}
  tmp=`sed -n '/_oac_/p' commit.log`
  tmp=${tmp#*\_oac\_}
  oac=${tmp%% *}
  if [ "${llvm}" != "" ]; then
    tmp=`sed -n '/^llvm_PRID:/p' commit/llvm.prid_${llvm}`
    LLVM_PRID=${tmp#*:}
    tmp=`sed -n '/^llvm_owner:/p' commit/llvm.prid_${llvm}`
    LLVM_OWNER=${tmp#*:}
    tmp=`sed -n '/^llvm_branch:/p' commit/llvm.prid_${llvm}`
    LLVM_BRANCH=${tmp#*:}
    echo "LLVM_PRID:$LLVM_PRID  LLVM_OWNER:$LLVM_OWNER  LLVM_BRANCH:$LLVM_BRANCH"
  fi
  if [ "${oac}" != "" ]; then
    tmp=`sed -n '/^oac_PRID:/p' commit/oac.prid_${oac}`
    OAC_PRID=${tmp#*:}
    tmp=`sed -n '/^oac_owner:/p' commit/oac.prid_${oac}`
    OAC_OWNER=${tmp#*:}
    tmp=`sed -n '/^oac_branch:/p' commit/oac.prid_${oac}`
    OAC_BRANCH=${tmp#*:}
    echo "OAC_PRID:$OAC_PRID  OAC_OWNER:$OAC_OWNER  OAC_BRANCH:$OAC_BRANCH"
  fi
}

function start_ci_test() {
  cd ${SUB_OAC_DIR}
  ls ${SUB_OAC_DIR}/output/aarch64-clang-release/bin/
  source build/envsetup.sh arm release
  mm c_test
  mm bsc_test
}

function post_label() {
  tmp="python3 script/postlabel.py --token ${access_token} --label $1"
  if [ "${LLVM_PRID}" != "" ]; then
    tmp="${tmp} --llvm ${LLVM_PRID}"
  else
    tmp="${tmp} --llvm -1"
  fi
  if [ "${OAC_PRID}" != "" ]; then
    tmp="${tmp} --oac ${OAC_PRID}"
  else
    tmp="${tmp} --oac -1"
  fi
  ${tmp}
  if [[ $? -ne 0 ]];then
     cat make.log
     exit 1
  fi
}

function main() {
  echo "Start Building"
  install_tools
  get_owner_info
  cd ${ROOT_DIR}
  post_label "ci_processing"
  get_branch_code
  build_llvm
  install_llvm
  build_oac
  start_ci_test
  copy_output
  cd ${ROOT_DIR}
  post_label "ci_successful"
  echo "Built Successfully"
}

main "$@"
