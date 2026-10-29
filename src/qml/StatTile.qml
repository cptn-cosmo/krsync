// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

// A labelled figure for the progress dashboard.
ColumnLayout {
    id: tile

    required property string label
    required property string value
    property string iconName
    property color valueColor: Kirigami.Theme.textColor

    spacing: 0

    RowLayout {
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            visible: tile.iconName.length > 0
            source: tile.iconName
            implicitWidth: Kirigami.Units.iconSizes.small
            implicitHeight: Kirigami.Units.iconSizes.small
            opacity: 0.6
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: tile.label
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            elide: Text.ElideRight
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        text: tile.value
        color: tile.valueColor
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.35
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        elide: Text.ElideRight
    }
}
