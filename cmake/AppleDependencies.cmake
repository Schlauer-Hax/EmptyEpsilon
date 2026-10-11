# Store builds use target-built libraries, never Homebrew's macOS binaries.
enable_language(OBJC OBJCXX)
# Each preset builds one SDK; keep bundle generator expressions usable by scripts.
set_property(GLOBAL PROPERTY XCODE_EMIT_EFFECTIVE_PLATFORM_NAME OFF)
# Only the app belongs in an archive; installing static libraries makes it generic.
set(CMAKE_XCODE_ATTRIBUTE_SKIP_INSTALL YES)
# Keep symbols for TestFlight crash reports, including code in static dependencies.
foreach(language C CXX OBJC OBJCXX)
    string(APPEND CMAKE_${language}_FLAGS_RELEASE " -g")
endforeach()
include(FetchContent)
find_package(Git REQUIRED)
set(WITH_DISCORD OFF CACHE BOOL "Build with Discord support" FORCE)
set(WITH_FREETYPE2 bundled CACHE STRING "FreeType source" FORCE)
set(WITH_GLM bundled CACHE STRING "GLM source" FORCE)
set(WITH_OPUS bundled CACHE STRING "Opus source" FORCE)
set(SHARED_SP OFF CACHE BOOL "Build static SeriousProton" FORCE)
if(STEAMSDK)
    message(FATAL_ERROR "Steam SDK is not supported in Apple store builds")
endif()
set(SDL_SHARED OFF CACHE BOOL "Build shared SDL" FORCE)
set(SDL_STATIC ON CACHE BOOL "Build static SDL" FORCE)
set(SDL_TEST OFF CACHE BOOL "Build SDL tests" FORCE)
set(SDL_TESTS OFF CACHE BOOL "Build SDL test applications" FORCE)
set(SDL_DISABLE_INSTALL ON CACHE BOOL "Install SDL" FORCE)
FetchContent_Declare(sdl2
    URL https://www.libsdl.org/release/SDL2-2.32.8.tar.gz
    URL_HASH SHA256=0ca83e9c9b31e18288c7ec811108e58bac1f1bb5ec6577ad386830eac51c787e
    PATCH_COMMAND ${GIT_EXECUTABLE} apply --whitespace=nowarn
        ${CMAKE_CURRENT_LIST_DIR}/../apple/sdl2.patch)
FetchContent_MakeAvailable(sdl2)

# Keep the engine changes reproducible until they can be upstreamed. Desktop builds
# continue using SERIOUS_PROTON_DIR. This copy is private to the store build.
FetchContent_Declare(apple_seriousproton
    URL https://codeload.github.com/daid/SeriousProton/tar.gz/b137f0f287a6378a1284057eb588a5d43f2468e2
    URL_HASH SHA256=97d125f071ab6ce1404ebc9e3a1c37789bd3aea32fd7ed7e63d1342031ae7088
    PATCH_COMMAND ${GIT_EXECUTABLE} apply --whitespace=nowarn
        ${CMAKE_CURRENT_LIST_DIR}/../apple/seriousproton.patch)
FetchContent_GetProperties(apple_seriousproton)
if(NOT apple_seriousproton_POPULATED)
    FetchContent_Populate(apple_seriousproton)
endif()
set(SERIOUS_PROTON_DIR "${apple_seriousproton_SOURCE_DIR}")
if(EE_APPLE_MOBILE)
    add_compile_definitions(EE_APPLE_MOBILE)
else()
    add_compile_definitions(EE_APPLE_TESTFLIGHT)
endif()
if(CMAKE_SYSTEM_NAME STREQUAL "tvOS")
    add_compile_definitions(EE_TVOS)
endif()
