#!/bin/bash
set -x
set -e

ROOT_DIR=$(cd "$(dirname $0)"; pwd)
SUB_LLVM_DIR=${ROOT_DIR}/fe/llvm-project
SUB_LLVM_BUILD_DIR=${SUB_LLVM_DIR}/build
SUB_LLVM_INSTALL_DIR=${SUB_LLVM_DIR}/install
SUB_OAC_DIR=${ROOT_DIR}/compiler/OpenArkCompiler
TARGET=${SUB_OAC_DIR}/tools/clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-18.04-enhanced
THREADS=$(cat /proc/cpuinfo | grep -c processor) # FIXME: this does not work for macos

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

function copy_files() {
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
  make | tee ${ROOT_DIR}/build_oac.log
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
  sudo yum -y install python3 cmake git g++ dkms dpkg rsync
  sudo ln -sf /usr/lib/dkms/lsb_release /usr/bin/lsb_release
  sudo ln -sf /lib64/libtinfo.so.6 /lib64/libtinfo.so.5
}

function get_branch_code() {
  rm -rf ${SUB_LLVM_DIR}
  cd ${ROOT_DIR}/fe
  if [ "${LLVM_COMMITID}" == "" ]; then
    git clone https://gitee.com/${LLVM_OWNER}/llvm-project.git
    cd ${SUB_LLVM_DIR}
    git remote add upstream https://gitee.com/bisheng_c_language_dep/llvm-project.git
    git fetch upstream
    git checkout -b ${LLVM_BRANCH} origin/${LLVM_BRANCH}
    git rebase upstream/bishengc/12.0.1
  else
    git clone https://gitee.com/bisheng_c_language_dep/llvm-project.git
    cd ${SUB_LLVM_DIR}
    git checkout -b bishenghc/12.0.1 origin/bishengc/12.0.1
  fi

  rm -rf ${SUB_OAC_DIR}
  cd ${ROOT_DIR}/compiler
  if [ "${OAC_COMMITID}" == "" ]; then
    git clone https://gitee.com/${OAC_OWNER}/OpenArkCompiler.git
    cd ${SUB_OAC_DIR}
    git remote add upstream https://gitee.com/bisheng_c_language_dep/OpenArkCompiler.git
    git fetch upstream
    git checkout -b ${OAC_BRANCH} origin/${OAC_BRANCH}
    git rebase upstream/bishengc
  else
    git clone https://gitee.com/bisheng_c_language_dep/OpenArkCompiler.git
    cd ${SUB_OAC_DIR}
    git checkout -b bishengc origin/bishengc
  fi
}

function get_owner_info() {
  cd ${ROOT_DIR}
  tmp=`sed -n '/^owner:/p' llvm.commitid`
  LLVM_OWNER=${tmp#*:}
  tmp=`sed -n '/^branch:/p' llvm.commitid`
  LLVM_BRANCH=${tmp#*:}
  tmp=`sed -n '/^commitid:/p' llvm.commitid`
  LLVM_COMMITID=${tmp#*:}
  tmp=`sed -n '/^owner:/p' oac.commitid`
  OAC_OWNER=${tmp#*:}
  tmp=`sed -n '/^branch:/p' oac.commitid`
  OAC_BRANCH=${tmp#*:}
  tmp=`sed -n '/^commitid:/p' oac.commitid`
  OAC_COMMITID=${tmp#*:}
}

function start_ci_test() {
  cd ${SUB_OAC_DIR}
  ll ${SUB_OAC_DIR}/output/aarch64-clang-release/bin/
  source build/envsetup.sh arm release
  mm c_test
}

function main() {
  echo "Start Building"
  git config --global user.email "sunzibo@huawei.com"
  git config --global user.name "sunzibo"
  install_tools
  get_owner_info
  get_branch_code
  build_llvm
  copy_files
  build_oac
  start_ci_test
  copy_output
  echo "Built Successfully"
}

main "$@"
