# SPDX-License-Identifier: GPL-3.0-or-later

cmake_minimum_required(VERSION 3.22)

project(krsync VERSION 0.1.0 LANGUAGES CXX)

set(QT_MIN_VERSION "6.6.0")
set(KF_MIN_VERSION "6.8.0")

find_package(ECM ${KF_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMSetupVersion)
include(ECMInstallIcons)
include(FeatureSummary)

ecm_setup_version(${PROJECT_VERSION}
    VARIABLE_PREFIX KRSYNC
    VERSION_HEADER "${CMAKE_CURRENT_BINARY_DIR}/src/krsync-version.h"
)

find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS
    Core
    DBus
    Gui
    Qml
    Quick
    QuickControls2
    Widgets
)

find_package(KF6 ${KF_MIN_VERSION} REQUIRED COMPONENTS
    Config
    CoreAddons
    Crash
    DBusAddons
    I18n
    IconThemes
    Kirigami
    Notifications
)

find_package(KF6KirigamiAddons 1.4.0 REQUIRED)
set_package_properties(KF6KirigamiAddons PROPERTIES
    TYPE RUNTIME
    PURPOSE "Provides FormCard and delegate components used throughout the UI"
)

qt_policy(SET QTP0001 NEW)

add_subdirectory(src)

install(PROGRAMS org.kde.krsync.desktop DESTINATION ${KDE_INSTALL_APPDIR})
install(FILES org.kde.krsync.metainfo.xml DESTINATION ${KDE_INSTALL_METAINFODIR})
install(FILES krsync.notifyrc DESTINATION ${KDE_INSTALL_KNOTIFYRCDIR})
ecm_install_icons(ICONS icons/sc-apps-org.kde.krsync.svg DESTINATION ${KDE_INSTALL_ICONDIR} THEME hicolor)

feature_summary(WHAT ALL INCLUDE_QUIET_PACKAGES FATAL_ON_MISSING_REQUIRED_PACKAGES)
