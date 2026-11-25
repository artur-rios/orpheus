cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# The system's unwinder, loaded before anything else. Flutter's engine exports
# LLVM's unwinder under libgcc's names (`_Unwind_RaiseException@GCC_3.0`), and
# the dynamic linker binds a symbol to the first library in load order that
# defines it. With the engine first, the LuaJIT inside an Arch-built libmpv
# raised its Lua errors through the engine's unwinder and the application died
# of a segmentation fault at the first song played. BEFORE puts the library
# ahead of the objects and of every plugin, so it is the executable's first
# needed library; --no-as-needed keeps it although nothing here calls it.
# tools/check-linux-unwinder.sh fails the build if that ever stops being true.
target_link_options(${BINARY_NAME} BEFORE PRIVATE
  "LINKER:--push-state,--no-as-needed,-lgcc_s,--pop-state")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
