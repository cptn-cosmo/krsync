// SPDX-License-Identifier: GPL-3.0-or-later

import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.krsync

Kirigami.Page {
    id: page

    signal runAgainRequested(bool simulate)

    readonly property bool active: Runner.active
    readonly property bool done: Runner.finished
    readonly property bool succeeded: Runner.state === Runner.Succeeded
    readonly property bool failed: Runner.state === Runner.Failed
    readonly property string sessionName: Runner.session ? Runner.session.name : ""

    readonly property color stateColor: {
        if (succeeded)
            return Runner.exitCode === 24 || Runner.errorCount > 0 ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.positiveTextColor;
        if (failed)
            return Kirigami.Theme.negativeTextColor;
        if (Runner.state === Runner.Cancelled || Runner.paused)
            return Kirigami.Theme.neutralTextColor;
        return Kirigami.Theme.highlightColor;
    }

    title: Runner.simulation ? i18nc("@title %1 is a session name", "Simulating “%1”", sessionName) : i18nc("@title %1 is a session name", "Synchronizing “%1”", sessionName)

    padding: 0
    Kirigami.Theme.colorSet: Kirigami.Theme.Window

    actions: [
        Kirigami.Action {
            visible: page.active
            enabled: Runner.canPause
            text: Runner.paused ? i18nc("@action:intoolbar", "Resume") : i18nc("@action:intoolbar", "Pause")
            icon.name: Runner.paused ? "media-playback-start" : "media-playback-pause"
            onTriggered: Runner.paused ? Runner.resume() : Runner.pause()
        },
        Kirigami.Action {
            visible: page.active
            text: i18nc("@action:intoolbar", "Cancel")
            icon.name: "dialog-cancel"
            shortcut: "Escape"
            onTriggered: Runner.cancel()
        },
        Kirigami.Action {
            visible: page.done && Runner.simulation && page.succeeded
            text: i18nc("@action:intoolbar", "Synchronize Now")
            icon.name: "folder-sync"
            onTriggered: page.runAgainRequested(false)
        },
        Kirigami.Action {
            visible: page.done && !(Runner.simulation && page.succeeded)
            text: Runner.simulation ? i18nc("@action:intoolbar", "Simulate Again") : i18nc("@action:intoolbar", "Run Again")
            icon.name: "view-refresh"
            onTriggered: page.runAgainRequested(Runner.simulation)
        },
        Kirigami.Action {
            text: i18nc("@action:intoolbar", "Save Log…")
            icon.name: "document-save"
            displayHint: Kirigami.DisplayHint.AlwaysHide
            onTriggered: saveDialog.open()
        },
        Kirigami.Action {
            visible: page.done
            text: i18nc("@action:intoolbar", "Done")
            icon.name: "dialog-ok"
            onTriggered: {
                Runner.dismiss();
                applicationWindow().pageStack.layers.pop();
            }
        }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Dashboard ────────────────────────────────────────────────

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: dashboard.implicitHeight + Kirigami.Units.gridUnit * 2
            Kirigami.Theme.colorSet: Kirigami.Theme.View
            Kirigami.Theme.inherit: false
            color: Kirigami.Theme.backgroundColor

            // A soft wash of the state colour behind the ring.
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.alpha(page.stateColor, 0.10) }
                    GradientStop { position: 0.6; color: "transparent" }
                }
                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
            }

            GridLayout {
                id: dashboard

                readonly property bool wide: width > Kirigami.Units.gridUnit * 30

                anchors {
                    left: parent.left
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    margins: Kirigami.Units.gridUnit
                }
                columns: wide ? 2 : 1
                columnSpacing: Kirigami.Units.gridUnit * 1.5
                rowSpacing: Kirigami.Units.largeSpacing

                ProgressRing {
                    id: ring
                    Layout.alignment: Qt.AlignCenter
                    implicitWidth: Kirigami.Units.gridUnit * (dashboard.wide ? 9 : 7)
                    value: page.done && page.succeeded ? 1 : Math.max(0, Runner.progress)
                    indeterminate: page.active && Runner.progress < 0 && !Runner.paused
                    color: page.stateColor

                    QQC2.Label {
                        anchors.centerIn: parent
                        visible: !page.done
                        text: Runner.progress >= 0 ? i18nc("@info percentage", "%1%", Math.floor(Runner.progress * 100)) : ""
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * (dashboard.wide ? 2.2 : 1.8)
                        font.weight: Font.Light
                        font.features: { "tnum": 1 }
                    }

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        visible: page.done || Runner.paused
                        implicitWidth: Kirigami.Units.iconSizes.large
                        implicitHeight: Kirigami.Units.iconSizes.large
                        source: Runner.paused ? "media-playback-pause"
                              : page.succeeded ? (Runner.exitCode === 24 ? "dialog-warning" : "dialog-ok-apply")
                              : page.failed ? "dialog-error" : "dialog-cancel"
                        color: page.stateColor
                        isMask: true

                        scale: visible ? 1 : 0.5
                        Behavior on scale { NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.OutBack } }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Heading {
                            Layout.fillWidth: true
                            level: 2
                            wrapMode: Text.WordWrap
                            horizontalAlignment: dashboard.wide ? Text.AlignLeft : Text.AlignHCenter
                            text: {
                                if (page.done)
                                    return Runner.resultTitle;
                                if (Runner.paused)
                                    return i18nc("@info:status", "Paused");
                                switch (Runner.state) {
                                case Runner.PreCommand:
                                    return i18nc("@info:status", "Running command before synchronizing…");
                                case Runner.PostCommand:
                                    return i18nc("@info:status", "Running command after synchronizing…");
                                default:
                                    if (Runner.progress < 0)
                                        return i18nc("@info:status", "Comparing files…");
                                    return Runner.simulation ? i18nc("@info:status", "Simulating…") : i18nc("@info:status", "Transferring…");
                                }
                            }
                        }

                        QQC2.Label {
                            Layout.fillWidth: true
                            horizontalAlignment: dashboard.wide ? Text.AlignLeft : Text.AlignHCenter
                            visible: text.length > 0
                            wrapMode: page.done ? Text.WordWrap : Text.NoWrap
                            elide: page.done ? Text.ElideNone : Text.ElideMiddle
                            font.family: page.done ? Kirigami.Theme.defaultFont.family : Kirigami.Theme.fixedWidthFont.family
                            opacity: 0.75
                            text: page.done ? Runner.resultMessage : Runner.currentFile
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: dashboard.wide ? 3 : 2
                        columnSpacing: Kirigami.Units.gridUnit
                        rowSpacing: Kirigami.Units.largeSpacing

                        StatTile {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            iconName: "transfer-down"
                            label: Runner.simulation ? i18nc("@label", "Would transfer") : i18nc("@label", "Transferred")
                            value: KCoreAddons.Format.formatByteSize(page.done && Runner.stats.transferredSize !== undefined ? Runner.stats.transferredSize : Runner.bytesTransferred)
                        }
                        StatTile {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            iconName: "speedometer"
                            label: page.done ? i18nc("@label", "Average speed") : i18nc("@label", "Speed")
                            value: {
                                const speed = page.done ? (Runner.stats.rate ?? 0) : Runner.speed;
                                return speed > 0 ? i18nc("@info bytes per second", "%1/s", KCoreAddons.Format.formatByteSize(speed)) : "—";
                            }
                        }
                        StatTile {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            iconName: "chronometer"
                            label: page.active && Runner.eta >= 0 ? i18nc("@label", "Time left") : i18nc("@label", "Elapsed")
                            value: KCoreAddons.Format.formatDuration((page.active && Runner.eta >= 0 ? Runner.eta : Runner.elapsed) * 1000)
                        }
                        StatTile {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            iconName: "document-multiple"
                            label: Runner.simulation ? i18nc("@label", "Files to update") : i18nc("@label", "Files updated")
                            value: {
                                const n = page.done && Runner.stats.transferredFiles !== undefined ? Runner.stats.transferredFiles : Runner.filesTransferred;
                                return Runner.filesTotal > 0 && !page.done
                                    ? i18nc("@info %1 of %2 files", "%1 of %2", n.toLocaleString(Qt.locale(), "f", 0), Runner.filesTotal.toLocaleString(Qt.locale(), "f", 0))
                                    : n.toLocaleString(Qt.locale(), "f", 0);
                            }
                        }
                        StatTile {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            iconName: "edit-delete"
                            label: Runner.simulation ? i18nc("@label", "To delete") : i18nc("@label", "Deleted")
                            value: Runner.deletedCount.toLocaleString(Qt.locale(), "f", 0)
                            valueColor: Runner.deletedCount > 0 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                        }
                        StatTile {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            iconName: "data-error"
                            label: i18nc("@label", "Errors")
                            value: Runner.errorCount.toLocaleString(Qt.locale(), "f", 0)
                            valueColor: Runner.errorCount > 0 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                        }
                    }
                }
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            position: Kirigami.InlineMessage.Position.Header
            visible: page.done && Runner.simulation && page.succeeded
            type: Kirigami.MessageType.Positive
            icon.name: "view-preview"
            text: Runner.deletedCount > 0
                ? i18np("Nothing was changed. A real run would also delete one file; review it in the log below.",
                        "Nothing was changed. A real run would also delete %1 files; review them in the log below.", Runner.deletedCount)
                : i18n("Nothing was changed. Review the list below, then synchronize when ready.")
            actions: Kirigami.Action {
                text: i18nc("@action:button", "Synchronize Now")
                icon.name: "folder-sync"
                onTriggered: page.runAgainRequested(false)
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        // ── Log ──────────────────────────────────────────────────────

        QQC2.ToolBar {
            Layout.fillWidth: true
            position: QQC2.ToolBar.Header

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC2.TabBar {
                    id: tabs
                    QQC2.TabButton {
                        text: i18nc("@title:tab", "Everything")
                        width: implicitWidth
                    }
                    QQC2.TabButton {
                        text: i18nc("@title:tab", "Changes")
                        width: implicitWidth
                    }
                    QQC2.TabButton {
                        text: Runner.errorCount > 0 ? i18nc("@title:tab %1 is a count", "Errors (%1)", Runner.errorCount) : i18nc("@title:tab", "Errors")
                        width: implicitWidth
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Kirigami.SearchField {
                    id: search
                    Layout.maximumWidth: Kirigami.Units.gridUnit * 14
                    Layout.fillWidth: true
                    placeholderText: i18nc("@info:placeholder", "Filter log…")
                    onAccepted: filtered.searchText = text
                }
            }
        }

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Kirigami.Theme.colorSet: Kirigami.Theme.View
            Kirigami.Theme.inherit: false

            background: Rectangle {
                color: Kirigami.Theme.backgroundColor
            }

            ListView {
                id: logView

                property bool follow: true

                clip: true
                reuseItems: true
                boundsBehavior: Flickable.StopAtBounds
                topMargin: Kirigami.Units.smallSpacing
                bottomMargin: Kirigami.Units.smallSpacing

                model: LogFilterModel {
                    id: filtered
                    sourceModel: Runner.log
                    filter: tabs.currentIndex
                }

                onCountChanged: if (follow) Qt.callLater(positionViewAtEnd)
                onMovementEnded: follow = atYEnd
                onFlickEnded: follow = atYEnd

                delegate: RowLayout {
                    id: entry

                    required property int kind
                    required property string text

                    readonly property color tint: {
                        switch (kind) {
                        case LogModel.Error:
                            return Kirigami.Theme.negativeTextColor;
                        case LogModel.Deletion:
                            return Kirigami.Theme.negativeTextColor;
                        case LogModel.Command:
                            return Kirigami.Theme.linkColor;
                        default:
                            return Kirigami.Theme.textColor;
                        }
                    }

                    width: ListView.view.width
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        Layout.leftMargin: Kirigami.Units.largeSpacing
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: Kirigami.Units.iconSizes.small
                        source: {
                            switch (entry.kind) {
                            case LogModel.Command:
                                return "utilities-terminal";
                            case LogModel.Transfer:
                                return "document-new";
                            case LogModel.Directory:
                                return "folder";
                            case LogModel.Deletion:
                                return "edit-delete";
                            case LogModel.Error:
                                return "dialog-error";
                            default:
                                return "documentinfo";
                            }
                        }
                        opacity: entry.kind === LogModel.Info ? 0.5 : 1
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        Layout.rightMargin: Kirigami.Units.largeSpacing
                        text: entry.kind === LogModel.Command ? "$ " + entry.text : entry.text
                        color: entry.tint
                        opacity: entry.kind === LogModel.Info ? 0.7 : 1
                        font.family: Kirigami.Theme.fixedWidthFont.family
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        wrapMode: entry.kind === LogModel.Error || entry.kind === LogModel.Command ? Text.WrapAnywhere : Text.NoWrap
                        elide: Text.ElideMiddle
                        textFormat: Text.PlainText
                        topPadding: 1
                        bottomPadding: 1
                    }
                }

                Kirigami.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 4
                    visible: logView.count === 0
                    icon.name: tabs.currentIndex === 2 ? "data-success" : "view-list-text"
                    text: tabs.currentIndex === 2 ? i18nc("@info:placeholder", "No errors")
                        : tabs.currentIndex === 1 ? (page.done ? i18nc("@info:placeholder", "Everything was already up to date") : i18nc("@info:placeholder", "No changes yet"))
                        : i18nc("@info:placeholder", "Waiting for rsync…")
                }
            }
        }

        QQC2.Button {
            id: jumpButton
            visible: !logView.follow && page.active
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            Layout.topMargin: -height - Kirigami.Units.largeSpacing
            z: 1
            icon.name: "go-bottom"
            text: i18nc("@action:button", "Follow Output")
            onClicked: {
                logView.follow = true;
                logView.positionViewAtEnd();
            }
        }
    }

    FileDialog {
        id: saveDialog
        title: i18nc("@title:dialog", "Save Log")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "log"
        currentFolder: StandardPaths.writableLocation(StandardPaths.DocumentsLocation)
        nameFilters: [i18n("Log files (*.log *.txt)")]
        onAccepted: {
            if (!Runner.saveLog(selectedFile))
                applicationWindow().showPassiveNotification(i18n("The log could not be saved"));
        }
    }
}
