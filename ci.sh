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
OAC_OWNER=""
OAC_BRANCH=""

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
  make -j${THREADS} | tee ${ROOT_DIR}/build_oac.log
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
  yum -y install python3 cmake git
}

function get_branch_code() {
  rm -rf ${SUB_LLVM_DIR}
  cd ${SUB_LLVM_DIR}/..
  if [ ${LLVM_OWNER} != "" ]; then
    git clone https://gitee.com/${LLVM_OWNER}/llvm-project.git
    cd ${SUB_LLVM_DIR}
    git remote add upstream https://gitee.com/bisheng_c_language_dep/OpenArkCompiler
    git checkout -b ${LLVM_BRANCH} origin/${LLVM_BRANCH}
    git merge upstream/bishenghc/12.0.1
  elif
    git clone https://gitee.com/bisheng_c_language_dep/OpenArkCompiler.git
    cd ${SUB_LLVM_DIR}
    git checkout -b bishenghc/12.0.1 origin/bishenghc/12.0.1
  fi

  rm -rf ${SUB_OAC_DIR}
  cd ${SUB_OAC_DIR}/..
  if [ ${OAC_OWNER} != "" ]; then
    git clone https://gitee.com/${OAC_OWNER}/OpenArkCompiler.git
    cd ${SUB_OAC_DIR}
    git remote add upstream https://gitee.com/bisheng_c_language_dep/llvm-project
    git checkout -b ${OAC_BRANCH} origin/${OAC_BRANCH}
    git merge upstream/bishengc
  elif
    git clone https://gitee.com/bisheng_c_language_dep/llvm-project.git
    cd ${SUB_OAC_DIR}
    git checkout -b bishengc
  fi
}

function get_owner_info() {
  cd ${ROOT_DIR}
  tmp=`sed -n '/^owner:/p' llvm.commitid`
  LLVM_OWNER=${tmp#*:}
  tmp=`sed -n '/^branch:/p' llvm.commitid`
  LLVM_BRANCH=${tmp#*:}
  tmp=`sed -n '/^owner:/p' oac.commitid`
  OAC_OWNER=${tmp#*:}
  tmp=`sed -n '/^branch:/p' oac.commitid`
  OAC_BRANCH=${tmp#*:}
}

function main() {
  echo "Start Building"
  echo $(pwd)
  install_tools
  get_owner_info
  get_branch_code
  build_llvm
  copy_files
  build_oac
  copy_output
  echo "Built Successfully"
}

main "$@"