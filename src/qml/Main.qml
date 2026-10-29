// SPDX-License-Identifier: GPL-3.0-or-later

import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard
import org.kde.coreaddons as KCoreAddons
import org.kde.krsync
import org.kde.krsync.config

Kirigami.ApplicationWindow {
    id: root

    property Session currentSession: null

    title: currentSession ? i18nc("@title:window %1 is a session name", "%1 — KRsync", currentSession.name) : i18n("KRsync")

    width: Kirigami.Units.gridUnit * 60
    height: Kirigami.Units.gridUnit * 42
    minimumWidth: Kirigami.Units.gridUnit * 22
    minimumHeight: Kirigami.Units.gridUnit * 26

    pageStack.globalToolBar.style: Kirigami.ApplicationHeaderStyle.ToolBar
    pageStack.globalToolBar.showNavigationButtons: Kirigami.ApplicationHeaderStyle.ShowBackButton
    pageStack.columnView.columnResizeMode: Kirigami.ColumnView.SingleColumn

    globalDrawer: Sidebar {
        id: sidebar
        currentSession: root.currentSession
        onSessionActivated: session => root.selectSession(session)
        onNewSessionRequested: root.newSession()
        onRenameRequested: session => root.renameSession(session)
        onDuplicateRequested: session => root.selectSession(SessionManager.duplicate(session))
        onExportRequested: session => root.exportSession(session)
        onRemoveRequested: session => root.removeSession(session)
        onImportRequested: importDialog.open()
        onImportGrsyncRequested: root.importGrsync()
        onSettingsRequested: root.openSettings()
        onAboutRequested: root.openAbout()
        onShowProgressRequested: root.showRunPage()
    }

    Component.onCompleted: {
        const last = SessionManager.findById(Config.lastSession);
        selectSession(last ? last : SessionManager.get(0));
    }

    function selectSession(session: Session) {
        if (session && session === currentSession && pageStack.depth > 0)
            return;
        currentSession = session;
        Config.lastSession = session ? session.id : "";
        pageStack.clear();
        if (session)
            pageStack.push(sessionPageComponent, { session: session });
        else
            pageStack.push(welcomePageComponent);
        if (sidebar.modal)
            sidebar.close();
    }

    function newSession() {
        nameDialog.session = null;
        nameDialog.text = SessionManager.uniqueName(i18n("New Session"));
        nameDialog.open();
    }

    function renameSession(session: Session) {
        nameDialog.session = session;
        nameDialog.text = session.name;
        nameDialog.open();
    }

    function removeSession(session: Session) {
        removeDialog.session = session;
        removeDialog.open();
    }

    function exportSession(session: Session) {
        exportDialog.session = session;
        exportDialog.selectedFile = StandardPaths.writableLocation(StandardPaths.DocumentsLocation) + "/" + session.name + ".grsync";
        exportDialog.open();
    }

    function importGrsync() {
        const count = SessionManager.importGrsyncSessions();
        if (count > 0) {
            showPassiveNotification(i18np("Imported one session from Grsync", "Imported %1 sessions from Grsync", count));
            selectSession(SessionManager.get(SessionManager.count - count));
        } else {
            showPassiveNotification(i18n("No Grsync sessions were found"));
        }
    }

    function requestRun(session: Session, simulate: bool) {
        if (Runner.active)
            return;
        if (!simulate && session.options["delete"] && Config.confirmDelete) {
            deleteConfirmDialog.session = session;
            deleteConfirmDialog.open();
            return;
        }
        Runner.start(session, simulate);
    }

    function showRunPage() {
        if (Runner.session && Runner.session !== currentSession)
            selectSession(Runner.session);
        if (pageStack.layers.depth === 1)
            pageStack.layers.push(runPageComponent);
    }

    function openSettings() {
        if (sidebar.modal)
            sidebar.close();
        pageStack.layers.clear();
        pageStack.layers.push(settingsPageComponent);
    }

    function openAbout() {
        if (sidebar.modal)
            sidebar.close();
        pageStack.layers.clear();
        pageStack.layers.push(aboutPageComponent);
    }

    Connections {
        target: Runner
        function onStarted() {
            root.showRunPage();
        }
    }

    Connections {
        target: SessionManager
        function onCountChanged() {
            if (root.currentSession && SessionManager.indexOf(root.currentSession) < 0)
                root.selectSession(SessionManager.get(0));
            else if (!root.currentSession && SessionManager.count > 0)
                root.selectSession(SessionManager.get(0));
        }
    }

    Shortcut {
        sequences: [StandardKey.New]
        onActivated: root.newSession()
    }
    Shortcut {
        sequences: [StandardKey.Preferences]
        onActivated: root.openSettings()
    }
    Shortcut {
        sequences: [StandardKey.Quit]
        onActivated: Qt.quit()
    }

    Component {
        id: sessionPageComponent
        SessionPage {
            onRunRequested: simulate => root.requestRun(session, simulate)
            onRenameRequested: root.renameSession(session)
            onDuplicateRequested: root.selectSession(SessionManager.duplicate(session))
            onExportRequested: root.exportSession(session)
            onRemoveRequested: root.removeSession(session)
            onShowProgressRequested: root.showRunPage()
        }
    }

    Component {
        id: welcomePageComponent
        WelcomePage {
            onNewSessionRequested: root.newSession()
            onImportRequested: importDialog.open()
            onImportGrsyncRequested: root.importGrsync()
        }
    }

    Component {
        id: runPageComponent
        RunPage {
            onRunAgainRequested: simulate => {
                if (Runner.session)
                    root.requestRun(Runner.session, simulate);
            }
        }
    }

    Component {
        id: settingsPageComponent
        SettingsPage {}
    }

    Component {
        id: aboutPageComponent
        FormCard.AboutPage {
            aboutData: KCoreAddons.AboutData
        }
    }

    NameDialog {
        id: nameDialog
        property Session session: null
        title: session ? i18nc("@title:dialog", "Rename Session") : i18nc("@title:dialog", "New Session")
        acceptText: session ? i18nc("@action:button", "Rename") : i18nc("@action:button", "Create")
        onConfirmed: {
            if (session) {
                session.name = text;
            } else {
                root.selectSession(SessionManager.create(text));
            }
        }
    }

    Kirigami.PromptDialog {
        id: removeDialog
        property Session session: null
        title: i18nc("@title:dialog", "Delete Session?")
        subtitle: session ? i18n("The session “%1” will be removed. Files in its source and destination are not touched.", session.name) : ""
        dialogType: Kirigami.PromptDialog.Warning
        standardButtons: Kirigami.Dialog.NoButton
        customFooterActions: [
            Kirigami.Action {
                text: i18nc("@action:button", "Delete Session")
                icon.name: "edit-delete"
                onTriggered: {
                    SessionManager.remove(removeDialog.session);
                    removeDialog.close();
                }
            },
            Kirigami.Action {
                text: i18nc("@action:button", "Cancel")
                icon.name: "dialog-cancel"
                onTriggered: removeDialog.close()
            }
        ]
    }

    Kirigami.PromptDialog {
        id: deleteConfirmDialog
        property Session session: null
        title: i18nc("@title:dialog", "Delete Files on Destination?")
        subtitle: i18n("This session deletes files in the destination that are not in the source. Deleted files cannot be recovered.\n\nRun a simulation first to see what would be removed.")
        dialogType: Kirigami.PromptDialog.Warning
        standardButtons: Kirigami.Dialog.NoButton
        customFooterActions: [
            Kirigami.Action {
                text: i18nc("@action:button", "Simulate First")
                icon.name: "view-preview"
                onTriggered: {
                    deleteConfirmDialog.close();
                    Runner.start(deleteConfirmDialog.session, true);
                }
            },
            Kirigami.Action {
                text: i18nc("@action:button", "Synchronize")
                icon.name: "folder-sync"
                onTriggered: {
                    deleteConfirmDialog.close();
                    Runner.start(deleteConfirmDialog.session, false);
                }
            }
        ]
    }

    FileDialog {
        id: importDialog
        title: i18nc("@title:dialog", "Import Sessions")
        fileMode: FileDialog.OpenFiles
        nameFilters: [i18n("Grsync session files (*.grsync *.ini)"), i18n("All files (*)")]
        onAccepted: {
            let total = 0;
            for (const url of selectedFiles) {
                const count = SessionManager.importFile(url);
                if (count > 0)
                    total += count;
            }
            if (total > 0) {
                root.showPassiveNotification(i18np("Imported one session", "Imported %1 sessions", total));
                root.selectSession(SessionManager.get(SessionManager.count - total));
            } else {
                root.showPassiveNotification(i18n("No sessions could be imported"));
            }
        }
    }

    FileDialog {
        id: exportDialog
        property Session session: null
        title: i18nc("@title:dialog", "Export Session")
        fileMode: FileDialog.SaveFile
        defaultSuffix: "grsync"
        nameFilters: [i18n("Grsync session files (*.grsync)")]
        onAccepted: {
            if (SessionManager.exportSession(session, selectedFile))
                root.showPassiveNotification(i18n("Session exported"));
            else
                root.showPassiveNotification(i18n("The session could not be exported"));
        }
    }
}
