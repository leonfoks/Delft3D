cmake_minimum_required(VERSION 3.30)

project(CMake)
enable_testing()

# enable project files grouping by folders
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# Globally disable min and max macro's defined in the windows.h header. These often lead to name clashes with
# std::min and std::max and only still exist for legacy reasons. Disable globally to prevent accidental use.
if(WIN32)
    add_compile_definitions(NOMINMAX)

    if(NOT DEFINED ENV{ONEAPI_ROOT} OR "$ENV{ONEAPI_ROOT}" STREQUAL "")
        message(FATAL_ERROR
            "ONEAPI_ROOT is not set. Configure from an Intel OneApi command prompt or manually set the environment."
        )
    endif()

    if(NOT IS_DIRECTORY "$ENV{ONEAPI_ROOT}")
        message(FATAL_ERROR
            "ONEAPI_ROOT does not point to an existing directory: '$ENV{ONEAPI_ROOT}'."
        )
    endif()
endif()

message(STATUS "Configuring")
if(UNIX)
    include(linux_scripts.cmake)
    add_definitions(-DCOMMIT_VERSION=${COMMIT_VERSION})
endif(UNIX)

include(functions.cmake)

# Set checkout root
set(checkout_src_root ${CMAKE_CURRENT_SOURCE_DIR}/..) # This points to the location of OSS/src
set(checkout_root ${checkout_src_root}/..)

# Find modules for dependencies that ship no package config of their own.
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/modules")

# Third-party dependencies come from the Conan CMakeDeps output by default. Turning
# this off discovers them from CMAKE_PREFIX_PATH instead, for sites that provide the
# libraries themselves: a HPC module tree, or a conda environment.
option(DELFT3D_USE_CONAN_DEPS "Discover third-party dependencies from the Conan CMakeDeps output" ON)

if(DELFT3D_USE_CONAN_DEPS)
    # Conan: check if conan.lock or conanfile.py have changed since last conan install.
    # If so, configuration is stopped and conan must be rerun. This doesn't catch all conan changes
    # (e.g. profile changes aren't taken into account), but it is a good basic safety net.
    set(conan_lock_source "${checkout_root}/conan.lock")
    set(conan_file_source "${checkout_root}/conanfile.py")
    set(conan_stamp "${CMAKE_BINARY_DIR}/conan/generators/conan.stamp")
    if("${conan_lock_source}" IS_NEWER_THAN "${conan_stamp}" OR
        "${conan_file_source}" IS_NEWER_THAN "${conan_stamp}")
        message(FATAL_ERROR
            "The conan configuration has been updated since the last conan install. "
            "Please do a clean build using build.py to ensure dependencies are up to date."
        )
    endif()

    # Conan: add the CMakeDeps generator output to the search path and find all explicit dependencies.
    # In the CMakeDeps generator, transitively depending on a dll counts as an explicit dependency,
    # because we need to install the dll and deliver it to a user.
    list(PREPEND CMAKE_PREFIX_PATH "${CMAKE_BINARY_DIR}/conan/generators")
    set(delft3d_dep_mode CONFIG)
else()
    # Let CMake try its own Find modules first and fall back to package config files,
    # which is the layout both a conda environment and a module tree have.
    set(delft3d_dep_mode "")
endif()

find_package(ZLIB ${delft3d_dep_mode} REQUIRED)
find_package(HDF5 ${delft3d_dep_mode} REQUIRED)
find_package(netCDF ${delft3d_dep_mode} REQUIRED)
find_package(netCDF-Fortran ${delft3d_dep_mode} REQUIRED)
find_package(expat ${delft3d_dep_mode} REQUIRED)
# The Conan package config names the target expat::expat; CMake's own FindEXPAT
# names it EXPAT::EXPAT. The tree links expat::expat either way.
if(NOT TARGET expat::expat AND TARGET EXPAT::EXPAT)
    add_library(expat::expat INTERFACE IMPORTED)
    set_target_properties(expat::expat PROPERTIES INTERFACE_LINK_LIBRARIES EXPAT::EXPAT)
endif()
find_package(TIFF ${delft3d_dep_mode} REQUIRED)
find_package(PROJ ${delft3d_dep_mode} REQUIRED)
find_package(GDAL ${delft3d_dep_mode} REQUIRED)
find_package(PETSc ${delft3d_dep_mode} REQUIRED)

