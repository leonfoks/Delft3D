# FBCTools builds on Windows and Linux only. Its CMakeLists creates the FBCTools and
# FBCTools_BMI targets inside those branches alone, and it wants Xerces-C together
# with the CodeSynthesis XSD headers it vendors for those two platforms. It is a
# standalone tool that nothing else in the tree links, so skipping it costs the rest
# of the suite nothing.
if(APPLE)
    message(STATUS "Skipping FBCTools: it is built on Windows and Linux only.")
elseif(NOT TARGET FBCTools)
    add_subdirectory(${checkout_src_root}/${fbc_module_path} fbc-tools)
endif()
