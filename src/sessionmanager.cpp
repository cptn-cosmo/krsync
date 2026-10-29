// SPDX-License-Identifier: GPL-3.0-or-later

#include "sessionmanager.h"

#include "grsyncformat.h"
#include "options.h"
#include "session.h"

#include <KConfigGroup>
#include <KLocalizedString>
#include <KShell>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QUuid>

using namespace Qt::StringLiterals;

static const QString s_groupPrefix = u"Session-"_s;

SessionManager *SessionManager::instance()
{
    static SessionManager *manager = new SessionManager;
    return manager;
}

SessionManager *SessionManager::create(QQmlEngine *, QJSEngine *)
{
    auto *manager = instance();
    QQmlEngine::setObjectOwnership(manager, QQmlEngine::CppOwnership);
    return manager;
}

SessionManager::SessionManager(QObject *parent)
    : QAbstractListModel(parent)
    , m_config(KSharedConfig::openConfig(u"krsyncsessionsrc"_s, KConfig::SimpleConfig, QStandardPaths::AppDataLocation))
{
    m_saveTimer.setSingleShot(true);
    m_saveTimer.setInterval(400);
    connect(&m_saveTimer, &QTimer::timeout, this, &SessionManager::save);
    load();
}

int SessionManager::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_sessions.size());
}

QVariant SessionManager::data(const QModelIndex &index, int role) const
{
    if (!checkIndex(index, CheckIndexOption::IndexIsValid))
        return {};
    Session *session = m_sessions.at(index.row());
    switch (role) {
    case Qt::DisplayRole:
    case NameRole:
        return session->name();
    case SessionRole:
        return QVariant::fromValue(session);
    case SourceRole:
        return session->source();
    case DestinationRole:
        return session->destination();
    case RemoteRole:
        return session->isSourceRemote() || session->isDestinationRemote();
    case LastRunRole:
        return session->lastRun();
    case LastResultRole:
        return session->lastResult();
    }
    return {};
}

QHash<int, QByteArray> SessionManager::roleNames() const
{
    return {
        {NameRole, "name"},
        {SessionRole, "session"},
        {SourceRole, "source"},
        {DestinationRole, "destination"},
        {RemoteRole, "remote"},
        {LastRunRole, "lastRun"},
        {LastResultRole, "lastResult"},
    };
}

bool SessionManager::grsyncSessionsAvailable() const
{
    return QFileInfo::exists(GrsyncFormat::defaultSessionStore());
}

Session *SessionManager::get(int row) const
{
    return row >= 0 && row < m_sessions.size() ? m_sessions.at(row) : nullptr;
}

int SessionManager::indexOf(Session *session) const
{
    return int(m_sessions.indexOf(session));
}

Session *SessionManager::findById(const QString &id) const
{
    for (Session *session : m_sessions) {
        if (session->id() == id)
            return session;
    }
    return nullptr;
}

Session *SessionManager::find(const QString &idOrName) const
{
    if (Session *session = findById(idOrName))
        return session;
    for (Session *session : m_sessions) {
        if (session->name().compare(idOrName, Qt::CaseInsensitive) == 0)
            return session;
    }
    return nullptr;
}

Session *SessionManager::create(const QString &name)
{
    auto *session = new Session(QUuid::createUuid().toString(QUuid::WithoutBraces), this);
    session->setName(uniqueName(name.trimmed().isEmpty() ? i18n("New Session") : name));
    add(session);
    scheduleSave();
    return session;
}

Session *SessionManager::duplicate(Session *original)
{
    if (!original)
        return nullptr;
    auto *session = new Session(QUuid::createUuid().toString(QUuid::WithoutBraces), this);
    session->setName(uniqueName(i18nc("@title name of a duplicated session", "%1 (Copy)", original->name())));
    const QVariantMap values = original->optionValues();
    for (auto it = values.cbegin(); it != values.cend(); ++it)
        session->setOption(it.key(), it.value());

    const int row = indexOf(original) + 1;
    beginInsertRows({}, row, row);
    m_sessions.insert(row, session);
    connect(session, &Session::modified, this, [this, session] {
        onSessionChanged(session);
    });
    endInsertRows();
    Q_EMIT countChanged();
    scheduleSave();
    return session;
}

void SessionManager::remove(Session *session)
{
    const int row = indexOf(session);
    if (row < 0)
        return;
    beginRemoveRows({}, row, row);
    m_sessions.removeAt(row);
    endRemoveRows();
    m_config->deleteGroup(s_groupPrefix + session->id());
    session->deleteLater();
    Q_EMIT countChanged();
    scheduleSave();
}

void SessionManager::move(int from, int to)
{
    if (from == to || from < 0 || to < 0 || from >= m_sessions.size() || to >= m_sessions.size())
        return;
    beginMoveRows({}, from, from, {}, to > from ? to + 1 : to);
    m_sessions.move(from, to);
    endMoveRows();
    scheduleSave();
}

