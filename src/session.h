// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QDateTime>
#include <QObject>
#include <QQmlEngine>
#include <QQmlPropertyMap>

class KConfigGroup;

class Session : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Sessions are created by SessionManager")

    Q_PROPERTY(QString id READ id CONSTANT)
    Q_PROPERTY(QString name READ name WRITE setName NOTIFY nameChanged)
    Q_PROPERTY(QQmlPropertyMap *options READ options CONSTANT)
    Q_PROPERTY(QString source READ source NOTIFY optionsChanged)
    Q_PROPERTY(QString destination READ destination NOTIFY optionsChanged)
    Q_PROPERTY(bool sourceRemote READ isSourceRemote NOTIFY optionsChanged)
    Q_PROPERTY(bool destinationRemote READ isDestinationRemote NOTIFY optionsChanged)
    Q_PROPERTY(QString commandLine READ commandLine NOTIFY optionsChanged)
    Q_PROPERTY(QString validationError READ validationError NOTIFY optionsChanged)
    Q_PROPERTY(QDateTime lastRun READ lastRun NOTIFY lastRunChanged)
    Q_PROPERTY(int lastResult READ lastResult NOTIFY lastRunChanged)
    Q_PROPERTY(bool lastRunSimulated READ lastRunSimulated NOTIFY lastRunChanged)

public:
    explicit Session(const QString &id, QObject *parent = nullptr);

    QString id() const;
    QString name() const;
    void setName(const QString &name);

    QQmlPropertyMap *options() const;
    QVariantMap optionValues() const;
    QVariant option(const QString &key) const;
    void setOption(const QString &key, const QVariant &value);

    QString source() const;
    QString destination() const;
    bool isSourceRemote() const;
    bool isDestinationRemote() const;

    QString program(const QString &rsyncPath) const;
    QStringList arguments(const QString &rsyncPath, bool dryRun, bool forExecution) const;
    QString commandLine() const;
    QString validationError() const;

    QDateTime lastRun() const;
    int lastResult() const;
    bool lastRunSimulated() const;
    void recordRun(int exitCode, bool simulated);

    Q_INVOKABLE void swapPaths();
    Q_INVOKABLE void resetOptions();
    Q_INVOKABLE void setSourceContentsOnly(bool contentsOnly);

    void load(const KConfigGroup &group);
    void save(KConfigGroup &group) const;

    void loadGrsync(const QMap<QString, QString> &entries);
    QMap<QString, QString> toGrsync() const;

Q_SIGNALS:
    void nameChanged();
    void optionsChanged();
    void lastRunChanged();
    // Anything that should be persisted changed.
    void modified();

private:
    QString m_id;
    QString m_name;
    QQmlPropertyMap *m_options;
    QDateTime m_lastRun;
    int m_lastResult = -1;
    bool m_lastRunSimulated = false;
};
