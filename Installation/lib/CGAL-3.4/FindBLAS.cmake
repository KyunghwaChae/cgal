# Find BLAS library
#
# This module finds an installed library that implements the BLAS
# linear-algebra interface (see http://www.netlib.org/blas/).
# The list of libraries searched for is mainly taken
# from the autoconf macro file, acx_blas.m4 (distributed at
# http://ac-archive.sourceforge.net/ac-archive/acx_blas.html).
#
# This module sets the following variables:
#  BLAS_FOUND - set to true if a library implementing the BLAS interface
#    is found
#  BLAS_DEFINITIONS - Compilation options to use BLAS
#  BLAS_LINKER_FLAGS - Linker flags to use BLAS (excluding -l
#    and -L).
#  BLAS_LIBRARIES_DIR - Directories containing the BLAS libraries.
#     May be null if BLAS_LIBRARIES contains libraries name using full path.
#  BLAS_LIBRARIES - List of libraries to link against BLAS interface.
#     May be null if the compiler supports auto-link (e.g. VC++).
#  BLAS_USE_FILE - The name of the cmake module to include to compile
#     applications or libraries using BLAS.
#
# This module was modified by CGAL team:
# - find BLAS library shipped with TAUCS
# - find libraries for a C++ compiler, instead of Fortran
# - added BLAS_DEFINITIONS and BLAS_LIBRARIES_DIR
# - removed BLAS95_LIBRARIES
#
# TODO (CGAL):
# - find CBLAS (http://www.netlib.org/cblas)?


include(CheckFunctionExists)

include(CGAL_GeneratorSpecificSettings)


# This macro checks for the existence of the combination of fortran libraries
# given by _list.  If the combination is found, this macro checks (using the
# check_function_exists macro) whether can link against that library
# combination using the name of a routine given by _name using the linker
# flags given by _flags.  If the combination of libraries is found and passes
# the link test, LIBRARIES is set to the list of complete library paths that
# have been found and DEFINITIONS to the required definitions.
# Otherwise, they are set to FALSE.
# N.B. _prefix is the prefix applied to the names of all cached variables that
# are generated internally and marked advanced by this macro.
macro(check_fortran_libraries DEFINITIONS LIBRARIES _prefix _name _flags _list _path)
  #message("DEBUG: check_fortran_libraries(${_list} in ${_path})")

  # Check for the existence of the libraries given by _list
  set(_libraries_found TRUE)
  set(_libraries_work FALSE)
  set(${DEFINITIONS})
  set(${LIBRARIES})
  set(_combined_name)
  foreach(_library ${_list})
    set(_combined_name ${_combined_name}_${_library})

    if(_libraries_found)
      # search first in ${_path}
      find_library(${_prefix}_${_library}_LIBRARY
                  NAMES ${_library}
                  PATHS ${_path} NO_DEFAULT_PATH
                  )
      # if not found, search in environment variables and system
      if ( WIN32 )
        find_library(${_prefix}_${_library}_LIBRARY
                    NAMES ${_library}
                    PATHS ENV LIB
                    )
      elseif ( APPLE )
        find_library(${_prefix}_${_library}_LIBRARY
                    NAMES ${_library}
                    PATHS /usr/local/lib /usr/lib /usr/local/lib64 /usr/lib64 ENV DYLD_LIBRARY_PATH
                    )
      else ()
        find_library(${_prefix}_${_library}_LIBRARY
                    NAMES ${_library}
                    PATHS /usr/local/lib /usr/lib /usr/local/lib64 /usr/lib64 ENV LD_LIBRARY_PATH
                    )
      endif()
      mark_as_advanced(${_prefix}_${_library}_LIBRARY)
      set(${LIBRARIES} ${${LIBRARIES}} ${${_prefix}_${_library}_LIBRARY})
      set(_libraries_found ${${_prefix}_${_library}_LIBRARY})
    endif(_libraries_found)
  endforeach(_library ${_list})
  if(_libraries_found)
    set(_libraries_found ${${LIBRARIES}})
  endif()

  # Test this combination of libraries with the Fortran/f2c interface.
  # We test the Fortran interface first as it is well standardized.
  if(_libraries_found AND NOT _libraries_work)
    set(${DEFINITIONS}  "-D${_prefix}_USE_F2C")
    set(${LIBRARIES}    ${_libraries_found})
    # Some C++ linkers require the f2c library to link with Fortran libraries.
    # I do not know which ones, thus I just add the f2c library if it is available.
    find_package( F2C QUIET )
    if ( F2C_FOUND )
      set(${DEFINITIONS}  ${${DEFINITIONS}} ${F2C_DEFINITIONS})
      set(${LIBRARIES}    ${${LIBRARIES}} ${F2C_LIBRARIES})
    endif()
    set(CMAKE_REQUIRED_DEFINITIONS  ${${DEFINITIONS}})
    set(CMAKE_REQUIRED_LIBRARIES    ${_flags} ${${LIBRARIES}})
    #message("DEBUG: CMAKE_REQUIRED_DEFINITIONS = ${CMAKE_REQUIRED_DEFINITIONS}")
    #message("DEBUG: CMAKE_REQUIRED_LIBRARIES = ${CMAKE_REQUIRED_LIBRARIES}")
    # Check if function exists with f2c calling convention (ie a trailing underscore)
    check_function_exists(${_name}_ ${_prefix}_${_name}_${_combined_name}_f2c_WORKS)
    set(CMAKE_REQUIRED_DEFINITIONS})
    set(CMAKE_REQUIRED_LIBRARIES)
    mark_as_advanced(${_prefix}_${_name}_${_combined_name}_f2c_WORKS)
    set(_libraries_work ${${_prefix}_${_name}_${_combined_name}_f2c_WORKS})
  endif(_libraries_found AND NOT _libraries_work)

  # If not found, test this combination of libraries with a C interface.
  # A few implementations (ie ACML) provide a C interface. Unfortunately, there is no standard.
  if(_libraries_found AND NOT _libraries_work)
    set(${DEFINITIONS})
    set(${LIBRARIES}    ${_libraries_found})
    set(CMAKE_REQUIRED_DEFINITIONS)
    set(CMAKE_REQUIRED_LIBRARIES ${_flags} ${${LIBRARIES}})
    #message("DEBUG: CMAKE_REQUIRED_LIBRARIES = ${CMAKE_REQUIRED_LIBRARIES}")
    check_function_exists(${_name} ${_prefix}_${_name}${_combined_name}_WORKS)
    set(CMAKE_REQUIRED_LIBRARIES)
    mark_as_advanced(${_prefix}_${_name}${_combined_name}_WORKS)
    set(_libraries_work ${${_prefix}_${_name}${_combined_name}_WORKS})
  endif(_libraries_found AND NOT _libraries_work)

  # on failure
  if(NOT _libraries_work)
    set(${DEFINITIONS} FALSE)
    set(${LIBRARIES} FALSE)
  endif()
  #message("DEBUG: ${DEFINITIONS} = ${${DEFINITIONS}}")
  #message("DEBUG: ${LIBRARIES} = ${${LIBRARIES}}")
