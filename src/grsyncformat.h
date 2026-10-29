// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QByteArray>
#include <QList>
#include <QMap>
#include <QString>

/*
 * Minimal reader/writer for the GKeyFile format Grsync uses for both its
 * session store (~/.grsync/grsync.ini) and exported .grsync files.
 */
namespace GrsyncFormat
{
struct Group {
    QString name;
    QMap<QString, QString> entries;
};

QList<Group> parse(const QByteArray &data);
QByteArray write(const QList<Group> &groups);

QString defaultSessionStore();
}
