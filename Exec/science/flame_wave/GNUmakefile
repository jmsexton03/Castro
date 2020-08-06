PRECISION  = DOUBLE
PROFILE    = FALSE

DEBUG      = FALSE

DIM        = 2

COMP	   = gnu

USE_MPI    = TRUE

USE_GRAV   = TRUE
USE_REACT  = TRUE

USE_ROTATION  = TRUE
USE_DIFFUSION = TRUE

# define the location of the CASTRO top directory
CASTRO_HOME  := ../../..

#Nersc location, use haswell, gcc/7.3.0, PrgEnv-gnu
#ASCENT_HOME ?=/project/projectdirs/alpine/software/ascent/gnu/7.3.0/ascent-install/
#OLCF location, use cuda/10.1.168, gcc/6.4.0
ASCENT_HOME ?=/gpfs/alpine/world-shared/csc340/software/ascent/0.5.2-pre/summit/cuda/gnu/ascent-install
ASCENT_HOME ?= $(CASTRO_HOME)/ascent-install

USE_ASCENT_INSITU = FALSE

#include Make.ascent
ifeq ($(USE_ASCENT_INSITU),TRUE)
  ASCENT_HOME ?= NOT_SET
  ifneq ($(ASCENT_HOME),NOT_SET)
    include $(ASCENT_HOME)/share/ascent/ascent_config.mk
  endif
  USE_CONDUIT = TRUE
  USE_ASCENT = TRUE
endif

#Add these libraries for cuda ascent library (olcf)
#Theoretically should just use $(ASCENT_MPI_LIB_FLAGS)
#ifeq ($(USE_CUDA),TRUE)
ifeq ($(USE_ASCENT_INSITU),TRUE)
#ifneq ($(USE_CUDA),TRUE)
     XTRAOBJS += $(ASCENT_DEVICE_OBJECT_MPI)
#     LIBRARIES += $(ASCENT_MPI_LIB_FLAGS)
      LIBRARIES += -L $(ASCENT_DIR)/lib \
                       -lascent_mpi \
                       -lascent_flow \
                       -lascent_lodepng \
                       -lrover_mpi $(DRAY_LINK_RPATH) $(DRAY_LIB_FLAGS) $(ASCENT_VTKH_MPI_LIB_FLAGS) $(ASCENT_VTKM_LIB_FLAGS) $(ASCENT_CONDUIT_MPI_LIB_FLAGS) $(ASCENT_MFEM_LIB_FLAGS) $(ASCENT_PYTHON_LIBS) $(ASCENT_OPENMP_LINK_FLAGS) -L $(ASCENT_CUDA_LIB_FLAGS)
#endif
endif
#endif

GPU_COMPATIBLE_PROBLEM = TRUE

USE_PROB_PARAMS = TRUE

# This sets the EOS directory in $(MICROPHYSICS_HOME)/eos
EOS_DIR     := helmholtz

# This sets the network directory in $(MICROPHYSICS_HOME)/networks
NETWORK_DIR := aprox13

INTEGRATOR_DIR := VODE

CONDUCTIVITY_DIR := stellar

Bpack   := ./Make.package
Blocs   := .

include $(CASTRO_HOME)/Exec/Make.Castro
