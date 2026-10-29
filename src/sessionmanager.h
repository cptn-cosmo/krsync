// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QAbstractListModel>
#include <QQmlEngine>
#include <QTimer>

#include <KSharedConfig>

class Session;

class SessionManager : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(bool grsyncSessionsAvailable READ grsyncSessionsAvailable CONSTANT)

public:
    enum Roles {
        SessionRole = Qt::UserRole + 1,
        NameRole,
        SourceRole,
        DestinationRole,
        RemoteRole,
        LastRunRole,
        LastResultRole,
    };
    Q_ENUM(Roles)

    static SessionManager *instance();
    static SessionManager *create(QQmlEngine *, QJSEngine *);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    bool grsyncSessionsAvailable() const;

    Q_INVOKABLE Session *get(int row) const;
    Q_INVOKABLE int indexOf(Session *session) const;
    Q_INVOKABLE Session *findById(const QString &id) const;
    // Matches by id first, then by name (case-insensitive), like `grsync -e`.
    Q_INVOKABLE Session *find(const QString &idOrName) const;

    Q_INVOKABLE Session *create(const QString &name);
    Q_INVOKABLE Session *duplicate(Session *session);
    Q_INVOKABLE void remove(Session *session);
    Q_INVOKABLE void move(int from, int to);

    // Return the number of sessions imported, or -1 on failure.
    Q_INVOKABLE int importFile(const QUrl &url);
    Q_INVOKABLE int importGrsyncSessions();
    Q_INVOKABLE bool exportSession(Session *session, const QUrl &url);

    Q_INVOKABLE QString uniqueName(const QString &base) const;

    // Write pending changes to disk immediately.
    void save();

    // Small path helpers for QML.
    Q_INVOKABLE static QString urlToPath(const QUrl &url);
    Q_INVOKABLE static QUrl pathToUrl(const QString &path);
    Q_INVOKABLE static bool isRemotePath(const QString &path);
    Q_INVOKABLE static bool isDirectory(const QString &path);
    Q_INVOKABLE static QString displayName(const QString &path);
    Q_INVOKABLE static QString prettyPath(const QString &path);

Q_SIGNALS:
    void countChanged();

private:
    explicit SessionManager(QObject *parent = nullptr);

    void load();
    void scheduleSave();
    void add(Session *session);
    void onSessionChanged(Session *session);
    int importGroups(const QByteArray &data);

    KSharedConfig::Ptr m_config;
    QList<Session *> m_sessions;
    QTimer m_saveTimer;
};
