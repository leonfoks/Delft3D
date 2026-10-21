# FindPETSc
#
# Locates PETSc and defines the imported target PETSc::PETSc.
#
# A PETSc installation lays its Fortran include tree out under
# <prefix>/include/petsc/finclude and its module files under <prefix>/include.
# That is the layout the `#include <petsc/finclude/petscksp.h>` and `use petsc`
# in this code base expect, so both have to come from the same prefix.
#
# Discovery order: pkg-config (which a conda package provides), then PETSC_DIR.

find_package(PkgConfig QUIET)
if(PkgConfig_FOUND)
    pkg_check_modules(PC_PETSc QUIET PETSc)
endif()

find_path(PETSc_INCLUDE_DIR
    NAMES petsc/finclude/petscksp.h
    HINTS ${PC_PETSc_INCLUDE_DIRS} ${PETSC_DIR}/include
)

find_library(PETSc_LIBRARY
    NAMES petsc
    HINTS ${PC_PETSc_LIBRARY_DIRS} ${PETSC_DIR}/lib
)

set(PETSc_VERSION ${PC_PETSc_VERSION})

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(PETSc
    REQUIRED_VARS PETSc_LIBRARY PETSc_INCLUDE_DIR
    VERSION_VAR PETSc_VERSION
)

if(PETSc_FOUND AND NOT TARGET PETSc::PETSc)
    add_library(PETSc::PETSc UNKNOWN IMPORTED)
    set_target_properties(PETSc::PETSc PROPERTIES
        IMPORTED_LOCATION "${PETSc_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${PETSc_INCLUDE_DIR}"
    )
endif()

mark_as_advanced(PETSc_INCLUDE_DIR PETSc_LIBRARY)