endmacro(check_fortran_libraries)


#
# main
#

# Is it already configured?
if (BLAS_LIBRARIES_DIR OR BLAS_LIBRARIES)

  set(BLAS_FOUND TRUE)

else(BLAS_LIBRARIES_DIR OR BLAS_LIBRARIES)

  # Look first for the BLAS distributed with CGAL in auxiliary/taucs.
  # Set CGAL_TAUCS_FOUND, CGAL_TAUCS_INCLUDE_DIR and CGAL_TAUCS_LIBRARIES_DIR.
  include(CGAL_Locate_CGAL_TAUCS)

  # Search for BLAS libraries in ${CGAL_TAUCS_LIBRARIES_DIR} (BLAS shipped with CGAL),
  # else in $BLAS_LIB_DIR environment variable.
  if(CGAL_TAUCS_FOUND AND CGAL_AUTO_LINK_ENABLED)

    # if VC++: done
    set( BLAS_LIBRARIES_DIR  "${CGAL_TAUCS_LIBRARIES_DIR}"
                             CACHE FILEPATH "Directories containing the BLAS libraries")

  else(CGAL_TAUCS_FOUND AND CGAL_AUTO_LINK_ENABLED)

    # If Unix, search for BLAS function in possible libraries

    # BLAS in ATLAS library? (http://math-atlas.sourceforge.net/)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "cblas;f77blas;atlas"
      "${CGAL_TAUCS_LIBRARIES_DIR} $ENV{BLAS_LIB_DIR}"
      )
    endif()

    # BLAS in PhiPACK libraries? (requires generic BLAS lib, too)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "sgemm;dgemm;blas"
      "${CGAL_TAUCS_LIBRARIES_DIR} $ENV{BLAS_LIB_DIR}"
      )
    endif()

    # BLAS in Alpha CXML library?
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "cxml"
      "${CGAL_TAUCS_LIBRARIES_DIR} $ENV{BLAS_LIB_DIR}"
      )
    endif()

    # BLAS in Alpha DXML library? (now called CXML, see above)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "dxml"
      "${CGAL_TAUCS_LIBRARIES_DIR} $ENV{BLAS_LIB_DIR}"
      )
    endif()

    # BLAS in Sun Performance library?
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      "-xlic_lib=sunperf"
      "sunperf;sunmath"
      "${CGAL_TAUCS_LIBRARIES_DIR} $ENV{BLAS_LIB_DIR}"
      )
      if(BLAS_LIBRARIES)
        # Extra linker flag
        set(BLAS_LINKER_FLAGS "-xlic_lib=sunperf")
      endif()
    endif()

    # BLAS in SCSL library?  (SGI/Cray Scientific Library)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "scsl"
      "${CGAL_TAUCS_LIBRARIES_DIR} $ENV{BLAS_LIB_DIR}"
      )
    endif()

    # BLAS in SGIMATH library?
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "complib.sgimath"
      "${CGAL_TAUCS_LIBRARIES_DIR} $ENV{BLAS_LIB_DIR}"
      )
    endif()

    # BLAS in IBM ESSL library? (requires generic BLAS lib, too)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "essl;blas"
      "${CGAL_TAUCS_LIBRARIES_DIR} $ENV{BLAS_LIB_DIR}"
      )
    endif()

    #BLAS in intel mkl 10 library? (em64t 64bit)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "mkl_intel_lp64;mkl_intel_thread;mkl_core;guide;pthread"
      "${CGAL_TAUCS_LIBRARIES_DIR} $ENV{BLAS_LIB_DIR}"
      )
    endif()

    ### windows version of intel mkl 10?
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      SGEMM
      ""
      "mkl_c_dll;mkl_intel_thread_dll;mkl_core_dll;libguide40"
      "${CGAL_TAUCS_LIBRARIES_DIR} $ENV{BLAS_LIB_DIR}"
      )
    endif()

    #older versions of intel mkl libs

    # BLAS in intel mkl library? (shared)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "mkl;guide;pthread"
      "${CGAL_TAUCS_LIBRARIES_DIR} $ENV{BLAS_LIB_DIR}"
      )
    endif()

    #BLAS in intel mkl library? (static, 32bit)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "mkl_ia32;guide;pthread"
      "${CGAL_TAUCS_LIBRARIES_DIR} $ENV{BLAS_LIB_DIR}"
      )
    endif()

    #BLAS in intel mkl library? (static, em64t 64bit)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "mkl_em64t;guide;pthread"
      "${CGAL_TAUCS_LIBRARIES_DIR} $ENV{BLAS_LIB_DIR}"
      )
    endif()

    #BLAS in acml library?
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "acml"
      "${CGAL_TAUCS_LIBRARIES_DIR} $ENV{BLAS_LIB_DIR}"
      )
    endif()

    # Apple BLAS library?
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "Accelerate"
      "${CGAL_TAUCS_LIBRARIES_DIR} $ENV{BLAS_LIB_DIR}"
      )
    endif()

    if ( NOT BLAS_LIBRARIES )
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "vecLib"
      "${CGAL_TAUCS_LIBRARIES_DIR} $ENV{BLAS_LIB_DIR}"
      )
    endif ( NOT BLAS_LIBRARIES )

    # Generic BLAS library?
    # This configuration *must* be the last try as this library is notably slow.
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "blas"
      "${CGAL_TAUCS_LIBRARIES_DIR} $ENV{BLAS_LIB_DIR}"
      )
    endif()

    # Add variables to cache
    set( BLAS_DEFINITIONS   "${BLAS_DEFINITIONS}"
                            CACHE FILEPATH "Compilation options to use BLAS" )
    set( BLAS_LINKER_FLAGS  "${BLAS_LINKER_FLAGS}"
                            CACHE FILEPATH "Linker flags to use BLAS" )
    set( BLAS_LIBRARIES     "${BLAS_LIBRARIES}"
                            CACHE FILEPATH "BLAS libraries name" )

  endif(CGAL_TAUCS_FOUND AND CGAL_AUTO_LINK_ENABLED)

  if(BLAS_LIBRARIES_DIR OR BLAS_LIBRARIES)
    set(BLAS_FOUND TRUE)
  else()
    set(BLAS_FOUND FALSE)
  endif()

  if(NOT BLAS_FIND_QUIETLY)
    if(BLAS_FOUND)
      message(STATUS "A library with BLAS API found.")
      set(BLAS_USE_FILE "CGAL_UseBLAS")
    else(BLAS_FOUND)
      if(BLAS_FIND_REQUIRED)
        message(FATAL_ERROR "A required library with BLAS API not found. Please specify library location.")
      else()
        message(STATUS "A library with BLAS API not found. Please specify library location.")
      endif()
    endif(BLAS_FOUND)
  endif(NOT BLAS_FIND_QUIETLY)

  #message("DEBUG: BLAS_DEFINITIONS = ${BLAS_DEFINITIONS}")
  #message("DEBUG: BLAS_LINKER_FLAGS = ${BLAS_LINKER_FLAGS}")
  #message("DEBUG: BLAS_LIBRARIES = ${BLAS_LIBRARIES}")
  #message("DEBUG: BLAS_LIBRARIES_DIR = ${BLAS_LIBRARIES_DIR}")
  #message("DEBUG: BLAS_FOUND = ${BLAS_FOUND}")

endif(BLAS_LIBRARIES_DIR OR BLAS_LIBRARIES)