# triangle ships no package config, so without Conan it is built from the copy
# vendored in this repository.
if(DELFT3D_USE_CONAN_DEPS)
    find_package(triangle CONFIG REQUIRED)
else()
    add_subdirectory(${checkout_src_root}/third_party_open/triangle triangle)
    add_library(triangle::triangle ALIAS triangle)
endif()

# The components are what the tree links, so they are what has to be found. CMake's
# own FindBoost defines a target only for a component that was asked for, and CMake 4
# no longer searches for it at all (CMP0167), so this has to name them either way.
find_package(Boost ${delft3d_dep_mode} REQUIRED COMPONENTS headers program_options filesystem date_time)
find_package(precice ${delft3d_dep_mode} REQUIRED)
find_package(GTest ${delft3d_dep_mode} REQUIRED)
find_package(SWAN_MPI ${delft3d_dep_mode} REQUIRED)

# SWAN comes in an MPI and an OpenMP build, but only the MPI one is linked
# (SWAN_MPI::SWAN_MPI, in the wave engine); no target references SWAN_OMP. It stays
# required under Conan, which supplies it, and is optional for a site that builds
# its own SWAN and only needs the variant the wave engine links against.
if(DELFT3D_USE_CONAN_DEPS)
    find_package(SWAN_OMP CONFIG REQUIRED)
else()
    find_package(SWAN_OMP QUIET)
endif()

find_package(inja ${delft3d_dep_mode} REQUIRED)

# main repository directory
cmake_path(GET CMAKE_CURRENT_SOURCE_DIR PARENT_PATH PARENT_DIR)
cmake_path(GET PARENT_DIR PARENT_PATH dir)

# Set unit and integration test root directory
set(unit_tests_dir ${dir}/test/unit_test)
set(integration_tests_dir ${dir}/test/integration_test)

# Specify C++ standard for all targets, disable compiler specific extentions
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(modules.cmake)

# Check CMake optional arguments
set(CONFIGURATION_TYPE "ALL" CACHE STRING "Sets the configuration to be generated by this script.")
message(STATUS "build nr: ${COMMIT_VERSION}")
# Set this to true to group all predefined projects
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# Set compiler flags
enable_language(Fortran C CXX)

# DFlowFM stack size in bytes, used for OpenMP thread stack and Windows linker /STACK flag
set(DFLOWFM_STACK_SIZE_BYTES 20000000 CACHE STRING "DFlowFM stack size in bytes")

if(${CMAKE_Fortran_COMPILER_ID} MATCHES "GNU")
    include(compiler_options/gnu.cmake)
elseif(${CMAKE_Fortran_COMPILER_ID} MATCHES "Intel")
    include(compiler_options/intel.cmake)
else()
    message(FATAL_ERROR "Compiler \"${CMAKE_Fortran_COMPILER_ID}\" does not match known compilers.")
endif()
include(compiler_options/compiler_warning_targets.cmake)
include(compiler_options/fortran_styler.cmake)

# Set available build configurations
set(CMAKE_CONFIGURATION_TYPES "Debug;RelWithDebInfo;Release" CACHE STRING "" FORCE)

# Set Fortran module files location (needed for dependency bubbling on Linux)
set(CMAKE_Fortran_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/fortran_module_dir)

# MPI
set(OSS_MPI "IntelMPI" CACHE STRING "MPI library is IntelMPI")

if(WIN32)
    message(CHECK_START "Setting paths for windows")
    list(APPEND CMAKE_MESSAGE_INDENT "  ")

    # Set pthreads library
    set(pthreads_path ${checkout_src_root}/third_party_open/pthreads/include/x64)
    message(STATUS "pthreads set to ${pthreads_path}")

    # Set mpi_include_path
    if("${OSS_MPI}" STREQUAL "IntelMPI")
        message(STATUS "Intel MPI")
        list(APPEND CMAKE_MESSAGE_INDENT "  ")

        set(mpi_include_path $ENV{ONEAPI_ROOT}/mpi/latest/include)
        set(mpi_module_path ${mpi_include_path}/mpi)
        set(mpi_library_path $<IF:$<CONFIG:Debug>,$ENV{ONEAPI_ROOT}/mpi/latest/lib/mpi/debug,$ENV{ONEAPI_ROOT}/mpi/latest/lib>)
        set(mpi_fortran_library "impi.lib")
        set(mpi_c_library "impi.lib;impicxx.lib")
    else()
        message(WARNING "Did not recognize MPI library \"${OSS_MPI}\"")
    endif()

    message(STATUS "mpi include path \"${mpi_include_path}\"")
    message(STATUS "mpi module path \"${mpi_module_path}\"")
    message(STATUS "mpi library path \"${mpi_library_path}\"")
    message(STATUS "mpi fortran library \"${mpi_fortran_library}\"")
    message(STATUS "mpi c library \"${mpi_c_library}\"")

    list(POP_BACK CMAKE_MESSAGE_INDENT)

    add_definitions(-DHAVE_MPI=1)

    list(POP_BACK CMAKE_MESSAGE_INDENT)
