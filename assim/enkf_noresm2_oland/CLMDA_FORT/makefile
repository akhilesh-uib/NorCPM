# ---------------------------------------------------------------------------
# Serial (no MPI) build of clm5_da on Betzy
#
#   module purge
#   module load netCDF-Fortran/4.5.2-iompi-2020a
#   make clean && make          (make DEBUG=1 for -g -traceback -check bounds)
#   make check                  (runs the program with an EMPTY environment)
#
# clm5_da.f90 must be the serial source (sm_da_s2s.f90 renamed)
# Output (two levels above ./TMP):
#   clm5_da.exe   the real binary
#   clm5_da       wrapper script that sets LD_LIBRARY_PATH, then runs clm5_da.exe
# ---------------------------------------------------------------------------
THIS_MAKEFILE := $(firstword $(MAKEFILE_LIST))

MPI   = NO
VPATH = .:TMP:

include make.inc.betzy

SHELL = /bin/bash

# ---- overrides for the serial program (must stay AFTER the include) ----
# no -r8 (code uses explicit kinds), no -xavx2 (fails the Intel CPU check on AMD nodes)
SIZEO = -heap-arrays
OPTO  = $(OPTO_NOAVX2)

ifeq ($(DEBUG),1)
  OPTO += -g -traceback -check bounds
endif

# ---- NetCDF from the loaded module (fail early if it is not loaded) ----
ifneq ($(MAKECMDGOALS),clean)
  ifeq ($(shell which nf-config 2>/dev/null),)
    $(error nf-config not found: run "module load netCDF-Fortran/4.5.2-iompi-2020a" first)
  endif
endif

NF_FLIBS := $(shell nf-config --flibs)
NC_LIBS  := $(shell nc-config --libs)

INC_NETCDF = $(shell nf-config --fflags)

# ---- every library directory the program may need at run time ----
empty :=
space := $(empty) $(empty)
# Intel runtime (libirng, libimf, libsvml ...) lives in intel64_lin next to the ifort install
INTEL_LIN := $(wildcard $(dir $(shell which ifort))../../compiler/lib/intel64_lin)
LIBDIRS := $(patsubst -L%,%,$(filter -L%,$(NF_FLIBS) $(NC_LIBS))) \
           $(shell nf-config --prefix)/lib $(shell nc-config --prefix)/lib \
           $(if $(EBROOTHDF5),$(EBROOTHDF5)/lib) $(INTEL_LIN) \
           $(subst :, ,$(LD_LIBRARY_PATH)) $(subst :, ,$(LIBRARY_PATH))
LIBDIRS := $(sort $(strip $(LIBDIRS)))
LD_PATH_BAKED := $(subst $(space),:,$(LIBDIRS))
RPATHS  := $(foreach d,$(LIBDIRS),-Wl,-rpath,$(d))

# old-style RPATH as an extra safety net (the wrapper below is what makes it robust)
# no MKL / LAPACK / FFTW
LIBS = $(NF_FLIBS) -Wl,--disable-new-dtags $(RPATHS)

PROGS = clm5_da

# where the executable is put (relative to ./TMP)
BINDIR = ../..

.PHONY: all clean check

all: $(PROGS)

SM_SRC_F90 = \
clm5_da.f90

SM_OBJ = $(SM_SRC_F90:.f90=.o)

clm5_da: $(SM_OBJ)
	@echo "->clm5_da"
	@echo $(LD) $(LINKFLAGS) -o $(BINDIR)/clm5_da.exe $(SM_OBJ) $(LIBS)
	@cd ./TMP ; $(LD) $(LINKFLAGS) -o $(BINDIR)/clm5_da.exe $(SM_OBJ) $(LIBS)
	@{ echo '#!/bin/bash'; \
	   echo 'export LD_LIBRARY_PATH="$(LD_PATH_BAKED)$${LD_LIBRARY_PATH:+:$$LD_LIBRARY_PATH}"'; \
	   echo 'exec "$$(dirname "$$(readlink -f "$$0")")/clm5_da.exe" "$$@"'; \
	 } > ./TMP/$(BINDIR)/clm5_da
	@chmod +x ./TMP/$(BINDIR)/clm5_da
	@cd ./TMP ; if env -i LD_LIBRARY_PATH="$(LD_PATH_BAKED)" ldd $(BINDIR)/clm5_da.exe | grep -q "not found"; then \
	    echo "ERROR: unresolved shared libraries even with the baked LD_LIBRARY_PATH:"; \
	    env -i LD_LIBRARY_PATH="$(LD_PATH_BAKED)" ldd $(BINDIR)/clm5_da.exe | grep "not found"; exit 1; fi
	@echo "build OK: clm5_da (wrapper) + clm5_da.exe, all shared libraries resolve"

$(SM_OBJ): $(THIS_MAKEFILE)

# Run the WRAPPER with an EMPTY environment; exit code 127 = a library was not found.
# (run without arguments it prints its usage and stops with code 1, which is fine)
check:
	@cd ./TMP ; env -i $(BINDIR)/clm5_da ; rc=$$? ; \
	  if [ $$rc -eq 127 ]; then echo "FAIL: cannot start without the module environment"; exit 1; \
	  else echo "OK: starts with an empty environment (exit code $$rc)"; fi

clean:
	@rm -f TMP/*.*  $(BINDIR)/clm5_da $(BINDIR)/clm5_da.exe

# The source is plain free-form Fortran (no #ifdefs) and uses '//' for string concatenation,
# so it is NOT passed through $(CPP) (cpp would treat '//' as a comment).
%.o: %.f90
	@echo "  $*".f90
	@mkdir -p TMP
	@cd ./TMP ; $(CF90) -c $(FFLAGS) $(F90FLG) -o $*.o ../$<
