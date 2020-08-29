function(dparse_generate _g_file _out_file)
  add_custom_command(OUTPUT ${_out_file}
    DEPENDS ${_g_file}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR} VERBATIM
    COMMAND dparser::make_dparser ${_g_file} -o ${_out_file}
  )
  set_source_files_properties(${_out_file} PROPERTIES GENERATED 1)
endfunction() 
