// SPDX-License-Identifier: GPL-3.0-or-later

#include "options.h"

#include <KShell>

#include <QRegularExpression>

using namespace Qt::StringLiterals;

namespace Options
{

const QList<Definition> &definitions()
{
    static const QList<Definition> defs = {
        // Paths and notes
        {u"source"_s, QString(), u"text_source"_s},
        {u"destination"_s, QString(), u"text_dest"_s},
        {u"notes"_s, QString(), u"text_notes"_s},

        // Preserve
        {u"times"_s, true, u"check_time"_s},
        {u"perms"_s, true, u"check_perm"_s},
        {u"owner"_s, true, u"check_owner"_s},
        {u"group"_s, true, u"check_group"_s},
        {u"symlinks"_s, true, u"check_symlink"_s},
        {u"copyLinks"_s, false, QString()},
        {u"hardLinks"_s, false, u"check_hardlink"_s},
        {u"devices"_s, false, u"check_dev"_s},
        {u"acls"_s, false, QString()},
        {u"xattrs"_s, false, QString()},

        // Comparison
        {u"skipNewer"_s, false, u"check_skipnew"_s},
        {u"ignoreExisting"_s, false, u"check_exist"_s},
        {u"existingOnly"_s, false, u"check_existing"_s},
        {u"sizeOnly"_s, false, u"check_size"_s},
        {u"checksum"_s, false, u"check_sum"_s},
        {u"windowsCompat"_s, false, u"check_windows"_s},

        // Deletion
        {u"delete"_s, false, u"check_delete"_s},
        {u"deleteTiming"_s, u"during"_s, QString()},
        {u"deleteExcluded"_s, false, QString()},
        {u"maxDelete"_s, 0, QString()},

        // Transfer
        {u"compress"_s, false, u"check_compr"_s},
        {u"partial"_s, false, u"check_keepart"_s},
        {u"wholeFile"_s, false, QString()},
        {u"oneFileSystem"_s, false, u"check_onefs"_s},
        {u"noRecursion"_s, false, u"check_norecur"_s},
        {u"bwLimit"_s, 0, QString()},
        {u"remoteShell"_s, QString(), QString()},
        {u"protectArgs"_s, false, u"check_protectremote"_s},
        {u"numericIds"_s, false, QString()},

        // Filters
        {u"excludes"_s, QString(), QString()},
        {u"excludeFrom"_s, QString(), QString()},

        // Backups
        {u"backup"_s, false, u"check_backup"_s},
        {u"backupDir"_s, QString(), QString()},
        {u"backupSuffix"_s, QString(), QString()},

        // Output
        {u"verbose"_s, true, u"check_verbose"_s},
        {u"itemize"_s, false, u"check_itemized"_s},
        {u"stats"_s, true, u"check_stats"_s},

        // Advanced
        {u"superuser"_s, false, u"check_superuser"_s},
        {u"extraArgs"_s, QString(), u"text_addit"_s},
        {u"preCommandEnabled"_s, false, u"check_com_before"_s},
        {u"preCommand"_s, QString(), u"text_com_before"_s},
        {u"preAbortOnFailure"_s, true, u"check_com_halt"_s},
        {u"postCommandEnabled"_s, false, u"check_com_after"_s},
        {u"postCommand"_s, QString(), u"text_com_after"_s},
        {u"postOnlyOnSuccess"_s, false, u"check_com_onerror"_s},
    };
    return defs;
}

QVariantMap defaults()
{
    QVariantMap map;
    for (const auto &def : definitions()) {
        map.insert(def.key, def.defaultValue);
    }
    return map;
}

QStringList buildArguments(const QVariantMap &o, bool dryRun, bool forExecution)
{
    const auto on = [&o](const char16_t *key) {
        return o.value(QString::fromUtf16(key)).toBool();
    };
    const auto str = [&o](const char16_t *key) {
        return o.value(QString::fromUtf16(key)).toString().trimmed();
    };

    QStringList args;
    args << (on(u"noRecursion") ? u"-d"_s : u"-r"_s);

    if (on(u"times"))
        args << u"-t"_s;
    if (on(u"perms"))
        args << u"-p"_s;
    if (on(u"owner"))
        args << u"-o"_s;
    if (on(u"group"))
        args << u"-g"_s;
    if (on(u"symlinks"))
        args << u"-l"_s;
    if (on(u"copyLinks"))
        args << u"-L"_s;
    if (on(u"hardLinks"))
        args << u"-H"_s;
    if (on(u"devices"))
        args << u"-D"_s;
    if (on(u"acls"))
        args << u"-A"_s;
    if (on(u"xattrs"))
        args << u"-X"_s;

    if (on(u"verbose"))
        args << u"-v"_s;
    if (on(u"itemize"))
        args << u"-i"_s;

    if (on(u"skipNewer"))
        args << u"-u"_s;
    if (on(u"ignoreExisting"))
        args << u"--ignore-existing"_s;
    if (on(u"existingOnly"))
        args << u"--existing"_s;
    if (on(u"sizeOnly"))
        args << u"--size-only"_s;
    if (on(u"checksum"))
        args << u"-c"_s;
    if (on(u"windowsCompat"))
        args << u"--modify-window=1"_s;

    if (on(u"delete")) {
        const QString timing = str(u"deleteTiming");
        if (timing == u"before")
            args << u"--delete-before"_s;
        else if (timing == u"after")
            args << u"--delete-after"_s;
        else if (timing == u"delay")
            args << u"--delete-delay"_s;
        else
            args << u"--delete"_s;
        if (on(u"deleteExcluded"))
            args << u"--delete-excluded"_s;
        const int maxDelete = o.value(u"maxDelete"_s).toInt();
        if (maxDelete > 0)
            args << u"--max-delete=%1"_s.arg(maxDelete);
    }

    if (on(u"compress"))
        args << u"-z"_s;
    if (on(u"partial"))
        args << u"--partial"_s;
    if (on(u"wholeFile"))
        args << u"-W"_s;
    if (on(u"oneFileSystem"))
        args << u"-x"_s;
    const int bwLimit = o.value(u"bwLimit"_s).toInt();
    if (bwLimit > 0)
        args << u"--bwlimit=%1"_s.arg(bwLimit);
    if (const QString rsh = str(u"remoteShell"); !rsh.isEmpty())
        args << u"--rsh=%1"_s.arg(rsh);
    if (on(u"protectArgs"))
        args << u"-s"_s;
    if (on(u"numericIds"))
        args << u"--numeric-ids"_s;

    const QStringList excludes = o.value(u"excludes"_s).toString().split(u'\n', Qt::SkipEmptyParts);
    for (const QString &pattern : excludes) {
        if (!pattern.trimmed().isEmpty())
            args << u"--exclude=%1"_s.arg(pattern.trimmed());
    }
    if (const QString from = str(u"excludeFrom"); !from.isEmpty())
        args << u"--exclude-from=%1"_s.arg(from);

    if (on(u"backup")) {
        args << u"-b"_s;
        if (const QString dir = str(u"backupDir"); !dir.isEmpty())
            args << u"--backup-dir=%1"_s.arg(dir);
        if (const QString suffix = str(u"backupSuffix"); !suffix.isEmpty())
            args << u"--suffix=%1"_s.arg(suffix);
    }

    if (on(u"stats"))
        args << u"--stats"_s;

    if (forExecution) {
        // Overall progress on one line, line-buffered so updates arrive promptly.
        args << u"--info=progress2"_s << u"--outbuf=L"_s;
    }

    if (dryRun)
        args << u"--dry-run"_s;

    if (const QString extra = str(u"extraArgs"); !extra.isEmpty()) {
        KShell::Errors err = KShell::NoError;
        const QStringList split = KShell::splitArgs(extra, KShell::TildeExpand, &err);
        args << (err == KShell::NoError ? split : extra.split(u' ', Qt::SkipEmptyParts));
    }

    args << KShell::tildeExpand(o.value(u"source"_s).toString()) << KShell::tildeExpand(o.value(u"destination"_s).toString());
    return args;
}

bool isRemotePath(const QString &path)
{
    static const QRegularExpression remote(u"^(rsync://|[^/:]+:)"_s);
    return remote.match(path).hasMatch();
}

}