endif()

if(UNIX)
    #Packages
    find_package(Threads REQUIRED)
    find_package(PkgConfig REQUIRED)

    #MPI
    find_package(MPI REQUIRED)
    add_definitions(-DHAVE_MPI)
    # The rest of the tree consumes these two names, as the Windows branch above
    # fills them in; on UNIX FindMPI is what knows them. Without them the module
    # path is empty and mpi.mod is never found.
    set(mpi_module_path ${MPI_Fortran_INCLUDE_DIRS})
    set(mpi_fortran_library MPI::MPI_Fortran)
endif(UNIX)

if(UNIX)
    set(platform_extension sh)
    set(library_suffix so)
    set(library_prefix lib)
elseif(WIN32)
    set(platform_extension bat)
    set(library_suffix dll)
    set(CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_SKIP TRUE)
    set(CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_NO_WARNINGS TRUE) # Ignore warnings about missing ifort libs, we use ifx
    set(library_prefix "")
    include(InstallRequiredSystemLibraries)
endif()

# getopt:
#     Windows: use prebuild library in ".../getopt/x64"
#     Linux  : compile source code  using ".../getopt/cmake_deltares/CMakeLists.txt"
set(getopt_include_path ${checkout_src_root}/third_party_open/getopt)
if(WIN32)
    set(getopt_library_path_win ${checkout_src_root}/third_party_open/getopt/x64/$<IF:$<CONFIG:Debug>,Debug,Release>/)
endif(WIN32)

### Configuration names

string(TOUPPER ${CONFIGURATION_TYPE} configuration_type)
string(TOLOWER ${CONFIGURATION_TYPE} configuration_type_lower)

IF(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(installdir "install_${configuration_type_lower}")
    SET(CMAKE_INSTALL_PREFIX ${checkout_src_root}/../${installdir} CACHE PATH "default" FORCE)
ENDIF(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)

if(CMAKE_GENERATOR MATCHES "Visual Studio")
    # Set root name of the projects in the root UI of Visual Studio
    set(visual_studio_source_group_name "Source Files")
    # auto-install debug
    set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)

    create_vs_user_files()

endif(CMAKE_GENERATOR MATCHES "Visual Studio")

# Basic (single-component) configurations
set(all_configuration "ALL")
set(dflowfm_configuration "DFLOWFM")
set(dflowfm_configuration_interacter "DFLOWFM_INTERACTER")
set(dimr_configuration "DIMR")
set(dwaq_configuration "DWAQ")
set(dwaves_configuration "DWAVES")
set(flow2d3d_configuration "FLOW2D3D")
set(tools_configuration "TOOLS")
set(tools_gpl_configuration "TOOLS_GPL")
set(drr_configuration "DRR")
set(rtc_configuration "RTC")
set(fbc_configuration "FBC")
set(dsle_configuration "DSLE")

# Combined (multi-component) configurations for running specific testbenches
# These are equivalent to our branch-prefixes
set(testbench-all_configuration "ALL-TESTBENCH")
set(testbench-none_configuration "NONE-TESTBENCH")
set(testbench-fm_configuration "FM-TESTBENCH")
set(testbench-d3d4_configuration "D3D4-TESTBENCH")
set(testbench-rr_configuration "RR-TESTBENCH")
set(testbench-waq_configuration "WAQ-TESTBENCH")
set(testbench-part_configuration "PART-TESTBENCH")
set(testbench-wave_configuration "WAVE-TESTBENCH")
set(testbench-tc_configuration "TC-TESTBENCH")

# Combined (multi-component) configurations
# For products that we release
set(fm-suite_configuration "FM-SUITE")
set(d3d4-suite_configuration "D3D4-SUITE")

