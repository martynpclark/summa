#!/bin/bash
# run as "./build.mac.bash clean" to remove this build directory and the executables it produced
if [[ "${1:-}" == "clean" ]]; then
  if [[ -d "../cmake_build" ]]; then
    cmake --build "../cmake_build" --target clean || true
    rm -rf "../cmake_build"
    echo "removed ../cmake_build and its executables"
  else
    echo "nothing to clean: ../cmake_build does not exist"
  fi
  exit 0
fi

# build SUMMA on a Mac using Bash, from cmake directory run this as ./build.mac.bash
# Environment variables may be set within this script (see examples below) or in the terminal environment before executing this script
# Actual settings may vary

# Mac Example using MacPorts:
export FC=/opt/local/bin/gfortran                             # Fortran compiler family
#export FLAGS_OPT="-flto=1"                                   # -flto=1 is slow to compile, but might want to use
export LIBRARY_LINKS='-llapack'                               # list of library links
export SUNDIALS_DIR=../../../sundials/instdir/

cmake -B ../cmake_build -S ../. \
    -DUSE_SUNDIALS=ON \
    -DUSE_MPI=OFF \
    -DUSE_NEXTGEN=OFF \
    -DUSE_OPENWQ=OFF \
    -DUSE_MIZUROUTE=OFF \
    -DSPECIFY_LAPACK_LINKS=ON \
    -DCMAKE_BUILD_TYPE=Release

cmake --build ../cmake_build --target all -j
