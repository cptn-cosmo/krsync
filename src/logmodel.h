// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QAbstractListModel>
#include <QQmlEngine>
#include <QSortFilterProxyModel>
#include <QTimer>

class LogModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Owned by RsyncRunner")

public:
    enum Kind {
        Command,
        Info,
        Transfer,
        Directory,
        Deletion,
        Error,
    };
    Q_ENUM(Kind)

    enum Roles {
        KindRole = Qt::UserRole + 1,
        TextRole,
    };

    explicit LogModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void append(Kind kind, const QString &text);
    void clear();
    // Push buffered lines to views now.
    void flush();

    QString toPlainText() const;

private:
    struct Entry {
        Kind kind;
        QString text;
    };
    QList<Entry> m_entries;
    QList<Entry> m_pending;
    QTimer m_flushTimer;
};

class LogFilterModel : public QSortFilterProxyModel
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(Filter filter READ filter WRITE setFilter NOTIFY filterChanged)
    Q_PROPERTY(QString searchText READ searchText WRITE setSearchText NOTIFY searchTextChanged)

public:
    enum Filter {
        All,
        Changes,
        Errors,
    };
    Q_ENUM(Filter)

    explicit LogFilterModel(QObject *parent = nullptr);

    Filter filter() const;
    void setFilter(Filter filter);
    QString searchText() const;
    void setSearchText(const QString &text);

Q_SIGNALS:
    void filterChanged();
    void searchTextChanged();

protected:
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const override;

private:
    Filter m_filter = All;
    QString m_searchText;
};
