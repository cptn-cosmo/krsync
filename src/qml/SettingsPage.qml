// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard
import org.kde.krsync
import org.kde.krsync.config

FormCard.FormCardPage {
    id: page

    title: i18nc("@title", "Settings")

    FormCard.FormHeader {
        title: i18nc("@title:group", "Synchronizing")
    }

    FormCard.FormCard {
        FormCard.FormSwitchDelegate {
            icon.name: "dialog-warning"
            text: i18nc("@option:check", "Confirm before deleting files")
            description: i18n("Ask before running a session that removes files from the destination.")
            checked: Config.confirmDelete
            onToggled: Config.confirmDelete = checked
        }
        FormCard.FormDelegateSeparator {}
        FormCard.FormSwitchDelegate {
            icon.name: "system-suspend-inhibited"
            text: i18nc("@option:check", "Keep the computer awake")
            description: i18n("Prevent sleep while a synchronization is running.")
            checked: Config.inhibitSleep
            onToggled: Config.inhibitSleep = checked
        }
        FormCard.FormDelegateSeparator {}
        FormCard.FormSwitchDelegate {
            icon.name: "view-statistics"
            text: i18nc("@option:check", "Accurate progress")
            description: i18n("Scan the whole source before transferring. Progress is exact, but large trees take longer to start.")
            checked: Config.accurateProgress
            onToggled: Config.accurateProgress = checked
        }
    }

    FormCard.FormHeader {
        title: i18nc("@title:group", "Interface")
    }

    FormCard.FormCard {
        FormCard.FormSwitchDelegate {
            icon.name: "notifications"
            text: i18nc("@option:check", "Notify when finished")
            description: i18n("Show a notification when a synchronization ends while KRsync is in the background.")
            checked: Config.notifyWhenDone
            onToggled: Config.notifyWhenDone = checked
        }
        FormCard.FormDelegateSeparator {}
        FormCard.FormSwitchDelegate {
            icon.name: "utilities-terminal"
            text: i18nc("@option:check", "Show the rsync command")
            description: i18n("Display the generated command line at the bottom of each session.")
            checked: Config.showCommandPreview
            onToggled: Config.showCommandPreview = checked
        }
    }

    FormCard.FormHeader {
        title: i18nc("@title:group", "rsync")
    }

    FormCard.FormCard {
        FormCard.FormTextFieldDelegate {
            label: i18nc("@label:textbox", "rsync program")
            text: Config.rsyncPath
            placeholderText: "rsync"
            onEditingFinished: Config.rsyncPath = text.trim().length > 0 ? text.trim() : "rsync"
        }
        FormCard.FormButtonDelegate {
            icon.name: "document-open"
            text: i18nc("@action:button", "Choose Program…")
            onClicked: programDialog.open()
        }
    }

    Component.onDestruction: Config.save()

    FileDialog {
        id: programDialog
        title: i18nc("@title:dialog", "Choose rsync Program")
        fileMode: FileDialog.OpenFile
        onAccepted: Config.rsyncPath = SessionManager.urlToPath(selectedFile)
    }
}
