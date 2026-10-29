# SPDX-License-Identifier: GPL-3.0-or-later

add_executable(krsync)

qt_add_qml_module(krsync
    URI org.kde.krsync
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/Sidebar.qml
        qml/WelcomePage.qml
        qml/SessionPage.qml
        qml/PathField.qml
        qml/OptionSection.qml
        qml/RunPage.qml
        qml/ProgressRing.qml
        qml/StatTile.qml
        qml/SettingsPage.qml
        qml/NameDialog.qml
    SOURCES
        main.cpp
        options.cpp options.h
        grsyncformat.cpp grsyncformat.h
        session.cpp session.h
        sessionmanager.cpp sessionmanager.h
        logmodel.cpp logmodel.h
        rsyncrunner.cpp rsyncrunner.h
        desktopintegration.cpp desktopintegration.h
)

kconfig_add_kcfg_files(krsync GENERATE_MOC krsyncconfig.kcfgc)

target_include_directories(krsync PRIVATE ${CMAKE_CURRENT_BINARY_DIR})

target_link_libraries(krsync PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Widgets
    KF6::ConfigCore
    KF6::ConfigGui
    KF6::CoreAddons
    KF6::Crash
    KF6::DBusAddons
    KF6::I18n
    KF6::I18nQml
    KF6::IconThemes
    KF6::Notifications
)

install(TARGETS krsync ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
