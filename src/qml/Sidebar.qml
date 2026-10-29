// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.delegates as Delegates
import org.kde.coreaddons as KCoreAddons
import org.kde.krsync

Kirigami.OverlayDrawer {
    id: drawer

    property Session currentSession

    signal sessionActivated(Session session)
    signal newSessionRequested
    signal renameRequested(Session session)
    signal duplicateRequested(Session session)
    signal exportRequested(Session session)
    signal removeRequested(Session session)
    signal importRequested
    signal importGrsyncRequested
    signal settingsRequested
    signal aboutRequested
    signal showProgressRequested

    readonly property bool narrow: (applicationWindow()?.width ?? 1000) < Kirigami.Units.gridUnit * 40

    edge: Qt.application.layoutDirection === Qt.RightToLeft ? Qt.RightEdge : Qt.LeftEdge
    modal: narrow
    drawerOpen: !narrow
    handleVisible: modal
    onNarrowChanged: drawerOpen = !narrow

    width: Kirigami.Units.gridUnit * 15
    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    Kirigami.Theme.colorSet: Kirigami.Theme.View
    Kirigami.Theme.inherit: false

    contentItem: ColumnLayout {
        spacing: 0

        QQC2.ToolBar {
            Layout.fillWidth: true
            Layout.preferredHeight: applicationWindow().pageStack.globalToolBar.preferredHeight

            leftPadding: Kirigami.Units.largeSpacing
            rightPadding: Kirigami.Units.smallSpacing

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Heading {
                    Layout.fillWidth: true
                    level: 1
                    text: i18nc("@title", "Sessions")
                    elide: Text.ElideRight
                }

                QQC2.ToolButton {
                    icon.name: "list-add"
                    text: i18nc("@action:button", "New Session")
                    display: QQC2.AbstractButton.IconOnly
                    onClicked: drawer.newSessionRequested()
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }

                QQC2.ToolButton {
                    id: menuButton
                    icon.name: "open-menu-symbolic"
                    text: i18nc("@action:button", "Main Menu")
                    display: QQC2.AbstractButton.IconOnly
                    down: appMenu.visible
                    onClicked: appMenu.popup(menuButton, 0, menuButton.height)
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered && !appMenu.visible
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

                    QQC2.Menu {
                        id: appMenu
                        QQC2.MenuItem {
                            text: i18nc("@action:inmenu", "Import Sessions…")
                            icon.name: "document-import"
                            onTriggered: drawer.importRequested()
                        }
                        QQC2.MenuItem {
                            text: i18nc("@action:inmenu", "Import from Grsync")
                            icon.name: "folder-sync"
                            enabled: SessionManager.grsyncSessionsAvailable
                            onTriggered: drawer.importGrsyncRequested()
                        }
                        QQC2.MenuSeparator {}
                        QQC2.MenuItem {
                            text: i18nc("@action:inmenu", "Configure KRsync…")
                            icon.name: "configure"
                            onTriggered: drawer.settingsRequested()
                        }
                        QQC2.MenuItem {
                            text: i18nc("@action:inmenu", "About KRsync")
                            icon.name: "help-about"
                            onTriggered: drawer.aboutRequested()
                        }
                        QQC2.MenuSeparator {}
                        QQC2.MenuItem {
                            text: i18nc("@action:inmenu", "Quit")
                            icon.name: "application-exit"
                            onTriggered: Qt.quit()
                        }
                    }
                }
            }
        }

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: sessionList

                model: SessionManager
                clip: true
                topMargin: Kirigami.Units.smallSpacing
                bottomMargin: Kirigami.Units.smallSpacing
                spacing: Kirigami.Units.smallSpacing / 2
                currentIndex: SessionManager.indexOf(drawer.currentSession)
                keyNavigationEnabled: true
                activeFocusOnTab: true

                delegate: Delegates.RoundedItemDelegate {
                    id: delegate

                    required property int index
                    required property string name
                    required property Session session
                    required property string source
                    required property string destination
                    required property bool remote
                    required property var lastRun
                    required property int lastResult

                    readonly property bool running: Runner.active && Runner.session === session
                    readonly property bool hasRun: lastResult >= 0

                    width: ListView.view.width
                    text: name
                    highlighted: drawer.currentSession === session
                    onClicked: drawer.sessionActivated(session)

                    Accessible.description: subtitle.text

                    contentItem: RowLayout {
                        spacing: Kirigami.Units.largeSpacing

                        Item {
                            implicitWidth: Kirigami.Units.iconSizes.medium
                            implicitHeight: Kirigami.Units.iconSizes.medium

                            Kirigami.Icon {
                                anchors.fill: parent
                                source: delegate.remote ? "folder-cloud" : "folder-sync"
                                selected: delegate.highlighted && !Kirigami.Settings.isMobile
                            }

                            Kirigami.Icon {
                                anchors {
                                    right: parent.right
                                    bottom: parent.bottom
                                    rightMargin: -Kirigami.Units.smallSpacing / 2
                                    bottomMargin: -Kirigami.Units.smallSpacing / 2
                                }
                                width: Kirigami.Units.iconSizes.small
                                height: width
                                visible: delegate.hasRun && !delegate.running
                                source: delegate.lastResult === 0 ? "emblem-success" : "emblem-error"
                            }

                            QQC2.BusyIndicator {
                                anchors.centerIn: parent
                                width: parent.width + Kirigami.Units.smallSpacing * 2
                                height: width
                                running: delegate.running && !Runner.paused
                                visible: delegate.running
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            QQC2.Label {
                                Layout.fillWidth: true
                                text: delegate.name
                                elide: Text.ElideRight
                                color: delegate.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                            }

                            QQC2.Label {
                                id: subtitle
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font: Kirigami.Theme.smallFont
                                opacity: 0.7
                                color: delegate.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                                text: {
                                    if (delegate.running) {
                                        if (Runner.paused)
                                            return i18nc("@info:status", "Paused");
                                        return Runner.progress >= 0
                                            ? i18nc("@info:status %1 is a percentage", "Synchronizing… %1%", Math.round(Runner.progress * 100))
                                            : i18nc("@info:status", "Synchronizing…");
                                    }
                                    if (!delegate.hasRun) {
                                        const src = SessionManager.displayName(delegate.source);
                                        const dst = SessionManager.displayName(delegate.destination);
                                        if (src && dst)
                                            return i18nc("@info source → destination", "%1 → %2", src, dst);
                                        return i18nc("@info:status", "Not set up yet");
                                    }
                                    const when = KCoreAddons.Format.formatRelativeDateTime(delegate.lastRun, Locale.ShortFormat);
                                    return delegate.lastResult === 0
                                        ? i18nc("@info:status %1 is a relative date", "Synced %1", when)
                                        : i18nc("@info:status %1 is a relative date", "Failed %1", when);
                                }
                            }
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: contextMenu.popup()
                    }
                    TapHandler {
                        acceptedDevices: PointerDevice.TouchScreen
                        onLongPressed: contextMenu.popup()
                    }

                    QQC2.Menu {
                        id: contextMenu
                        QQC2.MenuItem {
                            text: i18nc("@action:inmenu", "Rename…")
                            icon.name: "edit-rename"
                            onTriggered: drawer.renameRequested(delegate.session)
                        }
                        QQC2.MenuItem {
                            text: i18nc("@action:inmenu", "Duplicate")
                            icon.name: "edit-copy"
                            onTriggered: drawer.duplicateRequested(delegate.session)
                        }
                        QQC2.MenuItem {
                            text: i18nc("@action:inmenu", "Export…")
                            icon.name: "document-export"
                            onTriggered: drawer.exportRequested(delegate.session)
                        }
                        QQC2.MenuSeparator {}
                        QQC2.MenuItem {
                            text: i18nc("@action:inmenu", "Move Up")
                            icon.name: "go-up"
                            enabled: delegate.index > 0
                            onTriggered: SessionManager.move(delegate.index, delegate.index - 1)
                        }
                        QQC2.MenuItem {
                            text: i18nc("@action:inmenu", "Move Down")
                            icon.name: "go-down"
                            enabled: delegate.index < SessionManager.count - 1
                            onTriggered: SessionManager.move(delegate.index, delegate.index + 1)
                        }
                        QQC2.MenuSeparator {}
                        QQC2.MenuItem {
                            text: i18nc("@action:inmenu", "Delete…")
                            icon.name: "edit-delete"
                            enabled: !delegate.running
                            onTriggered: drawer.removeRequested(delegate.session)
                        }
                    }
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 2
                    visible: sessionList.count === 0
                    icon.name: "folder-sync"
                    text: i18nc("@info:placeholder", "No sessions")
                    helpfulAction: Kirigami.Action {
                        text: i18nc("@action:button", "New Session")
                        icon.name: "list-add"
                        onTriggered: drawer.newSessionRequested()
                    }
                }
            }
        }

        // Live status of the running sync, reachable from any session.
        Kirigami.Separator {
            Layout.fillWidth: true
            visible: activityCard.visible
        }

        QQC2.ItemDelegate {
            id: activityCard

            Layout.fillWidth: true
            visible: Runner.active
            padding: Kirigami.Units.largeSpacing
            onClicked: drawer.showProgressRequested()

            contentItem: ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing
                    Kirigami.Icon {
                        source: Runner.paused ? "media-playback-pause" : (Runner.simulation ? "view-preview" : "folder-sync")
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.weight: Font.DemiBold
                        text: Runner.session ? Runner.session.name : ""
                    }
                    QQC2.Label {
                        visible: Runner.progress >= 0
                        text: i18nc("@info percentage", "%1%", Math.round(Runner.progress * 100))
                        font: Kirigami.Theme.smallFont
                    }
                }

                QQC2.ProgressBar {
                    Layout.fillWidth: true
                    from: 0
                    to: 1
                    value: Math.max(0, Runner.progress)
                    indeterminate: Runner.progress < 0 && !Runner.paused
                }
            }
        }
    }
}
