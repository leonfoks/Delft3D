# FindnetCDF
#
# Locates netCDF and defines the imported target netCDF::netcdf.
#
# A CMake-installed netCDF (Conan, conda, upstream's own build system) ships
# a package config, and that is used as-is when present. An autotools install
# ships no config at all, only nc-config; this module reads it so a site that
# provides netCDF as a plain library tree needs no hand-written config on its
# CMAKE_PREFIX_PATH. nc-config exits 0 even for options it does not recognise,
# so every answer is checked for the shape it must have, not for the status.

find_package(netCDF CONFIG QUIET)
if(netCDF_FOUND)
    return()
endif()

find_program(NC_CONFIG_EXECUTABLE nc-config)

set(nc_hint_include "")
set(nc_hint_libdir "")
set(netCDF_VERSION "")

if(NC_CONFIG_EXECUTABLE)
    execute_process(COMMAND "${NC_CONFIG_EXECUTABLE}" --includedir
        OUTPUT_VARIABLE nc_hint_include OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
    execute_process(COMMAND "${NC_CONFIG_EXECUTABLE}" --libdir
        OUTPUT_VARIABLE nc_hint_libdir OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
    execute_process(COMMAND "${NC_CONFIG_EXECUTABLE}" --version
        OUTPUT_VARIABLE nc_version OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
    if(NOT IS_DIRECTORY "${nc_hint_include}")
        set(nc_hint_include "")
    endif()
    if(NOT IS_DIRECTORY "${nc_hint_libdir}")
        set(nc_hint_libdir "")
    endif()
    if(nc_version MATCHES "netCDF ([0-9.]+)")
        set(netCDF_VERSION "${CMAKE_MATCH_1}")
    endif()
endif()

find_path(netCDF_INCLUDE_DIR
    NAMES netcdf.h
    HINTS ${nc_hint_include}
)

find_library(netCDF_LIBRARY
    NAMES netcdf
    HINTS ${nc_hint_libdir}
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(netCDF
    REQUIRED_VARS netCDF_LIBRARY netCDF_INCLUDE_DIR
    VERSION_VAR netCDF_VERSION
)

if(netCDF_FOUND AND NOT TARGET netCDF::netcdf)
    add_library(netCDF::netcdf UNKNOWN IMPORTED)
    set_target_properties(netCDF::netcdf PROPERTIES
        IMPORTED_LOCATION "${netCDF_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${netCDF_INCLUDE_DIR}"
    )
endif()

mark_as_advanced(NC_CONFIG_EXECUTABLE)
