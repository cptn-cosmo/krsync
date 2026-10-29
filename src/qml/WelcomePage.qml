// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.krsync

Kirigami.Page {
    id: page

    signal newSessionRequested
    signal importRequested
    signal importGrsyncRequested

    title: i18nc("@title", "Welcome")

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - Kirigami.Units.gridUnit * 2, Kirigami.Units.gridUnit * 26)
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Kirigami.Units.iconSizes.enormous
            implicitHeight: Kirigami.Units.iconSizes.enormous
            source: "org.kde.krsync"
            fallback: "folder-sync"
        }

        Kirigami.Heading {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: i18nc("@title", "Welcome to KRsync")
        }

        QQC2.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            opacity: 0.8
            text: i18n("Keep folders in sync between disks, computers and servers. Create a session for each pair of folders you want to keep identical, then synchronize them with one click.")
        }

        Item {
            implicitHeight: Kirigami.Units.largeSpacing
        }

        QQC2.Button {
            Layout.alignment: Qt.AlignHCenter
            icon.name: "list-add"
            text: i18nc("@action:button", "Create a Session")
            highlighted: true
            onClicked: page.newSessionRequested()
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                visible: SessionManager.grsyncSessionsAvailable
                icon.name: "folder-sync"
                text: i18nc("@action:button", "Import from Grsync")
                flat: true
                onClicked: page.importGrsyncRequested()
            }

            QQC2.Button {
                icon.name: "document-import"
                text: i18nc("@action:button", "Import File…")
                flat: true
                onClicked: page.importRequested()
            }
        }
    }
}
