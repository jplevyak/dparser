cmake_minimum_required(VERSION 3.0)g
g
project(dparser VERSION 1.30.0.0)g
g
include(CPack)g
include(GenerateExportHeader)g
include(CMakePackageConfigHelpers)g
g
option(DEBUG "DEBUG" FALSE)g
option(OPTIMIZE "OPTIMIZE" TRUE)g
option(PROFILE "PROFILE" FALSE)g
option(USE_GC "USE_GC" FALSE)g
option(LEAK_DETECT "LEAK_DETECT" FALSE)g
option(USE_FREELISTS "OPTIMIZE" TRUE)g
g
g
add_executable(make_dparserg
  make_dparser.cg
  version.cg
)g
g
add_executable(sample_parserg
  sample_parser.cg
  sample.gg
  ${CMAKE_CURRENT_BINARY_DIR}/sample.g.d_parser.cg
)g
add_dependencies(sample_parser make_dparser)g
g
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/sample.g.d_parser.cg
  DEPENDS make_dparser sample.gg
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR} VERBATIMg
  COMMAND $<TARGET_FILE:make_dparser> ${CMAKE_CURRENT_SOURCE_DIR}/sample.g -o ${CMAKE_CURRENT_BINARY_DIR}/sample.g.d_parser.cg
)g
g
add_executable(test_parserg
  test_parser.cg
  my.gg
  ${CMAKE_CURRENT_BINARY_DIR}/my.g.d_parser.cg
)g
add_dependencies(test_parser make_dparser)g
g
add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/my.g.d_parser.cg
  DEPENDS make_dparser my.gg
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR} VERBATIMg
  COMMAND $<TARGET_FILE:make_dparser> ${CMAKE_CURRENT_SOURCE_DIR}/my.g -o ${CMAKE_CURRENT_BINARY_DIR}/my.g.d_parser.cg
)g
g
add_library(mkdparse STATICg
  mkdparse.c g
  write_tables.c g
  grammar.g.c g
  gram.c g
  lex.c g
  lr.cg
  version.cg
)g
g
add_library(dparse STATICg
  arg.c g
  parse.c g
  scan.c g
  dsymtab.c g
  util.c g
  read_binary.c g
  dparse_tree.cg
  version.cg
)g
g
target_link_libraries(make_dparser PRIVATE mkdparse dparse)g
target_link_libraries(sample_parser PRIVATE mkdparse dparse)g
target_link_libraries(test_parser PRIVATE mkdparse dparse)g
g
macro(d_comple_defs _target)g
  target_compile_definitions(${_target} PRIVATE g
    -DD_MAJOR_VERSION=${PROJECT_VERSION_MAJOR}g
    -DD_MINOR_VERSION=${PROJECT_VERSION_MINOR}g
  )g
  if(${DEBUG})g
    target_compile_definitions(${_target} PRIVATE -DDEBUG -D_DEBUG)g
  endif()g
  if(${USE_GC})g
    target_compile_definitions(${_target} PRIVATE -DUSE_GC)g
  endif()g
  if(${LEAK_DETECT})g
    target_compile_definitions(${_target} PRIVATE -DLEAK_DETECT)g
  endif()g
  target_include_directories(${_target} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})g
endmacro()g
g
d_comple_defs(make_dparser)g
d_comple_defs(sample_parser)g
d_comple_defs(test_parser)g
d_comple_defs(mkdparse)g
d_comple_defs(dparse)g
g
generate_export_header(dparse)g
g
install(g
  TARGETS make_dparser sample_parser test_parserg
  EXPORT DParseTargetsg
  RUNTIME DESTINATION bing
)g
install(g
  TARGETS mkdparse dparseg
  EXPORT DParseTargetsg
  ARCHIVE DESTINATION libg
)g
install(g
  FILES d.h dparse.hg
  DESTINATION includeg
)g
configure_file(dparser-config.cmake.in ${CMAKE_CURRENT_BINARY_DIR}/dparser-config.cmake @ONLY)g
install(g
  FILES dparser-generate.cmake ${CMAKE_CURRENT_BINARY_DIR}/dparser-config.cmakeg
  DESTINATION lib/cmake/dparserg
)g
g
g
write_basic_package_version_file(g
  "${CMAKE_CURRENT_BINARY_DIR}/DParseVersion.cmake"g
  VERSION ${PROJECT_VERSION}g
  COMPATIBILITY AnyNewerVersiong
)g
g
export(EXPORT DParseTargetsg
  FILE "${CMAKE_CURRENT_BINARY_DIR}/DParseTargets.cmake"g
  NAMESPACE dparser::g
)g
g
install(g
  EXPORT DParseTargetsg
  FILE DParseTargets.cmakeg
  NAMESPACE dparser::g
  DESTINATION lib/cmake/dparserg
)g
