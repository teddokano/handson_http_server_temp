cmake_minimum_required(VERSION 3.20.0)

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
find_package(Python REQUIRED COMPONENTS Interpreter)

project(http_server_temp_handson)

target_sources(app PRIVATE src/main.c)

# HTTP_RESOURCE_DEFINE() (main.c) places each resource descriptor into a
# named iterable linker section (http_resource_desc_<service>). Without this
# linker script the section never gets created and the http server can't
# enumerate its resources at boot.
zephyr_linker_sources(SECTIONS sections-rom.ld)
zephyr_linker_section_ifdef(CONFIG_NET_SAMPLE_HTTPS_SERVICE
  NAME http_resource_desc_test_https_service
  KVMA RAM_REGION GROUP RODATA_REGION
)
zephyr_linker_section_ifdef(CONFIG_NET_SAMPLE_HTTP_SERVICE
  NAME http_resource_desc_test_http_service
  KVMA RAM_REGION GROUP RODATA_REGION
)

# index.html / main.js are gzip-compressed into *.gz.inc at build time and
# included directly by main.c (index_html_gz / main_js_gz).
set(gen_dir ${ZEPHYR_BINARY_DIR}/include/generated/)

foreach(web_resource
  index.html
  main.js
)
  generate_inc_file_for_target(app
    src/static_web_resources/${web_resource}
    ${gen_dir}/${web_resource}.gz.inc
    --gzip
  )
endforeach()