int SessionManager::importFile(const QUrl &url)
{
    QFile file(urlToPath(url));
    if (!file.open(QIODevice::ReadOnly))
        return -1;
    return importGroups(file.readAll());
}

int SessionManager::importGrsyncSessions()
{
    QFile file(GrsyncFormat::defaultSessionStore());
    if (!file.open(QIODevice::ReadOnly))
        return -1;
    return importGroups(file.readAll());
}

int SessionManager::importGroups(const QByteArray &data)
{
    int imported = 0;
    const QList<GrsyncFormat::Group> groups = GrsyncFormat::parse(data);
    for (const auto &group : groups) {
        // Grsync files may contain non-session groups; a session always has paths.
        if (!group.entries.contains(u"text_source"_s) && !group.entries.contains(u"text_dest"_s))
            continue;
        Session *session = create(group.name);
        session->loadGrsync(group.entries);
        ++imported;
    }
    return imported;
}

bool SessionManager::exportSession(Session *session, const QUrl &url)
{
    if (!session)
        return false;
    QSaveFile file(urlToPath(url));
    if (!file.open(QIODevice::WriteOnly))
        return false;
    file.write(GrsyncFormat::write({{session->name(), session->toGrsync()}}));
    return file.commit();
}

QString SessionManager::uniqueName(const QString &base) const
{
    const auto taken = [this](const QString &name) {
        for (Session *session : m_sessions) {
            if (session->name().compare(name, Qt::CaseInsensitive) == 0)
                return true;
        }
        return false;
    };
    if (!taken(base))
        return base;
    for (int i = 2;; ++i) {
        const QString candidate = u"%1 %2"_s.arg(base).arg(i);
        if (!taken(candidate))
            return candidate;
    }
}

QString SessionManager::urlToPath(const QUrl &url)
{
    return url.isLocalFile() ? url.toLocalFile() : url.toString();
}

QUrl SessionManager::pathToUrl(const QString &path)
{
    if (path.isEmpty() || Options::isRemotePath(path))
        return {};
    return QUrl::fromLocalFile(KShell::tildeExpand(path));
}

bool SessionManager::isRemotePath(const QString &path)
{
    return Options::isRemotePath(path);
}

bool SessionManager::isDirectory(const QString &path)
{
    return !Options::isRemotePath(path) && QFileInfo(KShell::tildeExpand(path)).isDir();
}

QString SessionManager::displayName(const QString &path)
{
    QString p = path.trimmed();
    while (p.size() > 1 && p.endsWith(u'/'))
        p.chop(1);
    if (p.isEmpty())
        return {};
    if (p == u"/")
        return i18nc("@label the filesystem root", "Root");
    // host:path → last component of path, or the host itself.
    if (Options::isRemotePath(p) && !p.startsWith(u"rsync://")) {
        const qsizetype colon = p.indexOf(u':');
        const QString remote = p.mid(colon + 1);
        if (remote.isEmpty() || remote == u"~" || remote == u"/")
            return p.left(colon);
        p = remote;
    }
    const QString name = p.section(u'/', -1);
    if (name == u"~")
        return i18nc("@label the user's home folder", "Home");
    return name;
}

QString SessionManager::prettyPath(const QString &path)
{
    const QString home = QDir::homePath();
    if (path == home || path.startsWith(home + u'/'))
        return u'~' + path.mid(home.size());
    return path;
}

void SessionManager::load()
{
    const QStringList order = m_config->group(u"General"_s).readEntry("Order", QStringList());
    QStringList groups = m_config->groupList().filter(s_groupPrefix);
    // Known order first, then anything not yet listed.
    QStringList ids;
    for (const QString &id : order) {
        if (groups.removeOne(s_groupPrefix + id))
            ids << id;
    }
    for (const QString &group : std::as_const(groups))
        ids << group.mid(s_groupPrefix.size());

    for (const QString &id : std::as_const(ids)) {
        auto *session = new Session(id, this);
        session->load(m_config->group(s_groupPrefix + id));
        m_sessions << session;
        connect(session, &Session::modified, this, [this, session] {
            onSessionChanged(session);
        });
    }
}

void SessionManager::add(Session *session)
{
    beginInsertRows({}, int(m_sessions.size()), int(m_sessions.size()));
    m_sessions << session;
    connect(session, &Session::modified, this, [this, session] {
        onSessionChanged(session);
    });
    endInsertRows();
    Q_EMIT countChanged();
}

void SessionManager::onSessionChanged(Session *session)
{
    const QModelIndex idx = index(indexOf(session));
    if (idx.isValid())
        Q_EMIT dataChanged(idx, idx);
    scheduleSave();
}

void SessionManager::scheduleSave()
{
    m_saveTimer.start();
}

void SessionManager::save()
{
    QStringList order;
    for (Session *session : std::as_const(m_sessions)) {
        KConfigGroup group = m_config->group(s_groupPrefix + session->id());
        session->save(group);
        order << session->id();
    }
    m_config->group(u"General"_s).writeEntry("Order", order);
    m_config->sync();
}
