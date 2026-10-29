// SPDX-License-Identifier: GPL-3.0-or-later

#include "grsyncformat.h"

#include <QDir>

using namespace Qt::StringLiterals;

namespace GrsyncFormat
{

static QString unescape(QStringView value)
{
    QString out;
    out.reserve(value.size());
    for (qsizetype i = 0; i < value.size(); ++i) {
        const QChar c = value[i];
        if (c != u'\\' || i + 1 >= value.size()) {
            out += c;
            continue;
        }
        switch (value[++i].unicode()) {
        case u's':
            out += u' ';
            break;
        case u'n':
            out += u'\n';
            break;
        case u't':
            out += u'\t';
            break;
        case u'r':
            out += u'\r';
            break;
        default:
            out += value[i];
            break;
        }
    }
    return out;
}

static QString escape(const QString &value)
{
    QString out;
    out.reserve(value.size());
    for (qsizetype i = 0; i < value.size(); ++i) {
        const QChar c = value[i];
        if (c == u'\\')
            out += u"\\\\"_s;
        else if (c == u'\n')
            out += u"\\n"_s;
        else if (c == u'\t')
            out += u"\\t"_s;
        else if (c == u'\r')
            out += u"\\r"_s;
        else if (c == u' ' && i == 0)
            out += u"\\s"_s;
        else
            out += c;
    }
    return out;
}

QList<Group> parse(const QByteArray &data)
{
    QList<Group> groups;
    const QStringList lines = QString::fromUtf8(data).split(u'\n');
    for (const QString &rawLine : lines) {
        const QString line = rawLine.trimmed();
        if (line.isEmpty() || line.startsWith(u'#'))
            continue;
        if (line.startsWith(u'[') && line.endsWith(u']')) {
            groups.append({line.mid(1, line.size() - 2), {}});
            continue;
        }
        const qsizetype eq = line.indexOf(u'=');
        if (eq <= 0 || groups.isEmpty())
            continue;
        // Values keep their leading whitespace only when escaped, as in GKeyFile.
        const QString key = line.left(eq).trimmed();
        const QString value = rawLine.mid(rawLine.indexOf(u'=') + 1).trimmed();
        groups.last().entries.insert(key, unescape(value));
    }
    return groups;
}

QByteArray write(const QList<Group> &groups)
{
    QString out;
    for (const Group &group : groups) {
        if (!out.isEmpty())
            out += u'\n';
        out += u'[' + group.name + u"]\n"_s;
        for (auto it = group.entries.cbegin(); it != group.entries.cend(); ++it)
            out += it.key() + u'=' + escape(it.value()) + u'\n';
    }
    return out.toUtf8();
}

QString defaultSessionStore()
{
    return QDir::homePath() + u"/.grsync/grsync.ini"_s;
}

}
