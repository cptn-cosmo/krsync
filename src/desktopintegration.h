// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QObject>

/*
 * Talks to the desktop over D-Bus: progress on the task manager entry
 * (LauncherEntry API, shown by Plasma and others) and sleep inhibition
 * while a sync is running.
 */
class DesktopIntegration : public QObject
{
    Q_OBJECT

public:
    explicit DesktopIntegration(QObject *parent = nullptr);
    ~DesktopIntegration() override;

    void setTaskProgress(double progress);
    void clearTaskProgress();

    void inhibitSleep(const QString &reason);
    void uninhibitSleep();

    static void notify(const QString &eventId, const QString &title, const QString &text, const QString &iconName);

private:
    void sendLauncherUpdate(const QVariantMap &properties);

    uint m_inhibitCookie = 0;
    bool m_inhibitPending = false;
    bool m_releaseWhenReady = false;
    bool m_progressVisible = false;
};
