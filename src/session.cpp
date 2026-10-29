// SPDX-License-Identifier: GPL-3.0-or-later

#include "session.h"

#include "krsyncconfig.h"
#include "options.h"

#include <KConfigGroup>
#include <KLocalizedString>
#include <KShell>

#include <QFileInfo>
#include <QStandardPaths>

using namespace Qt::StringLiterals;

Session::Session(const QString &id, QObject *parent)
    : QObject(parent)
    , m_id(id)
#if QT_VERSION >= QT_VERSION_CHECK(6, 11, 0)
    , m_options(QQmlPropertyMap::create(this))
#else
    , m_options(new QQmlPropertyMap(this))
#endif
{
    const QVariantMap defaults = Options::defaults();
    for (auto it = defaults.cbegin(); it != defaults.cend(); ++it)
        m_options->insert(it.key(), it.value());

    // Fired only for changes made from QML; C++ setters emit on their own.
    connect(m_options, &QQmlPropertyMap::valueChanged, this, [this] {
        Q_EMIT optionsChanged();
        Q_EMIT modified();
    });
}

QString Session::id() const
{
    return m_id;
}

QString Session::name() const
{
    return m_name;
}

void Session::setName(const QString &name)
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty() || trimmed == m_name)
        return;
    m_name = trimmed;
    Q_EMIT nameChanged();
    Q_EMIT modified();
}

QQmlPropertyMap *Session::options() const
{
    return m_options;
}

QVariantMap Session::optionValues() const
{
    QVariantMap map;
    const QStringList keys = m_options->keys();
    for (const QString &key : keys)
        map.insert(key, m_options->value(key));
    return map;
}

QVariant Session::option(const QString &key) const
{
    return m_options->value(key);
}

void Session::setOption(const QString &key, const QVariant &value)
{
    if (m_options->value(key) == value)
        return;
    m_options->insert(key, value);
    Q_EMIT optionsChanged();
    Q_EMIT modified();
}

QString Session::source() const
{
    return option(u"source"_s).toString();
}

QString Session::destination() const
{
    return option(u"destination"_s).toString();
}

bool Session::isSourceRemote() const
{
    return Options::isRemotePath(source());
}

bool Session::isDestinationRemote() const
{
    return Options::isRemotePath(destination());
}

QString Session::program(const QString &rsyncPath) const
{
    return option(u"superuser"_s).toBool() ? u"pkexec"_s : rsyncPath;
}

QStringList Session::arguments(const QString &rsyncPath, bool dryRun, bool forExecution) const
{
    QStringList args = Options::buildArguments(optionValues(), dryRun, forExecution);
    if (option(u"superuser"_s).toBool()) {
        // pkexec wants an absolute program path.
        const QString resolved = QStandardPaths::findExecutable(rsyncPath);
        args.prepend(resolved.isEmpty() ? rsyncPath : resolved);
    }
    return args;
}

QString Session::commandLine() const
{
    const QString rsync = KRsyncConfig::self()->rsyncPath();
    return KShell::joinArgs(QStringList{program(rsync)} + arguments(rsync, false, false));
}

QString Session::validationError() const
{
    if (source().trimmed().isEmpty())
        return i18n("Choose a source to synchronize from.");
    if (destination().trimmed().isEmpty())
        return i18n("Choose a destination to synchronize to.");
    if (!isSourceRemote() && !QFileInfo::exists(KShell::tildeExpand(source())))
        return i18n("The source “%1” does not exist.", source());
    return QString();
}

QDateTime Session::lastRun() const
{
    return m_lastRun;
}

int Session::lastResult() const
{
    return m_lastResult;
}

bool Session::lastRunSimulated() const
{
    return m_lastRunSimulated;
}

void Session::recordRun(int exitCode, bool simulated)
{
    m_lastRun = QDateTime::currentDateTime();
    m_lastResult = exitCode;
    m_lastRunSimulated = simulated;
    Q_EMIT lastRunChanged();
    Q_EMIT modified();
}

void Session::swapPaths()
{
    const QString src = source();
    m_options->insert(u"source"_s, destination());
    m_options->insert(u"destination"_s, src);
    Q_EMIT optionsChanged();
    Q_EMIT modified();
}

void Session::resetOptions()
{
    const QVariantMap defaults = Options::defaults();
    for (auto it = defaults.cbegin(); it != defaults.cend(); ++it) {
        // Keep what identifies the session; reset only behaviour.
        if (it.key() == u"source" || it.key() == u"destination" || it.key() == u"notes")
            continue;
        m_options->insert(it.key(), it.value());
    }
    Q_EMIT optionsChanged();
    Q_EMIT modified();
}

void Session::setSourceContentsOnly(bool contentsOnly)
{
    QString src = source();
    while (src.size() > 1 && src.endsWith(u'/'))
        src.chop(1);
    if (contentsOnly)
        src += u'/';
    setOption(u"source"_s, src);
}

void Session::load(const KConfigGroup &group)
{
    m_name = group.readEntry("Name", i18n("Untitled"));
    for (const auto &def : Options::definitions()) {
        const QVariant value = group.readEntry(def.key.toUtf8().constData(), def.defaultValue);
        m_options->insert(def.key, value);
    }
    m_lastRun = group.readEntry("LastRun", QDateTime());
    m_lastResult = group.readEntry("LastResult", -1);
    m_lastRunSimulated = group.readEntry("LastRunSimulated", false);
    Q_EMIT nameChanged();
    Q_EMIT optionsChanged();
    Q_EMIT lastRunChanged();
}

void Session::save(KConfigGroup &group) const
{
    group.writeEntry("Name", m_name);
    for (const auto &def : Options::definitions())
        group.writeEntry(def.key.toUtf8().constData(), m_options->value(def.key));
    if (m_lastRun.isValid()) {
        group.writeEntry("LastRun", m_lastRun);
        group.writeEntry("LastResult", m_lastResult);
        group.writeEntry("LastRunSimulated", m_lastRunSimulated);
    }
}

void Session::loadGrsync(const QMap<QString, QString> &entries)
{
    for (const auto &def : Options::definitions()) {
        if (def.grsyncKey.isEmpty() || !entries.contains(def.grsyncKey))
            continue;
        const QString raw = entries.value(def.grsyncKey);
        if (def.defaultValue.typeId() == QMetaType::Bool)
            m_options->insert(def.key, raw.compare(u"true"_s, Qt::CaseInsensitive) == 0 || raw == u"1");
        else
            m_options->insert(def.key, raw);
    }
    Q_EMIT optionsChanged();
    Q_EMIT modified();
}

QMap<QString, QString> Session::toGrsync() const
{
    QMap<QString, QString> entries;
    for (const auto &def : Options::definitions()) {
        if (def.grsyncKey.isEmpty())
            continue;
        const QVariant value = m_options->value(def.key);
        if (def.defaultValue.typeId() == QMetaType::Bool)
            entries.insert(def.grsyncKey, value.toBool() ? u"true"_s : u"false"_s);
        else
            entries.insert(def.grsyncKey, value.toString());
    }
    // Grsync reads these too; KRsync always reports progress itself.
    entries.insert(u"check_progr"_s, u"true"_s);
    return entries;
}
