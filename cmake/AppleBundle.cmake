set(EE_APPLE_BUNDLE_ID "sh.mgp.emptyepsilon" CACHE STRING "Apple application bundle identifier")
set(EE_APPLE_BUILD_NUMBER "1" CACHE STRING "Apple build number (CFBundleVersion)")
if(NOT EE_APPLE_BUILD_NUMBER MATCHES "^[1-9][0-9]?[0-9]?[0-9]?(\\.[0-9][0-9]?)?(\\.[0-9][0-9]?)?$")
    message(FATAL_ERROR "EE_APPLE_BUILD_NUMBER must have up to three numeric components (9999.99.99 maximum)")
endif()
option(EE_APPLE_MULTICAST "Sign with Apple's approved multicast entitlement" OFF)
if(EE_APPLE_TESTFLIGHT)
    set(EE_APPLE_PLATFORM MacOSX)
elseif(CMAKE_SYSTEM_NAME STREQUAL "tvOS")
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

if(EE_APPLE_MOBILE)
    target_sources(EmptyEpsilon PRIVATE apple/mobile.cpp)
    target_include_directories(EmptyEpsilon PRIVATE apple)
    target_link_libraries(EmptyEpsilon PRIVATE "-framework UIKit" "-framework Foundation")
    set_target_properties(EmptyEpsilon PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/apple/Info.plist.in"
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "${EE_APPLE_DEVICE_FAMILY}")
else()
    set_target_properties(EmptyEpsilon PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/apple/MacInfo.plist.in"
        XCODE_ATTRIBUTE_ENABLE_APP_SANDBOX YES
        XCODE_ATTRIBUTE_ENABLE_HARDENED_RUNTIME YES
        XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_CURRENT_SOURCE_DIR}/apple/Mac.entitlements")
endif()
set_target_properties(EmptyEpsilon PROPERTIES
    MACOSX_BUNDLE_GUI_IDENTIFIER "${EE_APPLE_BUNDLE_ID}"
    MACOSX_BUNDLE_BUNDLE_NAME "Empty Epsilon"
    MACOSX_BUNDLE_SHORT_VERSION_STRING "${PROJECT_VERSION}"
    MACOSX_BUNDLE_BUNDLE_VERSION "${EE_APPLE_BUILD_NUMBER}"
    XCODE_GENERATE_SCHEME TRUE
    XCODE_ATTRIBUTE_SKIP_INSTALL NO
    XCODE_ATTRIBUTE_INSTALL_PATH "$(LOCAL_APPS_DIR)"
    XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT "dwarf-with-dsym"
    # Xcode collects archive symbols here, outside CMake's custom build directory.
    XCODE_ATTRIBUTE_DWARF_DSYM_FOLDER_PATH "$(SYMROOT)/$(CONFIGURATION)$(EFFECTIVE_PLATFORM_NAME)"
    XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER "${EE_APPLE_BUNDLE_ID}"
    XCODE_ATTRIBUTE_CODE_SIGN_STYLE Automatic
    XCODE_ATTRIBUTE_ENABLE_BITCODE NO)

if(CMAKE_GENERATOR STREQUAL "Xcode")
    set(apple_assets "${CMAKE_CURRENT_BINARY_DIR}/AppleAssets.xcassets")
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        apple/generate-assets.swift resources/logo_icon.png resources/logo_full.png)
    execute_process(COMMAND xcrun swift -module-cache-path "${CMAKE_CURRENT_BINARY_DIR}/SwiftModuleCache"
        "${CMAKE_CURRENT_SOURCE_DIR}/apple/generate-assets.swift"
        "${CMAKE_CURRENT_SOURCE_DIR}/resources" "${apple_assets}" "${CMAKE_SYSTEM_NAME}"
        COMMAND_ERROR_IS_FATAL ANY)
    target_sources(EmptyEpsilon PRIVATE "${apple_assets}")
    set_source_files_properties("${apple_assets}" PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    set_target_properties(EmptyEpsilon PROPERTIES XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME AppIcon)
endif()
if(EE_APPLE_MOBILE AND EE_APPLE_MULTICAST)
    set_target_properties(EmptyEpsilon PROPERTIES
        XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS "${CMAKE_CURRENT_SOURCE_DIR}/apple/EmptyEpsilon.entitlements")
endif()

if(EE_APPLE_TESTFLIGHT)
    set(apple_resources "$<TARGET_BUNDLE_DIR:EmptyEpsilon>/Contents/Resources")
    set(apple_privacy MacPrivacyInfo.xcprivacy)
    set(apple_privacy_dir "${apple_resources}")
else()
    # A root-level "resources" directory makes CoreFoundation misidentify this as
    # a desktop bundle, so keep the mobile providers underneath "data".
    set(apple_resources "$<TARGET_BUNDLE_DIR:EmptyEpsilon>/data")
    set(apple_privacy PrivacyInfo.xcprivacy)
    set(apple_privacy_dir "$<TARGET_BUNDLE_DIR:EmptyEpsilon>")
endif()
add_custom_command(TARGET EmptyEpsilon POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different "${CMAKE_CURRENT_SOURCE_DIR}/apple/${apple_privacy}" "${apple_privacy_dir}/PrivacyInfo.xcprivacy"
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/resources" "${apple_resources}/resources"
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/scripts" "${apple_resources}/scripts"
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/packs" "${apple_resources}/packs"
    VERBATIM)

if(BUILD_TESTING)
    if(EE_APPLE_TESTFLIGHT)
        # Build the desktop tests with the archive, reusing its compiled libraries.
        add_dependencies(EmptyEpsilon camera_state_test progress_slider_test)
    endif()
    find_package(Python3 COMPONENTS Interpreter REQUIRED)
    add_test(NAME apple_bundle COMMAND ${Python3_EXECUTABLE}
        "${CMAKE_CURRENT_SOURCE_DIR}/tests/appleBundle.py"
        "$<TARGET_BUNDLE_DIR:EmptyEpsilon>" "${EE_APPLE_PLATFORM}" "${CMAKE_GENERATOR}")
endif()