# Research branches do not specify a product scope, so build and test everything.
if(${configuration_type} STREQUAL "RESEARCH-TESTBENCH")
    set(configuration_type ${testbench-all_configuration})
endif()

# Determine the configuration to make
if(NOT (${configuration_type} STREQUAL ${dflowfm_configuration}
         OR ${configuration_type} STREQUAL ${dflowfm_configuration_interacter}
         OR ${configuration_type} STREQUAL ${dimr_configuration}
         OR ${configuration_type} STREQUAL ${dwaq_configuration}
         OR ${configuration_type} STREQUAL ${dwaves_configuration}
         OR ${configuration_type} STREQUAL ${flow2d3d_configuration}
         OR ${configuration_type} STREQUAL ${tools_configuration}
         OR ${configuration_type} STREQUAL ${tools_gpl_configuration}
         OR ${configuration_type} STREQUAL ${drr_configuration}
         OR ${configuration_type} STREQUAL ${rtc_configuration}
         OR ${configuration_type} STREQUAL ${fbc_configuration}
         OR ${configuration_type} STREQUAL ${dsle_configuration}
         OR ${configuration_type} STREQUAL ${fm-suite_configuration}
         OR ${configuration_type} STREQUAL ${d3d4-suite_configuration}
         OR ${configuration_type} STREQUAL ${all_configuration}
         OR ${configuration_type} STREQUAL ${testbench-all_configuration}
         OR ${configuration_type} STREQUAL ${testbench-none_configuration}
         OR ${configuration_type} STREQUAL ${testbench-fm_configuration}
         OR ${configuration_type} STREQUAL ${testbench-d3d4_configuration}
         OR ${configuration_type} STREQUAL ${testbench-rr_configuration}
         OR ${configuration_type} STREQUAL ${testbench-waq_configuration}
         OR ${configuration_type} STREQUAL ${testbench-part_configuration}
         OR ${configuration_type} STREQUAL ${testbench-wave_configuration}
         OR ${configuration_type} STREQUAL ${testbench-tc_configuration}))
    message(FATAL_ERROR "${configuration_type} not recognized. CMake will abort solution generation now.")
endif()

### Component configurations

# Unit test configuration, should be findable for every configuration
include(configurations/miscellaneous/unit_test_configuration.cmake)

# D-Flow FM configuration
if(${configuration_type} STREQUAL ${dflowfm_configuration})
    message(STATUS "Generating solution for D-Flow FM ...")
    include(configurations/components/dflowfm_configuration_without_interacter.cmake)
endif()

# D-Flow FM (with Interacter-GUI) configuration
if(${configuration_type} STREQUAL ${dflowfm_configuration_interacter})
    message(STATUS "Generating solution for D-Flow FM (with interacter) ...")
    include(configurations/components/dflowfm_configuration_interacter.cmake)
endif()

# DIMR configuration
if(${configuration_type} STREQUAL ${dimr_configuration})
    message(STATUS "Generating solution for DIMR ...")
    include(configurations/components/dimr_configuration.cmake)
endif()

# D-WAQ configuration
if(${configuration_type} STREQUAL ${dwaq_configuration})
    message(STATUS "Generating solution for D-Waq ...")
    include(configurations/components/dwaq_configuration.cmake)
    message(STATUS "Finished generating solution for D-Waq")
endif()

# D-Waves configuration
if(${configuration_type} STREQUAL ${dwaves_configuration})
    message(STATUS "Generating solution for D-Waves ...")
    include(configurations/components/dwaves_configuration.cmake)
endif()

# Flow2D3D (Delft3D4) configuration
if(${configuration_type} STREQUAL ${flow2d3d_configuration})
    message(STATUS "Generating solution for Flow2D3D ...")
    include(configurations/components/flow2d3d_configuration.cmake)
endif()

# Tools configuration
if(${configuration_type} STREQUAL ${tools_configuration})
    message(STATUS "Generating solution for Tools ...")
    include(configurations/miscellaneous/tools_configuration_no_fm.cmake)
endif()

# Tools_gpl configuration
if(${configuration_type} STREQUAL ${tools_gpl_configuration})
    message(STATUS "Generating solution for Tools_GPL ...")
    include(configurations/miscellaneous/tools_gpl_configuration.cmake)
endif()

