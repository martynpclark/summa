#========================================================================
# Makefile to compile setup tools for Summa
#========================================================================
#  Original Makefile from Martyn's FUSE Model
#  Modified:
#  Andy Newman, Nov 2015 
#
#
#========================================================================
# PART 0: Define directory paths
#========================================================================

# Define core directory below which everything resides
F_MASTER = /home/anewman/summa_setup_tools

# Core directory that contains source code
F_KORE_DIR = $(F_MASTER)/fortran

# Location of the compiled modules
MOD_PATH = $(F_MASTER)/fortran

# Define the directory for the executables
EXE_PATH = $(F_MASTER)/bin
#
#========================================================================
# PART 1: Assemble all of the various sub-routines
#========================================================================

#
# Utilities
SETUP_UTILS= \
		nrtype.f90 \
		nr_utility.f90 \
		multiconst.f90 \
		time_utils.f90
UTILS = $(patsubst %, $(F_KORE_DIR)/%, $(SETUP_UTILS))


# ... and stitch it all together...
ALL = $(UTILS)


#========================================================================
# PART 2: Define the libraries, driver programs, and executables
#========================================================================

# Define the Fortran Compiler
FC  = ifort

# Define the NetCDF libraries and path to include files

ifeq "$(FC)" "ifort"
# HDF_PATH  = /usr/local/hdf5-1.8.7
 NCDF_PATH = /usr/local/netcdf-4.3.0+ifort-12.1/
 LOCL_PATH = /usr/local
 LIBNETCDF = -L$(NCDF_PATH)/lib -lnetcdff -lnetcdf -L$(LOCL_PATH)/lib
 INCNETCDF = -I$(NCDF_PATH)/include
endif


# Define the main routine
SETUP_CODE= \
	setup_summa_forcings.f90
SETUP = $(patsubst %, $(F_KORE_DIR)/%, $(SETUP_CODE))

# Define the executable
SETUP__EX = setup_summa.exe


#========================================================================
# PART 3: Compile the puppy
#========================================================================

# Define flags
ifeq "$(FC)" "ifort"
 FLAGS = -debug -warn all -check all -FR -O0 -auto -WB -traceback -g -fltconsistency -fpe0
endif


#.SUFFIXES: .f .o .f90

# Compile
all: compile_tools link clean install

check:
	echo test
	echo $(FC)

# compile code
compile_tools:
	$(FC) $(FLAGS) -c $(ALL) $(SETUP) \
	$(INCNETCDF)

# link routines
link:
#	$(FC) -fPIC -Bstatic_pgi -rpath,/usr/local/netcdf4-pgi/lib *.o -I./ $(LIBNETCDF) -o $(DRIVER__EX)
#	$(FC) -fPIC -rpath,/usr/local/netcdf4-pgi/lib -I./ $(LIBNETCDF) -o $(DRIVER__EX) *.o 
	$(FC) -I./ $(LIBNETCDF) -o $(SETUP__EX) *.o 

# Remove object files
clean:
						rm -f *.o
						rm -f *.mod
#
# Copy the executable to the bin directory
install:
		mv $(SETUP__EX) $(EXE_PATH)



