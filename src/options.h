// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QList>
#include <QString>
#include <QVariant>
#include <QVariantMap>

/*
 * Every per-session setting lives in one table. The table drives persistence,
 * Grsync import/export and the rsync command line, so adding an option means
 * adding a row here, a branch in buildArguments() and a control in SessionPage.qml.
 */
namespace Options
{
struct Definition {
    QString key;
    QVariant defaultValue;
    // Matching key in Grsync session files, empty when Grsync has no equivalent.
    QString grsyncKey;
};

const QList<Definition> &definitions();
QVariantMap defaults();

// Arguments passed to rsync, excluding the program itself.
// `forExecution` adds the flags KRsync needs to read progress back.
QStringList buildArguments(const QVariantMap &options, bool dryRun, bool forExecution);

bool isRemotePath(const QString &path);
}
