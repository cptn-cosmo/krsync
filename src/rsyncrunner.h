// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QQmlEngine>
#include <QTimer>

#include "logmodel.h"
#include "session.h"

class DesktopIntegration;

class RsyncRunner : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Runner)
    QML_SINGLETON

    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool active READ isActive NOTIFY stateChanged)
    Q_PROPERTY(bool finished READ isFinished NOTIFY stateChanged)
    Q_PROPERTY(bool paused READ isPaused NOTIFY pausedChanged)
    Q_PROPERTY(bool canPause READ canPause NOTIFY stateChanged)
    Q_PROPERTY(Session *session READ session NOTIFY sessionChanged)
    Q_PROPERTY(bool simulation READ isSimulation NOTIFY sessionChanged)
    Q_PROPERTY(LogModel *log READ log CONSTANT)
    Q_PROPERTY(QString commandLine READ commandLine NOTIFY sessionChanged)

    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(qint64 bytesTransferred READ bytesTransferred NOTIFY progressChanged)
    Q_PROPERTY(double speed READ speed NOTIFY progressChanged)
    Q_PROPERTY(qint64 eta READ eta NOTIFY progressChanged)
    Q_PROPERTY(qint64 elapsed READ elapsed NOTIFY progressChanged)
    Q_PROPERTY(QString currentFile READ currentFile NOTIFY progressChanged)
    Q_PROPERTY(int filesTransferred READ filesTransferred NOTIFY progressChanged)
    Q_PROPERTY(int filesToCheck READ filesToCheck NOTIFY progressChanged)
    Q_PROPERTY(int filesTotal READ filesTotal NOTIFY progressChanged)
    Q_PROPERTY(int deletedCount READ deletedCount NOTIFY progressChanged)
    Q_PROPERTY(int errorCount READ errorCount NOTIFY progressChanged)

    Q_PROPERTY(int exitCode READ exitCode NOTIFY stateChanged)
    Q_PROPERTY(QString resultTitle READ resultTitle NOTIFY stateChanged)
    Q_PROPERTY(QString resultMessage READ resultMessage NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap stats READ stats NOTIFY stateChanged)

public:
    enum State {
        Idle,
        PreCommand,
        Syncing,
        PostCommand,
        Succeeded,
        Failed,
        Cancelled,
    };
    Q_ENUM(State)

    static RsyncRunner *instance();
    static RsyncRunner *create(QQmlEngine *, QJSEngine *);

    State state() const;
    bool isActive() const;
    bool isFinished() const;
    bool isPaused() const;
    bool canPause() const;
    Session *session() const;
    bool isSimulation() const;
    LogModel *log() const;
    QString commandLine() const;

    double progress() const;
    qint64 bytesTransferred() const;
    double speed() const;
    qint64 eta() const;
    qint64 elapsed() const;
    QString currentFile() const;
    int filesTransferred() const;
    int filesToCheck() const;
    int filesTotal() const;
    int deletedCount() const;
    int errorCount() const;

    int exitCode() const;
    QString resultTitle() const;
    QString resultMessage() const;
    QVariantMap stats() const;

    Q_INVOKABLE void start(Session *session, bool simulate);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();
    // Forget a finished run so the UI can return to its idle state.
    Q_INVOKABLE void dismiss();
    Q_INVOKABLE bool saveLog(const QUrl &url) const;
    Q_INVOKABLE QString logText() const;

    static QString describeExitCode(int code);

Q_SIGNALS:
    void stateChanged();
    void pausedChanged();
    void sessionChanged();
    void progressChanged();
    void started();
    void runFinished(bool success);

private:
    explicit RsyncRunner(QObject *parent = nullptr);

    void setState(State state);
    void runShell(const QString &command, State phase);
    void onShellFinished(int exitCode, QProcess::ExitStatus status);
    void startRsync();
    void onRsyncFinished(int exitCode, QProcess::ExitStatus status);
    void finish(State state, const QString &title, const QString &message);

    void readStdout();
    void readStderr();
    void handleLine(const QString &line);
    bool parseProgress(const QString &line);
    void parseStatsLine(const QString &line);
    void emitProgress();
    QProcessEnvironment environment() const;
    void signalGroup(int signal);

    QPointer<Session> m_session;
    LogModel *m_log;
    DesktopIntegration *m_desktop;
    QProcess *m_process = nullptr;
    QByteArray m_stdoutBuffer;
    QByteArray m_stderrBuffer;

    State m_state = Idle;
    bool m_simulation = false;
    bool m_paused = false;
    bool m_cancelRequested = false;
    bool m_superuser = false;
    QString m_commandLine;

    double m_progress = -1;
    qint64 m_bytes = 0;
    double m_speed = 0;
    qint64 m_eta = -1;
    QString m_currentFile;
    int m_filesTransferred = 0;
    int m_filesToCheck = 0;
    int m_filesTotal = 0;
    int m_deleted = 0;
    int m_errors = 0;

    int m_exitCode = -1;
    State m_pendingState = Idle;
    QString m_resultTitle;
    QString m_resultMessage;
    QVariantMap m_stats;

    QElapsedTimer m_clock;
    qint64 m_pausedFor = 0;
    QElapsedTimer m_pauseClock;
    qint64 m_finalElapsed = -1;
    QTimer m_tick;
};
