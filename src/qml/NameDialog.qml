// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: dialog

    property alias text: nameField.text
    property string acceptText

    signal confirmed

    preferredWidth: Kirigami.Units.gridUnit * 20
    padding: Kirigami.Units.largeSpacing
    standardButtons: Kirigami.Dialog.NoButton

    function confirm() {
        if (nameField.text.trim().length === 0)
            return;
        dialog.confirmed();
        dialog.close();
    }

    onOpened: {
        nameField.forceActiveFocus();
        nameField.selectAll();
    }

    customFooterActions: [
        Kirigami.Action {
            text: dialog.acceptText
            icon.name: "dialog-ok"
            enabled: nameField.text.trim().length > 0
            onTriggered: dialog.confirm()
        },
        Kirigami.Action {
            text: i18nc("@action:button", "Cancel")
            icon.name: "dialog-cancel"
            onTriggered: dialog.close()
        }
    ]

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        QQC2.Label {
            text: i18nc("@label:textbox", "Name:")
        }

        QQC2.TextField {
            id: nameField
            Layout.fillWidth: true
            placeholderText: i18nc("@info:placeholder", "Photos to external drive")
            onAccepted: dialog.confirm()
        }
    }
}
