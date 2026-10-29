// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// A titled FormCard that folds away, with a summary of what it holds when folded.
ColumnLayout {
    id: section

    required property string title
    property string summary
    property bool expanded: true
    default property alias delegates: card.delegates

    Layout.fillWidth: true
    spacing: 0

    FormCard.FormHeader {
        id: header
        title: section.title
        maximumWidth: card.maximumWidth
        trailing: QQC2.ToolButton {
            text: section.expanded ? i18nc("@action:button", "Collapse") : i18nc("@action:button", "Expand")
            icon.name: section.expanded ? "collapse" : "expand"
            display: QQC2.AbstractButton.IconOnly
            onClicked: section.expanded = !section.expanded
            Layout.rightMargin: Kirigami.Units.smallSpacing
        }

        TapHandler {
            onTapped: section.expanded = !section.expanded
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        Layout.maximumWidth: card.maximumWidth
        Layout.alignment: Qt.AlignHCenter
        Layout.leftMargin: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing + Kirigami.Units.smallSpacing
        visible: !section.expanded && section.summary.length > 0
        text: section.summary
        elide: Text.ElideRight
        font: Kirigami.Theme.smallFont
        opacity: 0.7
    }

    FormCard.FormCard {
        id: card
        maximumWidth: Kirigami.Units.gridUnit * 36
        visible: section.expanded
    }
}
