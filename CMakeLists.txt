cmake_minimum_required(VERSION 3.0)

project(dparser VERSION 1.30.0.0)

option(DEBUG "DEBUG" FALSE)
option(OPTIMIZE "OPTIMIZE" TRUE)
option(PROFILE "PROFILE" FALSE)
option(USE_GC "USE_GC" FALSE)
option(LEAK_DETECT "LEAK_DETECT" FALSE)
option(USE_FREELISTS "OPTIMIZE" TRUE)

if(${USE_GC})
  
endif()

add_executable(make_dparser
  make_dparser.c
  version.c
)

add_executable(sample_parser
  sample_parser.c
  sample.g
  ${CMAKE_CURRENT_BINARY_DIR}/sample.g.d_parser.c
)
add_dependencies(sample_parser make_dparser)

add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/sample.g.d_parser.c
  DEPENDS make_dparser sample.g
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR} VERBATIM
  COMMAND make_dparser ${CMAKE_CURRENT_SOURCE_DIR}/sample.g
)

add_executable(test_parser
  test_parser.c
  my.g
  ${CMAKE_CURRENT_BINARY_DIR}/my.g.d_parser.c
)
add_dependencies(test_parser make_dparser)

add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/my.g.d_parser.c
  DEPENDS make_dparser my.g
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR} VERBATIM
  COMMAND make_dparser ${CMAKE_CURRENT_SOURCE_DIR}/my.g
)

add_library(mkdparse STATIC
  mkdparse.c 
  write_tables.c 
  grammar.g.c 
  gram.c 
  lex.c 
  lr.c
  version.c
)

add_library(dparse STATIC
  arg.c 
  parse.c 
  scan.c 
  symtab.c 
  util.c 
  read_binary.c 
  dparse_tree.c
  version.c
)



target_link_libraries(make_dparser PRIVATE mkdparse dparse)
target_link_libraries(sample_parser PRIVATE mkdparse dparse)
target_link_libraries(test_parser PRIVATE mkdparse dparse)

macro(d_comple_defs _target)
  target_compile_definitions(${_target} PRIVATE 
    -DD_MAJOR_VERSION=${PROJECT_VERSION_MAJOR}
    -DD_MINOR_VERSION=${PROJECT_VERSION_MINOR}
    -DD_BUILD_VERSION="${PROJECT_VERSION}"
  )
  if(${DEBUG})
    target_compile_definitions(${_target} PRIVATE -DDEBUG -D_DEBUG)
  endif()
  if(${USE_GC})
    target_compile_definitions(${_target} PRIVATE -DUSE_GC)
  endif()
  if(${LEAK_DETECT})
    target_compile_definitions(${_target} PRIVATE -DLEAK_DETECT)
  endif()
endmacro()

d_comple_defs(make_dparser)
d_comple_defs(sample_parser)
d_comple_defs(test_parser)
d_comple_defs(mkdparse)
d_comple_defs(dparse)