# RTC configuration
if(${configuration_type} STREQUAL ${rtc_configuration})
    message(STATUS "Generating solution for rtc ...")
    include(configurations/components/rtc_configuration.cmake)
endif()

# D-RR configuration
if(${configuration_type} STREQUAL ${drr_configuration})
    message(STATUS "Generating solution for D-RR ...")
    include(configurations/components/drr_configuration.cmake)
endif()

# FBC configuration
if(${configuration_type} STREQUAL ${fbc_configuration})
    message(STATUS "Generating solution for FBC-tools ...")
    include(configurations/components/fbc_configuration.cmake)
endif()

if(${configuration_type} STREQUAL ${dsle_configuration})
    message(STATUS "Generating solution for D-SLE ...")
    include(configurations/components/dsle_configuration.cmake)
endif()

### Composed configurations for testbenches

# ALL configuration
if(${configuration_type} STREQUAL ${testbench-all_configuration} OR ${configuration_type} STREQUAL ${all_configuration})
    message(STATUS "Generating solution for all testbenches ...")
    include(configurations/testbench/all_configuration.cmake)
endif()

# NONE configuration
if(${configuration_type} STREQUAL ${testbench-none_configuration})
    message(STATUS "Generating solution for none testbenches ...")
    include(configurations/testbench/waq_configuration.cmake)
endif()

# D3D4 configuration
if(${configuration_type} STREQUAL ${testbench-d3d4_configuration})
    message(STATUS "Generating solution for d3d4 testbench ...")
    include(configurations/testbench/d3d4_configuration.cmake)
endif()

# RR configuration
if(${configuration_type} STREQUAL ${testbench-rr_configuration})
    message(STATUS "Generating solution for rr testbench ...")
    include(configurations/testbench/rr_configuration.cmake)
endif()

# WAQ configuration
if(${configuration_type} STREQUAL ${testbench-waq_configuration})
    message(STATUS "Generating solution for waq testbench ...")
    include(configurations/testbench/waq_configuration.cmake)
endif()

# PART configuration
if(${configuration_type} STREQUAL ${testbench-part_configuration})
    message(STATUS "Generating solution for part testbench ...")
    include(configurations/testbench/part_configuration.cmake)
endif()

# WAVE configuration
if(${configuration_type} STREQUAL ${testbench-wave_configuration})
    message(STATUS "Generating solution for wave testbench ...")
    include(configurations/testbench/wave_configuration.cmake)
endif()

# TC configuration
if(${configuration_type} STREQUAL ${testbench-tc_configuration})
    message(STATUS "Generating solution for tc testbench ...")
    include(configurations/testbench/waq_configuration.cmake)
endif()

### Composed configurations for releases

# Delft3D-FM suite configuration (dimr, dflowfm, dwaq, dwaves, and some tools)
if(${configuration_type} STREQUAL ${fm-suite_configuration} OR ${configuration_type} STREQUAL ${testbench-fm_configuration})
    message(STATUS "Generating solution for Delft3D-FM ...")
    include(configurations/suites/fm_configuration.cmake)
endif()

# Delft3D4 suite configuration (dflow2d3d, dwaq, dwaves, and some tools)
if(${configuration_type} STREQUAL ${d3d4-suite_configuration})
    message(STATUS "Generating solution for Delft3D4 ...")
    include(configurations/suites/d3d4_configuration.cmake)
endif()

if(UNIX)
    add_subdirectory(${checkout_src_root}/${install_linux_libs_module} install_linux_libs)
endif()

install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/../../bsd-2.txt
    ${CMAKE_CURRENT_SOURCE_DIR}/../../bsd-3.txt
    ${CMAKE_CURRENT_SOURCE_DIR}/../../agpl-3.0.txt
    ${CMAKE_CURRENT_SOURCE_DIR}/../../gpl-3.0.txt
    ${CMAKE_CURRENT_SOURCE_DIR}/../../lgpl-2.1.txt
    DESTINATION share)

# Install proj.db only if PROJ library is found and being used
if(TARGET PROJ::proj)
    install(FILES "$<IF:$<CONFIG:Debug>,${proj_PACKAGE_FOLDER_DEBUG},$<IF:$<CONFIG:RelWithDebInfo>,${proj_PACKAGE_FOLDER_RELWITHDEBINFO},${proj_PACKAGE_FOLDER_RELEASE}>>/res/proj.db"
        DESTINATION share/proj)
endif()
