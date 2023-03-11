#!/bin/bash

BSC_ROOT=$(pwd)
SUB_OAC_DIR=${BSC_ROOT}/compiler/OpenArkCompiler
#####################################################################
# build/envsetup.sh 中主要的环境变量
# 设置构建出来的编译器二进制路径在PATH路径
# export MAPLE_EXECUTE_BIN=${MAPLE_ROOT}/output/${MAPLE_BUILD_TYPE}/bin
# export TEST_BIN=${CASE_ROOT}/driver/script
# export PATH=$PATH:${MAPLE_EXECUTE_BIN}:${TEST_BIN}         
# 设置运行时依赖的库
# export LD_LIBRARY_PATH=${MAPLE_ROOT}/tools/gcc-linaro-7.5.0/aarch64-linux-gnu/libc/lib:${ENHANCED_CLANG_PATH}/lib:${LD_LIBRARY_PATH}
# 设置maple driver调用的Clang路径
# export ENHANCED_CLANG_PATH=${MAPLE_ROOT}/tools/clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-18.04-enhanced
#####################################################################
cd ${SUB_OAC_DIR}
source build/envsetup.sh arm release
cd ${BSC_ROOT}
#####################################################################
# x86_64平台运行程序依赖qemu-aarch64
# 设置 qemu-aarch在PATH路径
# 设置 qemu-aarch 运行时依赖的LD库
#####################################################################
export PATH=${PATH}:${MAPLE_ROOT}/tools/bin
export QEMU_LD_PREFIX=${MAPLE_ROOT}/tools/gcc-linaro-7.5.0/aarch64-linux-gnu/libc
