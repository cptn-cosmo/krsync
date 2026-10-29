// SPDX-License-Identifier: GPL-3.0-or-later

#include "desktopintegration.h"

#include <KNotification>

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QGuiApplication>

using namespace Qt::StringLiterals;

static const QString s_inhibitService = u"org.freedesktop.PowerManagement.Inhibit"_s;
static const QString s_inhibitPath = u"/org/freedesktop/PowerManagement/Inhibit"_s;

DesktopIntegration::DesktopIntegration(QObject *parent)
    : QObject(parent)
{
}

DesktopIntegration::~DesktopIntegration()
{
    clearTaskProgress();
    uninhibitSleep();
}

void DesktopIntegration::setTaskProgress(double progress)
{
    m_progressVisible = true;
    sendLauncherUpdate({
        {u"progress"_s, std::clamp(progress, 0.0, 1.0)},
        {u"progress-visible"_s, true},
    });
}

void DesktopIntegration::clearTaskProgress()
{
    if (!m_progressVisible)
        return;
    m_progressVisible = false;
    sendLauncherUpdate({
        {u"progress"_s, 0.0},
        {u"progress-visible"_s, false},
    });
}

void DesktopIntegration::sendLauncherUpdate(const QVariantMap &properties)
{
    auto message = QDBusMessage::createSignal(u"/org/kde/krsync/UnityLauncher"_s, u"com.canonical.Unity.LauncherEntry"_s, u"Update"_s);
    message << u"application://%1.desktop"_s.arg(QGuiApplication::desktopFileName()) << properties;
    QDBusConnection::sessionBus().send(message);
}

void DesktopIntegration::inhibitSleep(const QString &reason)
{
    if (m_inhibitCookie || m_inhibitPending)
        return;
    m_inhibitPending = true;
    m_releaseWhenReady = false;

    auto message = QDBusMessage::createMethodCall(s_inhibitService, s_inhibitPath, s_inhibitService, u"Inhibit"_s);
    message << QGuiApplication::applicationDisplayName() << reason;
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *call) {
        call->deleteLater();
        m_inhibitPending = false;
        const QDBusPendingReply<uint> reply = *call;
        if (reply.isError())
            return;
        m_inhibitCookie = reply.value();
        // The sync may have ended before the reply arrived.
        if (m_releaseWhenReady)
            uninhibitSleep();
    });
}

void DesktopIntegration::uninhibitSleep()
{
    if (m_inhibitPending) {
        m_releaseWhenReady = true;
        return;
    }
    if (!m_inhibitCookie)
        return;
    auto message = QDBusMessage::createMethodCall(s_inhibitService, s_inhibitPath, s_inhibitService, u"UnInhibit"_s);
    message << m_inhibitCookie;
    QDBusConnection::sessionBus().asyncCall(message);
    m_inhibitCookie = 0;
}

void DesktopIntegration::notify(const QString &eventId, const QString &title, const QString &text, const QString &iconName)
{
    auto *notification = new KNotification(eventId, KNotification::CloseOnTimeout);
    notification->setTitle(title);
    notification->setText(text);
    notification->setIconName(iconName);
    notification->sendEvent();
}
