# Set GNU compiler specific flags:
enable_language (Fortran)
set(src_root_dir ${CMAKE_SOURCE_DIR}/..)

if (WIN32)
    message(FATAL_ERROR "GNU compilers are not supported on Windows. CMake will exit.")
endif(WIN32)

if (UNIX)
    # Set optional flags:
    message(STATUS "Setting Fortran compiler flags in Unix")

    set(CMAKE_CXX_FLAGS                          "-fPIC -fopenmp")
    set(CMAKE_CXX_FLAGS_DEBUG                    "-g -O0")
    set(CMAKE_CXX_FLAGS_RELWITHDEBINFO           "-g -O2")
    set(CMAKE_CXX_FLAGS_RELEASE                  "-O2")

    set(CMAKE_C_FLAGS                            "-fPIC -fopenmp")
    set(CMAKE_C_FLAGS_DEBUG                      "-g -O0")
    set(CMAKE_C_FLAGS_RELWITHDEBINFO             "-g -O2")
    set(CMAKE_C_FLAGS_RELEASE                    "-O2")
    set(CMAKE_Fortran_FLAGS                      "-fPIC -fopenmp -ffixed-line-length-132 -ffree-line-length-512 -fallow-argument-mismatch")
    set(CMAKE_Fortran_FLAGS_DEBUG                "-g -O0")
    set(CMAKE_Fortran_FLAGS_RELWITHDEBINFO       "-g -O2")
    set(CMAKE_Fortran_FLAGS_RELEASE              "-O2")

    set(cpp_compiler_flags                       "-std=c++17")

    set(file_preprocessor_flag                   "-cpp")
    set(traceback_flag                           "-fbacktrace")

    # Intel's -auto and -reentrancy threaded both mean "locals on the stack,
    # recursion allowed", which is what -frecursive does.
    set(automatic_local_variable_storage_flag    "-frecursive")
    set(generate_reentrancy_threaded_flag        "-frecursive")
    set(qauto_threaded_flags                     "SHELL:${automatic_local_variable_storage_flag}")

    # Intel -r8 widens default REAL to 8 bytes and leaves DOUBLE PRECISION at 8.
    # -fdefault-real-8 on its own would also widen DOUBLE PRECISION to 16 bytes
    # and change the ABI, so -fdefault-double-8 has to follow it.
    # SHELL: because the value is two flags and call sites pass it as one
    # argument, as they do for Intel's single -r8.
    set(real_size_64_flag                        "SHELL:-fdefault-real-8 -fdefault-double-8")

    set(openmp_flag                              "-fopenmp")
    set(check_bounds_flag                        "-fcheck=bounds")
    set(check_nobounds_flag                      "-fno-check=bounds")
    set(check_pointers_flag                      "-fcheck=pointer")
    # gfortran has no -fno-check=pointer counterpart, so a target that asks for
    # pointer checking to be off simply keeps the Debug default.
    set(check_nopointers_flag                    "")
    set(check_stack_flag                         "-fstack-check")
    set(floating_point_exception_flag            "-ffpe-trap=invalid,zero,overflow")

    set(CMAKE_POSITION_INDEPENDENT_CODE ON)

    # Set debug flags:
    string(APPEND CMAKE_Fortran_FLAGS_DEBUG " ${check_stack_flag} ${check_bounds_flag} ${traceback_flag} ${check_pointers_flag} ${floating_point_exception_flag}")
    string(APPEND CMAKE_Fortran_FLAGS_RELWITHDEBINFO " ${traceback_flag}")
endif(UNIX)

set(waq_default_flags ${file_preprocessor_flag} ${traceback_flag})
