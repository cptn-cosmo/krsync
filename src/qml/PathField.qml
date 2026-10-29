// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.krsync

// One end of a sync: a big glanceable folder plus an editable path.
// Accepts folders dragged in from Dolphin or the desktop.
Rectangle {
    id: field

    required property string label
    required property string path
    property string placeholder

    signal pathEdited(string path)

    readonly property bool remote: SessionManager.isRemotePath(path)
    readonly property string iconName: {
        if (path.length === 0)
            return "folder-new";
        if (remote)
            return "folder-cloud";
        if (path.startsWith("/run/media/") || path.startsWith("/media/") || path.startsWith("/mnt/"))
            return "drive-removable-media";
        const trimmed = path.replace(/\/+$/, "");
        if (trimmed === "~" || SessionManager.prettyPath(trimmed) === "~")
            return "user-home";
        return SessionManager.isDirectory(path) || path.endsWith("/") ? "folder" : "text-x-generic";
    }

    implicitWidth: layout.implicitWidth + Kirigami.Units.largeSpacing * 2
    implicitHeight: layout.implicitHeight + Kirigami.Units.largeSpacing * 2

    radius: Kirigami.Units.cornerRadius
    color: dropArea.containsDrag ? Qt.alpha(Kirigami.Theme.highlightColor, 0.15) : "transparent"
    border.width: dropArea.containsDrag ? 2 : 0
    border.color: Kirigami.Theme.highlightColor

    Behavior on color {
        ColorAnimation {
            duration: Kirigami.Units.shortDuration
        }
    }

    function setPath(newPath: string) {
        field.pathEdited(newPath);
    }

    ColumnLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Kirigami.Units.iconSizes.huge
            implicitHeight: Kirigami.Units.iconSizes.huge
            source: field.iconName
            opacity: field.path.length === 0 ? 0.5 : 1
            animated: true

            Behavior on opacity {
                NumberAnimation {
                    duration: Kirigami.Units.longDuration
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: field.label.toUpperCase()
            font.weight: Font.DemiBold
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.letterSpacing: 1
            opacity: 0.6
        }

        Kirigami.Heading {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            level: 3
            elide: Text.ElideMiddle
            text: SessionManager.displayName(field.path) || i18nc("@info:placeholder", "Not chosen")
            opacity: field.path.length === 0 ? 0.5 : 1
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            QQC2.TextField {
                id: textField

                Layout.fillWidth: true
                text: field.path
                placeholderText: field.placeholder
                font.family: Kirigami.Theme.fixedWidthFont.family
                inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                Accessible.name: field.label
                onTextEdited: field.pathEdited(text)
            }

            QQC2.Button {
                id: browseButton
                icon.name: "document-open-folder"
                text: i18nc("@action:button", "Browse…")
                display: QQC2.AbstractButton.IconOnly
                down: browseMenu.visible
                onClicked: browseMenu.popup(browseButton, 0, browseButton.height)
                QQC2.ToolTip.text: i18nc("@info:tooltip", "Choose a folder or file")
                QQC2.ToolTip.visible: hovered && !browseMenu.visible
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

                QQC2.Menu {
                    id: browseMenu
                    QQC2.MenuItem {
                        text: i18nc("@action:inmenu", "Choose Folder…")
                        icon.name: "folder"
                        onTriggered: folderDialog.open()
                    }
                    QQC2.MenuItem {
                        text: i18nc("@action:inmenu", "Choose File…")
                        icon.name: "text-x-generic"
                        onTriggered: fileDialog.open()
                    }
                }
            }
        }
    }

    DropArea {
        id: dropArea
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: drop => {
            if (drop.hasUrls && drop.urls.length > 0) {
                field.setPath(SessionManager.urlToPath(drop.urls[0]));
                drop.acceptProposedAction();
            }
        }
    }

    FolderDialog {
        id: folderDialog
        title: i18nc("@title:dialog %1 is Source or Destination", "Choose %1 Folder", field.label)
        currentFolder: SessionManager.pathToUrl(field.path)
        onAccepted: field.setPath(SessionManager.urlToPath(selectedFolder) + (field.path.endsWith("/") ? "/" : ""))
    }

    FileDialog {
        id: fileDialog
        title: i18nc("@title:dialog %1 is Source or Destination", "Choose %1 File", field.label)
        fileMode: FileDialog.OpenFile
        onAccepted: field.setPath(SessionManager.urlToPath(selectedFile))
    }
}
