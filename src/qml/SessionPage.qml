// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Dialogs
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard
import org.kde.coreaddons as KCoreAddons
import org.kde.krsync
import org.kde.krsync.config

FormCard.FormCardPage {
    id: page

    required property Session session

    signal runRequested(bool simulate)
    signal renameRequested
    signal duplicateRequested
    signal exportRequested
    signal removeRequested
    signal showProgressRequested

    readonly property var opts: session.options
    readonly property bool runningHere: Runner.active && Runner.session === session
    readonly property bool canRun: !Runner.active && session.validationError.length === 0
    readonly property real cardWidth: Kirigami.Units.gridUnit * 36

    title: session.name

    actions: [
        Kirigami.Action {
            text: i18nc("@action:intoolbar", "Show Command")
            icon.name: "utilities-terminal"
            displayHint: Kirigami.DisplayHint.AlwaysHide
            onTriggered: commandDialog.open()
        },
        Kirigami.Action {
            text: i18nc("@action:intoolbar", "Rename…")
            icon.name: "edit-rename"
            displayHint: Kirigami.DisplayHint.AlwaysHide
            shortcut: "F2"
            onTriggered: page.renameRequested()
        },
        Kirigami.Action {
            text: i18nc("@action:intoolbar", "Duplicate")
            icon.name: "edit-copy"
            displayHint: Kirigami.DisplayHint.AlwaysHide
            onTriggered: page.duplicateRequested()
        },
        Kirigami.Action {
            text: i18nc("@action:intoolbar", "Export…")
            icon.name: "document-export"
            displayHint: Kirigami.DisplayHint.AlwaysHide
            onTriggered: page.exportRequested()
        },
        Kirigami.Action {
            text: i18nc("@action:intoolbar", "Reset Options to Defaults")
            icon.name: "edit-reset"
            displayHint: Kirigami.DisplayHint.AlwaysHide
            onTriggered: page.session.resetOptions()
        },
        Kirigami.Action {
            text: i18nc("@action:intoolbar", "Delete Session…")
            icon.name: "edit-delete"
            displayHint: Kirigami.DisplayHint.AlwaysHide
            enabled: !page.runningHere
            onTriggered: page.removeRequested()
        }
    ]

    // Helpers keep each option row a one-liner below.
    component OptionSwitch: FormCard.FormSwitchDelegate {
        required property string key
        checked: page.opts[key] ?? false
        onToggled: page.opts[key] = checked
    }

    component OptionText: FormCard.FormTextFieldDelegate {
        required property string key
        text: page.opts[key] ?? ""
        onTextEdited: page.opts[key] = text
    }

    component OptionNumber: FormCard.FormSpinBoxDelegate {
        required property string key
        from: 0
        to: 2147483647
        value: page.opts[key] ?? 0
        onValueModified: page.opts[key] = value
    }

    function summarize(entries: var): string {
        const on = entries.filter(e => page.opts[e[0]]).map(e => e[1]);
        return on.length > 0 ? on.join(i18nc("list separator", ", ")) : i18nc("@info no options enabled", "None enabled");
    }

    Shortcut {
        sequences: ["Ctrl+Return"]
        enabled: page.canRun
        onActivated: page.runRequested(false)
    }
    Shortcut {
        sequences: ["Ctrl+Shift+Return"]
        enabled: page.canRun
        onActivated: page.runRequested(true)
    }

    // ── Status banners ───────────────────────────────────────────────

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.maximumWidth: page.cardWidth
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Kirigami.Units.largeSpacing
        position: Kirigami.InlineMessage.Position.Inline
        visible: page.runningHere
        type: Kirigami.MessageType.Information
        icon.name: "folder-sync"
        text: Runner.simulation ? i18n("A simulation of this session is running.") : i18n("This session is being synchronized.")
        actions: Kirigami.Action {
            text: i18nc("@action:button", "Show Progress")
            icon.name: "view-list-details"
            onTriggered: page.showProgressRequested()
        }
    }

    Kirigami.InlineMessage {
        Layout.fillWidth: true
        Layout.maximumWidth: page.cardWidth
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Kirigami.Units.largeSpacing
        position: Kirigami.InlineMessage.Position.Inline
        visible: page.opts.superuser
        type: Kirigami.MessageType.Warning
        text: i18n("This session runs rsync with administrator privileges.")
    }

    // ── Hero: source → destination ───────────────────────────────────

    FormCard.FormCard {
        Layout.topMargin: Kirigami.Units.largeSpacing
        maximumWidth: page.cardWidth

        FormCard.AbstractFormDelegate {
            background: null
            hoverEnabled: false
            focusPolicy: Qt.NoFocus

            contentItem: GridLayout {
                id: heroGrid
                readonly property bool wide: width > Kirigami.Units.gridUnit * 26

                columns: wide ? 3 : 1
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                PathField {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: i18nc("@label", "Source")
                    placeholder: i18nc("@info:placeholder", "/home/me/Pictures or user@host:path")
                    path: page.session.source
                    onPathEdited: path => page.opts.source = path
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignCenter
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: Kirigami.Units.iconSizes.medium
                        implicitHeight: Kirigami.Units.iconSizes.medium
                        source: heroGrid.wide ? "go-next-symbolic" : "go-down-symbolic"
                        color: Kirigami.Theme.highlightColor
                        isMask: true

                        SequentialAnimation on opacity {
                            running: page.runningHere && !Runner.paused
                            loops: Animation.Infinite
                            alwaysRunToEnd: true
                            NumberAnimation { to: 0.3; duration: Kirigami.Units.veryLongDuration; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1; duration: Kirigami.Units.veryLongDuration; easing.type: Easing.InOutQuad }
                        }
                    }

                    QQC2.ToolButton {
                        Layout.alignment: Qt.AlignHCenter
                        icon.name: "exchange-positions"
                        text: i18nc("@action:button", "Swap Source and Destination")
                        display: QQC2.AbstractButton.IconOnly
                        enabled: !page.runningHere
                        onClicked: page.session.swapPaths()
                        QQC2.ToolTip.text: text
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                }

                PathField {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    label: i18nc("@label", "Destination")
                    placeholder: i18nc("@info:placeholder", "/run/media/me/Backup")
                    path: page.session.destination
                    onPathEdited: path => page.opts.destination = path
                }
            }
        }

        FormCard.FormDelegateSeparator {
            visible: contentsSwitch.visible
        }

        // rsync's trailing-slash rule, made explicit.
        FormCard.FormSwitchDelegate {
            id: contentsSwitch

            readonly property string srcName: SessionManager.displayName(page.session.source)
            readonly property string dstName: SessionManager.displayName(page.session.destination) || i18nc("@info", "the destination")

            visible: page.session.source.length > 0 && (page.session.sourceRemote || SessionManager.isDirectory(page.session.source))
            icon.name: "folder-open"
            text: i18nc("@option:check", "Copy only the folder's contents")
            description: checked
                ? i18n("Everything inside “%1” goes directly into “%2”.", srcName, dstName)
                : i18n("“%1” itself is copied into “%2”, as “%2/%1”.", srcName, dstName)
            checked: page.session.source.endsWith("/")
            onToggled: page.session.setSourceContentsOnly(checked)
        }

        FormCard.FormDelegateSeparator {}

        FormCard.AbstractFormDelegate {
            background: null
            hoverEnabled: false
            focusPolicy: Qt.NoFocus

            contentItem: GridLayout {
                readonly property bool wide: width > Kirigami.Units.gridUnit * 24
                columns: wide ? 2 : 1
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.largeSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Icon {
                        implicitWidth: Kirigami.Units.iconSizes.smallMedium
                        implicitHeight: Kirigami.Units.iconSizes.smallMedium
                        source: page.session.validationError.length > 0 ? "dialog-information"
                              : page.session.lastResult < 0 ? "clock"
                              : page.session.lastResult === 0 ? "emblem-success" : "emblem-error"
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        opacity: 0.8
                        text: {
                            if (page.session.validationError.length > 0)
                                return page.session.validationError;
                            if (page.session.lastResult < 0)
                                return i18n("Never synchronized");
                            const when = KCoreAddons.Format.formatRelativeDateTime(page.session.lastRun, Locale.LongFormat);
                            if (page.session.lastRunSimulated)
                                return page.session.lastResult === 0 ? i18n("Last simulated %1", when) : i18n("Last simulation failed %1", when);
                            return page.session.lastResult === 0 ? i18n("Last synchronized %1", when) : i18n("Last synchronization failed %1", when);
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Button {
                        icon.name: "view-preview"
                        text: i18nc("@action:button", "Simulate")
                        enabled: page.canRun
                        onClicked: page.runRequested(true)
                        QQC2.ToolTip.text: i18nc("@info:tooltip", "Show what would change without touching any files (Ctrl+Shift+Return)")
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }

                    QQC2.Button {
                        icon.name: "folder-sync"
                        text: i18nc("@action:button", "Synchronize")
                        highlighted: true
                        enabled: page.canRun
                        onClicked: page.runRequested(false)
                        QQC2.ToolTip.text: i18nc("@info:tooltip", "Ctrl+Return")
                        QQC2.ToolTip.visible: hovered
                        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                    }
                }
            }
        }
    }

    // ── Options ──────────────────────────────────────────────────────

    OptionSection {
        title: i18nc("@title:group", "Preserve")
        summary: page.summarize([["times", i18n("Times")], ["perms", i18n("Permissions")], ["owner", i18n("Owner")], ["group", i18n("Group")], ["symlinks", i18n("Symlinks")], ["hardLinks", i18n("Hard links")], ["devices", i18n("Devices")], ["acls", i18n("ACLs")], ["xattrs", i18n("Extended attributes")]])

        OptionSwitch {
            key: "times"
            icon.name: "clock"
            text: i18nc("@option:check", "Modification times")
            description: i18n("Recommended: lets later syncs skip unchanged files quickly.")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "perms"
            icon.name: "object-locked"
            text: i18nc("@option:check", "Permissions")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "owner"
            icon.name: "user"
            text: i18nc("@option:check", "Owner")
            description: i18n("Only works when the destination is written as administrator.")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "group"
            icon.name: "group"
            text: i18nc("@option:check", "Group")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "symlinks"
            icon.name: "insert-link"
            text: i18nc("@option:check", "Copy symlinks as symlinks")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "copyLinks"
            icon.name: "edit-link"
            text: i18nc("@option:check", "Follow symlinks")
            description: i18n("Copy the files symlinks point to instead of the links themselves.")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "hardLinks"
            icon.name: "link"
            text: i18nc("@option:check", "Hard links")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "devices"
            icon.name: "drive-harddisk"
            text: i18nc("@option:check", "Device and special files")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "acls"
            icon.name: "security-high"
            text: i18nc("@option:check", "Access control lists")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "xattrs"
            icon.name: "tag"
            text: i18nc("@option:check", "Extended attributes")
        }
    }

    OptionSection {
        title: i18nc("@title:group", "Comparison")
        summary: page.summarize([["skipNewer", i18n("Skip newer")], ["ignoreExisting", i18n("Ignore existing")], ["existingOnly", i18n("Existing only")], ["sizeOnly", i18n("Size only")], ["checksum", i18n("Checksum")], ["windowsCompat", i18n("Windows compatibility")]])

        OptionSwitch {
            key: "skipNewer"
            text: i18nc("@option:check", "Skip files that are newer on the destination")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "ignoreExisting"
            text: i18nc("@option:check", "Don't update files that already exist")
            description: i18n("Only add files missing from the destination.")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "existingOnly"
            text: i18nc("@option:check", "Only update files that already exist")
            description: i18n("Never create new files on the destination.")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "sizeOnly"
            text: i18nc("@option:check", "Compare by size only")
            description: i18n("Ignore modification times when deciding what changed.")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "checksum"
            text: i18nc("@option:check", "Always compare checksums")
            description: i18n("Most thorough, but reads every file on both sides.")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "windowsCompat"
            text: i18nc("@option:check", "Windows filesystem compatibility")
            description: i18n("Tolerate the 2-second time precision of FAT and NTFS drives.")
        }
    }

    OptionSection {
        title: i18nc("@title:group", "Deletion")
        summary: page.opts["delete"] ? i18n("Deletes extraneous files on the destination") : i18n("Never deletes files on the destination")

        OptionSwitch {
            key: "delete"
            icon.name: "edit-delete"
            icon.color: checked ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
            text: i18nc("@option:check", "Delete files missing from the source")
            description: i18n("Makes the destination an exact mirror. Files only on the destination are permanently removed.")
        }
        FormCard.FormDelegateSeparator {
            visible: page.opts["delete"]
        }
        FormCard.FormComboBoxDelegate {
            visible: page.opts["delete"]
            text: i18nc("@label:listbox", "When to delete")
            textRole: "text"
            valueRole: "value"
            model: [
                { text: i18nc("@item:inlistbox", "While transferring"), value: "during" },
                { text: i18nc("@item:inlistbox", "Before transferring"), value: "before" },
                { text: i18nc("@item:inlistbox", "After transferring"), value: "after" },
                { text: i18nc("@item:inlistbox", "After transferring, found during"), value: "delay" }
            ]
            currentIndex: Math.max(0, ["during", "before", "after", "delay"].indexOf(page.opts.deleteTiming))
            onActivated: index => page.opts.deleteTiming = currentValue
        }
        FormCard.FormDelegateSeparator {
            visible: page.opts["delete"]
        }
        OptionSwitch {
            visible: page.opts["delete"]
            key: "deleteExcluded"
            text: i18nc("@option:check", "Also delete excluded files")
        }
        FormCard.FormDelegateSeparator {
            visible: page.opts["delete"]
        }
        OptionNumber {
            visible: page.opts["delete"]
            key: "maxDelete"
            label: i18nc("@label:spinbox", "Maximum deletions (0 for no limit)")
        }
    }

    OptionSection {
        title: i18nc("@title:group", "Transfer")
        expanded: false
        summary: page.summarize([["compress", i18n("Compress")], ["partial", i18n("Keep partial")], ["wholeFile", i18n("Whole files")], ["oneFileSystem", i18n("One filesystem")], ["noRecursion", i18n("No recursion")], ["protectArgs", i18n("Protect arguments")], ["numericIds", i18n("Numeric IDs")]])

        OptionSwitch {
            key: "compress"
            icon.name: "package-x-generic"
            text: i18nc("@option:check", "Compress data during transfer")
            description: i18n("Speeds up slow network links; wasteful on local disks.")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "partial"
            icon.name: "media-playback-pause"
            text: i18nc("@option:check", "Keep partially transferred files")
            description: i18n("Resume large files after an interruption.")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "wholeFile"
            text: i18nc("@option:check", "Copy whole files")
            description: i18n("Skip the delta algorithm; often faster between local disks.")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "oneFileSystem"
            text: i18nc("@option:check", "Don't cross filesystem boundaries")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "noRecursion"
            text: i18nc("@option:check", "Don't descend into subfolders")
        }
        FormCard.FormDelegateSeparator {}
        OptionNumber {
            key: "bwLimit"
            label: i18nc("@label:spinbox", "Bandwidth limit in KiB/s (0 for no limit)")
        }
        FormCard.FormDelegateSeparator {}
        OptionText {
            key: "remoteShell"
            label: i18nc("@label:textbox", "Remote shell")
            placeholderText: i18nc("@info:placeholder", "ssh -p 2222")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "protectArgs"
            text: i18nc("@option:check", "Protect remote arguments")
            description: i18n("Pass paths with spaces to the remote side unmangled.")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "numericIds"
            text: i18nc("@option:check", "Keep numeric user and group IDs")
        }
    }

    OptionSection {
        title: i18nc("@title:group", "Exclusions")
        expanded: false
        summary: {
            const count = (page.opts.excludes || "").split("\n").filter(l => l.trim().length > 0).length;
            return count > 0 ? i18np("One pattern", "%1 patterns", count) : i18n("Nothing excluded");
        }

        FormCard.FormTextAreaDelegate {
            label: i18nc("@label:textbox", "Exclude patterns, one per line")
            placeholderText: "*.tmp\n.cache/\nnode_modules/"
            text: page.opts.excludes ?? ""
            onTextChanged: if (page.opts.excludes !== text) page.opts.excludes = text
        }
        FormCard.FormDelegateSeparator {}
        OptionText {
            key: "excludeFrom"
            label: i18nc("@label:textbox", "Read patterns from file")
            placeholderText: i18nc("@info:placeholder", "Optional")
        }
        FormCard.FormButtonDelegate {
            icon.name: "document-open"
            text: i18nc("@action:button", "Choose Pattern File…")
            onClicked: excludeFileDialog.open()
        }
    }

    OptionSection {
        title: i18nc("@title:group", "Backups")
        expanded: false
        summary: page.opts.backup ? i18n("Replaced files are backed up") : i18n("Off")

        OptionSwitch {
            key: "backup"
            icon.name: "document-save-as"
            text: i18nc("@option:check", "Back up replaced and deleted files")
        }
        FormCard.FormDelegateSeparator {
            visible: page.opts.backup
        }
        OptionText {
            visible: page.opts.backup
            key: "backupDir"
            label: i18nc("@label:textbox", "Backup folder")
            placeholderText: i18nc("@info:placeholder", "Next to the original file")
        }
        FormCard.FormDelegateSeparator {
            visible: page.opts.backup
        }
        OptionText {
            visible: page.opts.backup
            key: "backupSuffix"
            label: i18nc("@label:textbox", "Backup suffix")
            placeholderText: "~"
        }
    }

    OptionSection {
        title: i18nc("@title:group", "Output")
        expanded: false
        summary: page.summarize([["verbose", i18n("List files")], ["itemize", i18n("Itemized changes")], ["stats", i18n("Statistics")]])

        OptionSwitch {
            key: "verbose"
            icon.name: "view-list-text"
            text: i18nc("@option:check", "List transferred files")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "itemize"
            icon.name: "view-list-details"
            text: i18nc("@option:check", "Itemize changes")
            description: i18n("Show what changed about each file, such as size, time or permissions.")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "stats"
            icon.name: "office-chart-bar"
            text: i18nc("@option:check", "Collect transfer statistics")
        }
    }

    OptionSection {
        title: i18nc("@title:group", "Advanced")
        expanded: false
        summary: {
            const parts = [];
            if (page.opts.superuser)
                parts.push(i18n("As administrator"));
            if ((page.opts.extraArgs || "").trim().length > 0)
                parts.push(i18n("Extra options"));
            if (page.opts.preCommandEnabled)
                parts.push(i18n("Command before"));
            if (page.opts.postCommandEnabled)
                parts.push(i18n("Command after"));
            return parts.length > 0 ? parts.join(i18nc("list separator", ", ")) : i18nc("@info no options enabled", "None enabled");
        }

        OptionSwitch {
            key: "superuser"
            icon.name: "dialog-password"
            text: i18nc("@option:check", "Run as administrator")
            description: i18n("Asks for your password through Polkit. Pausing is unavailable.")
        }
        FormCard.FormDelegateSeparator {}
        OptionText {
            key: "extraArgs"
            label: i18nc("@label:textbox", "Additional rsync options")
            placeholderText: "--chmod=D755,F644 --info=skip2"
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "preCommandEnabled"
            icon.name: "go-first"
            text: i18nc("@option:check", "Run a command before synchronizing")
        }
        OptionText {
            visible: page.opts.preCommandEnabled
            key: "preCommand"
            label: i18nc("@label:textbox", "Command")
            placeholderText: "mount /mnt/backup"
        }
        OptionSwitch {
            visible: page.opts.preCommandEnabled
            key: "preAbortOnFailure"
            text: i18nc("@option:check", "Don't synchronize if the command fails")
        }
        FormCard.FormDelegateSeparator {}
        OptionSwitch {
            key: "postCommandEnabled"
            icon.name: "go-last"
            text: i18nc("@option:check", "Run a command after synchronizing")
        }
        OptionText {
            visible: page.opts.postCommandEnabled
            key: "postCommand"
            label: i18nc("@label:textbox", "Command")
            placeholderText: "umount /mnt/backup"
        }
        OptionSwitch {
            visible: page.opts.postCommandEnabled
            key: "postOnlyOnSuccess"
            text: i18nc("@option:check", "Only if synchronization succeeded")
        }
        FormCard.FormSectionText {
            visible: page.opts.preCommandEnabled || page.opts.postCommandEnabled
            text: i18n("Commands run with /bin/sh and can read $KRSYNC_SOURCE, $KRSYNC_DESTINATION, $KRSYNC_SESSION and, afterwards, $KRSYNC_EXIT_CODE. They are skipped during simulations.")
        }
    }

    OptionSection {
        title: i18nc("@title:group", "Notes")
        expanded: (page.opts.notes ?? "").length > 0
        summary: (page.opts.notes ?? "").split("\n")[0] || i18n("No notes")

        FormCard.FormTextAreaDelegate {
            label: i18nc("@label:textbox", "Notes")
            placeholderText: i18nc("@info:placeholder", "What this session is for, where the drive lives…")
            text: page.opts.notes ?? ""
            onTextChanged: if (page.opts.notes !== text) page.opts.notes = text
        }
    }

    // ── Command preview ──────────────────────────────────────────────

    FormCard.FormHeader {
        visible: Config.showCommandPreview
        title: i18nc("@title:group", "Command")
        maximumWidth: page.cardWidth
    }

    FormCard.FormCard {
        visible: Config.showCommandPreview
        maximumWidth: page.cardWidth
        Layout.bottomMargin: Kirigami.Units.gridUnit

        FormCard.AbstractFormDelegate {
            background: null
            hoverEnabled: false
            focusPolicy: Qt.NoFocus

            contentItem: RowLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC2.TextArea {
                    id: commandText
                    Layout.fillWidth: true
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.WrapAnywhere
                    font.family: Kirigami.Theme.fixedWidthFont.family
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    text: page.session.commandLine
                    background: null
                }

                QQC2.ToolButton {
                    Layout.alignment: Qt.AlignTop
                    icon.name: "edit-copy"
                    text: i18nc("@action:button", "Copy Command")
                    display: QQC2.AbstractButton.IconOnly
                    onClicked: {
                        commandText.selectAll();
                        commandText.copy();
                        commandText.deselect();
                        applicationWindow().showPassiveNotification(i18n("Command copied to the clipboard"));
                    }
                    QQC2.ToolTip.text: text
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                }
            }
        }
    }

    Kirigami.Dialog {
        id: commandDialog
        title: i18nc("@title:dialog", "rsync Command")
        standardButtons: Kirigami.Dialog.Close
        preferredWidth: Kirigami.Units.gridUnit * 30
        padding: Kirigami.Units.largeSpacing

        QQC2.TextArea {
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.WrapAnywhere
            font.family: Kirigami.Theme.fixedWidthFont.family
            text: page.session.commandLine
        }
    }

    FileDialog {
        id: excludeFileDialog
        title: i18nc("@title:dialog", "Choose Exclude File")
        fileMode: FileDialog.OpenFile
        onAccepted: page.opts.excludeFrom = SessionManager.urlToPath(selectedFile)
    }
}
