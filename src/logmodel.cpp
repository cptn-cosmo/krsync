// SPDX-License-Identifier: GPL-3.0-or-later

#include "logmodel.h"

using namespace Qt::StringLiterals;

// Big transfers can print millions of lines; keep memory bounded.
static constexpr qsizetype MaxEntries = 200000;

LogModel::LogModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_flushTimer.setInterval(120);
    m_flushTimer.setSingleShot(true);
    connect(&m_flushTimer, &QTimer::timeout, this, &LogModel::flush);
}

int LogModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : int(m_entries.size());
}

QVariant LogModel::data(const QModelIndex &index, int role) const
{
    if (!checkIndex(index, CheckIndexOption::IndexIsValid))
        return {};
    const Entry &entry = m_entries.at(index.row());
    switch (role) {
    case Qt::DisplayRole:
    case TextRole:
        return entry.text;
    case KindRole:
        return entry.kind;
    }
    return {};
}

QHash<int, QByteArray> LogModel::roleNames() const
{
    return {
        {KindRole, "kind"},
        {TextRole, "text"},
    };
}

void LogModel::append(Kind kind, const QString &text)
{
    m_pending.append({kind, text});
    if (!m_flushTimer.isActive())
        m_flushTimer.start();
}

void LogModel::clear()
{
    m_flushTimer.stop();
    m_pending.clear();
    beginResetModel();
    m_entries.clear();
    endResetModel();
}

void LogModel::flush()
{
    if (m_pending.isEmpty())
        return;

    const qsizetype overflow = m_entries.size() + m_pending.size() - MaxEntries;
    if (overflow > 0) {
        const qsizetype drop = std::min(overflow, m_entries.size());
        if (drop > 0) {
            beginRemoveRows({}, 0, int(drop - 1));
            m_entries.remove(0, drop);
            endRemoveRows();
        }
        if (m_pending.size() > MaxEntries)
            m_pending.remove(0, m_pending.size() - MaxEntries);
    }

    const int first = int(m_entries.size());
    beginInsertRows({}, first, first + int(m_pending.size()) - 1);
    m_entries.append(m_pending);
    endInsertRows();
    m_pending.clear();
}

QString LogModel::toPlainText() const
{
    QString out;
    for (const Entry &entry : m_entries) {
        switch (entry.kind) {
        case Command:
            out += u"$ "_s;
            break;
        case Error:
            out += u"! "_s;
            break;
        default:
            break;
        }
        out += entry.text + u'\n';
    }
    return out;
}

LogFilterModel::LogFilterModel(QObject *parent)
    : QSortFilterProxyModel(parent)
{
}

LogFilterModel::Filter LogFilterModel::filter() const
{
    return m_filter;
}

void LogFilterModel::setFilter(Filter filter)
{
    if (m_filter == filter)
        return;
    beginFilterChange();
    m_filter = filter;
    endFilterChange(QSortFilterProxyModel::Direction::Rows);
    Q_EMIT filterChanged();
}

QString LogFilterModel::searchText() const
{
    return m_searchText;
}

void LogFilterModel::setSearchText(const QString &text)
{
    if (m_searchText == text)
        return;
    beginFilterChange();
    m_searchText = text;
    endFilterChange(QSortFilterProxyModel::Direction::Rows);
    Q_EMIT searchTextChanged();
}

bool LogFilterModel::filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const
{
    const QModelIndex idx = sourceModel()->index(sourceRow, 0, sourceParent);
    const auto kind = static_cast<LogModel::Kind>(idx.data(LogModel::KindRole).toInt());
    switch (m_filter) {
    case All:
        break;
    case Changes:
        if (kind != LogModel::Transfer && kind != LogModel::Deletion)
            return false;
        break;
    case Errors:
        if (kind != LogModel::Error)
            return false;
        break;
    }
    return m_searchText.isEmpty() || idx.data(LogModel::TextRole).toString().contains(m_searchText, Qt::CaseInsensitive);
}
