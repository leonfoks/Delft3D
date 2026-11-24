# FindnetCDF-Fortran
#
# Locates netCDF-Fortran and defines the imported target netCDF::netcdff.
# Package config first, like FindnetCDF; only autotools installs reach the
# discovery below.
#
# nf-config has no --libdir (it prints usage and exits 0 when asked), so the
# library directory comes from its --prefix, with the directory of the C
# library found by FindnetCDF as the fallback: the two install together.

find_package(netCDF-Fortran CONFIG QUIET)
if(netCDF-Fortran_FOUND)
    return()
endif()

include(CMakeFindDependencyMacro)
find_dependency(netCDF)

find_program(NF_CONFIG_EXECUTABLE nf-config)

set(nf_hint_include "")
set(nf_hint_libdir "")
set(netCDF-Fortran_VERSION "")

if(NF_CONFIG_EXECUTABLE)
    execute_process(COMMAND "${NF_CONFIG_EXECUTABLE}" --includedir
        OUTPUT_VARIABLE nf_hint_include OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
    execute_process(COMMAND "${NF_CONFIG_EXECUTABLE}" --prefix
        OUTPUT_VARIABLE nf_prefix OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
    execute_process(COMMAND "${NF_CONFIG_EXECUTABLE}" --version
        OUTPUT_VARIABLE nf_version OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
    if(NOT IS_DIRECTORY "${nf_hint_include}")
        set(nf_hint_include "")
    endif()
    if(nf_prefix AND IS_DIRECTORY "${nf_prefix}/lib")
        set(nf_hint_libdir "${nf_prefix}/lib")
    endif()
    if(nf_version MATCHES "netCDF-Fortran ([0-9.]+)")
        set(netCDF-Fortran_VERSION "${CMAKE_MATCH_1}")
    endif()
endif()

# The C library's include directory often holds the Fortran module file too.
if(NOT nf_hint_include AND netCDF_INCLUDE_DIR)
    set(nf_hint_include "${netCDF_INCLUDE_DIR}")
endif()

find_path(netCDF-Fortran_INCLUDE_DIR
    NAMES netcdf.mod netcdf.inc
    HINTS ${nf_hint_include}
)

# The C library's own directory is the last-resort hint; they share a prefix.
if(NOT nf_hint_libdir AND netCDF_LIBRARY)
    get_filename_component(nf_hint_libdir "${netCDF_LIBRARY}" DIRECTORY)
endif()

find_library(netCDF-Fortran_LIBRARY
    NAMES netcdff
    HINTS ${nf_hint_libdir}
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(netCDF-Fortran
    REQUIRED_VARS netCDF-Fortran_LIBRARY netCDF-Fortran_INCLUDE_DIR
    VERSION_VAR netCDF-Fortran_VERSION
)

if(netCDF-Fortran_FOUND AND NOT TARGET netCDF::netcdff)
    add_library(netCDF::netcdff UNKNOWN IMPORTED)
    set_target_properties(netCDF::netcdff PROPERTIES
        IMPORTED_LOCATION "${netCDF-Fortran_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${netCDF-Fortran_INCLUDE_DIR}"
        # libnetcdff's objects reference libnetcdf, so the C library has to
        # follow it on the link line.
        INTERFACE_LINK_LIBRARIES netCDF::netcdf
    )
endif()

mark_as_advanced(NF_CONFIG_EXECUTABLE)
