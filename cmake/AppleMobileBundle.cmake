set(EE_APPLE_BUNDLE_ID "io.github.daid.EmptyEpsilon" CACHE STRING "Apple application bundle identifier")
option(EE_APPLE_MULTICAST "Sign with Apple's approved multicast entitlement" OFF)
if(CMAKE_SYSTEM_NAME STREQUAL "tvOS")
    set(EE_APPLE_DEVICE_FAMILY 3)
    set(EE_APPLE_PLATFORM AppleTVOS)
    if(CMAKE_OSX_SYSROOT MATCHES "[Ss]imulator")
        set(EE_APPLE_PLATFORM AppleTVSimulator)
    endif()
else()
    set(EE_APPLE_DEVICE_FAMILY 2)
    set(EE_APPLE_PLATFORM iPhoneOS)
    if(CMAKE_OSX_SYSROOT MATCHES "[Ss]imulator")
        set(EE_APPLE_PLATFORM iPhoneSimulator)
    endif()
endif()

target_sources(EmptyEpsilon PRIVATE apple/mobile.cpp)
target_include_directories(EmptyEpsilon PRIVATE apple)
target_link_libraries(EmptyEpsilon PRIVATE "-framework UIKit" "-framework Foundation")
set_target_properties(EmptyEpsilon PROPERTIES
    MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/apple/Info.plist.in"
    MACOSX_BUNDLE_GUI_IDENTIFIER "${EE_APPLE_BUNDLE_ID}"
    MACOSX_BUNDLE_BUNDLE_NAME "Empty Epsilon"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    MACOSX_BUNDLE_BUNDLE_VERSION "${PROJECT_VERSION}"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${EE_APPLE_BUNDLE_ID}"
    XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "${EE_APPLE_DEVICE_FAMILY}"
    XCODE_ATTRIBUTE_CODE_SIGN_STYLE Automatic
    XCODE_ATTRIBUTE_ENABLE_BITCODE NO)
if(EE_APPLE_MULTICAST)
    set_target_properties(EmptyEpsilon PROPERTIES
        XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_CURRENT_SOURCE_DIR}/apple/EmptyEpsilon.entitlements")
endif()

# A root-level "resources" directory makes CoreFoundation misidentify this as a
# desktop bundle, so keep the providers' directory layout underneath "data".
add_custom_command(TARGET EmptyEpsilon POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/resources" "$<TARGET_BUNDLE_DIR:EmptyEpsilon>/data/resources"
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/scripts" "$<TARGET_BUNDLE_DIR:EmptyEpsilon>/data/scripts"
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/packs" "$<TARGET_BUNDLE_DIR:EmptyEpsilon>/data/packs"
    VERBATIM)

if(BUILD_TESTING)
    find_package(Python3 COMPONENTS Interpreter REQUIRED)
    add_test(NAME apple_bundle COMMAND ${Python3_EXECUTABLE}
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/appleBundle.py"
        "$<TARGET_BUNDLE_DIR:EmptyEpsilon>" "${EE_APPLE_PLATFORM}")
endif()
