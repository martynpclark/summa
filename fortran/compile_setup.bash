#!/bin/bash -u

ifort -debug -warn all -check all -FR -O0 -auto -WB -traceback -g -fltconsistency -fpe0 -c setup_summa_forcings.f90 -I /usr/local/netcdf-4.3.0+ifort-12.1/include/

ifort setup_summa_forcings.o -L /usr/local/netcdf-4.3.0+ifort-12.1/lib -lnetcdff -o setup.exe
