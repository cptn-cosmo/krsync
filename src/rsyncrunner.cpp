// SPDX-License-Identifier: GPL-3.0-or-later

#include "rsyncrunner.h"

#include "desktopintegration.h"
#include "krsyncconfig.h"

#include <KLocalizedString>
#include <KShell>

#include <QGuiApplication>
#include <QRegularExpression>
#include <QSaveFile>

#include <csignal>
#include <unistd.h>

using namespace Qt::StringLiterals;

RsyncRunner *RsyncRunner::instance()
{
    static RsyncRunner *runner = new RsyncRunner;
    return runner;
}

RsyncRunner *RsyncRunner::create(QQmlEngine *, QJSEngine *)
{
    auto *runner = instance();
    QQmlEngine::setObjectOwnership(runner, QQmlEngine::CppOwnership);
    return runner;
}

RsyncRunner::RsyncRunner(QObject *parent)
    : QObject(parent)
    , m_log(new LogModel(this))
    , m_desktop(new DesktopIntegration(this))
{
    m_tick.setInterval(250);
    connect(&m_tick, &QTimer::timeout, this, &RsyncRunner::emitProgress);
}

RsyncRunner::State RsyncRunner::state() const
{
    return m_state;
}

bool RsyncRunner::isActive() const
{
    return m_state == PreCommand || m_state == Syncing || m_state == PostCommand;
}

bool RsyncRunner::isFinished() const
{
    return m_state == Succeeded || m_state == Failed || m_state == Cancelled;
}

bool RsyncRunner::isPaused() const
{
    return m_paused;
}

bool RsyncRunner::canPause() const
{
    // A root-owned rsync cannot be signalled from here.
    return m_state == Syncing && !m_superuser;
}

Session *RsyncRunner::session() const
{
    return m_session;
}

bool RsyncRunner::isSimulation() const
{
    return m_simulation;
}

LogModel *RsyncRunner::log() const
{
    return m_log;
}

QString RsyncRunner::commandLine() const
{
    return m_commandLine;
}

double RsyncRunner::progress() const
{
    return m_progress;
}

qint64 RsyncRunner::bytesTransferred() const
{
    return m_bytes;
}

double RsyncRunner::speed() const
{
    return m_speed;
}

qint64 RsyncRunner::eta() const
{
    return m_eta;
}

qint64 RsyncRunner::elapsed() const
{
    if (m_finalElapsed >= 0)
        return m_finalElapsed;
    if (!m_clock.isValid())
        return 0;
    const qint64 pausedNow = m_paused ? m_pauseClock.elapsed() : 0;
    return (m_clock.elapsed() - m_pausedFor - pausedNow) / 1000;
}

QString RsyncRunner::currentFile() const
{
    return m_currentFile;
}

int RsyncRunner::filesTransferred() const
{
    return m_filesTransferred;
}

int RsyncRunner::filesToCheck() const
{
    return m_filesToCheck;
}

int RsyncRunner::filesTotal() const
{
    return m_filesTotal;
}

int RsyncRunner::deletedCount() const
{
    return m_deleted;
}

int RsyncRunner::errorCount() const
{
    return m_errors;
}

int RsyncRunner::exitCode() const
{
    return m_exitCode;
}

QString RsyncRunner::resultTitle() const
{
    return m_resultTitle;
}

QString RsyncRunner::resultMessage() const
{
    return m_resultMessage;
}

QVariantMap RsyncRunner::stats() const
{
    return m_stats;
}

void RsyncRunner::setState(State state)
{
    if (m_state == state)
        return;
    m_state = state;
    Q_EMIT stateChanged();
}

void RsyncRunner::start(Session *session, bool simulate)
{
    if (!session || isActive())
        return;

    m_session = session;
    m_simulation = simulate;
    m_superuser = session->option(u"superuser"_s).toBool();
    m_cancelRequested = false;
    m_paused = false;
    m_progress = -1;
    m_bytes = 0;
    m_speed = 0;
    m_eta = -1;
    m_currentFile.clear();
    m_filesTransferred = 0;
    m_filesToCheck = 0;
    m_filesTotal = 0;
    m_deleted = 0;
    m_errors = 0;
    m_exitCode = -1;
    m_resultTitle.clear();
    m_resultMessage.clear();
    m_stats.clear();
    m_pendingState = Idle;
    m_pausedFor = 0;
    m_finalElapsed = -1;
    m_log->clear();

    const QString rsync = KRsyncConfig::self()->rsyncPath();
    m_commandLine = KShell::joinArgs(QStringList{session->program(rsync)} + session->arguments(rsync, simulate, false));
    Q_EMIT sessionChanged();
    Q_EMIT pausedChanged();

    m_clock.start();
    m_tick.start();
    if (!simulate && KRsyncConfig::self()->inhibitSleep())
        m_desktop->inhibitSleep(i18n("Synchronizing “%1”", session->name()));
    Q_EMIT started();

    const QString pre = session->option(u"preCommand"_s).toString().trimmed();
    if (!simulate && session->option(u"preCommandEnabled"_s).toBool() && !pre.isEmpty())
        runShell(pre, PreCommand);
    else
        startRsync();
}

QProcessEnvironment RsyncRunner::environment() const
{
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    // Keep the user's character set so file names print unescaped, but force
    // C number formatting so progress figures are parseable.
    if (env.contains(u"LC_ALL"_s)) {
        env.insert(u"LANG"_s, env.value(u"LC_ALL"_s));
        env.remove(u"LC_ALL"_s);
    }
    env.insert(u"LC_NUMERIC"_s, u"C"_s);
    env.insert(u"LC_MESSAGES"_s, u"C"_s);

    if (m_session) {
        env.insert(u"KRSYNC_SESSION"_s, m_session->name());
        env.insert(u"KRSYNC_SOURCE"_s, m_session->source());
        env.insert(u"KRSYNC_DESTINATION"_s, m_session->destination());
    }
    env.insert(u"KRSYNC_DRY_RUN"_s, m_simulation ? u"1"_s : u"0"_s);
    if (m_exitCode >= 0)
        env.insert(u"KRSYNC_EXIT_CODE"_s, QString::number(m_exitCode));
    return env;
}

static void becomeGroupLeader()
{
    // Own process group, so pause/cancel reach rsync's forked helpers and ssh too.
    ::setpgid(0, 0);
}

void RsyncRunner::runShell(const QString &command, State phase)
{
    setState(phase);
    m_log->append(LogModel::Command, command);

    m_process = new QProcess(this);
    m_process->setProcessEnvironment(environment());
    m_process->setChildProcessModifier(becomeGroupLeader);
    m_process->setProgram(u"/bin/sh"_s);
    m_process->setArguments({u"-c"_s, command});
    connect(m_process, &QProcess::readyReadStandardOutput, this, &RsyncRunner::readStdout);
    connect(m_process, &QProcess::readyReadStandardError, this, &RsyncRunner::readStderr);
    connect(m_process, &QProcess::finished, this, &RsyncRunner::onShellFinished);
    m_process->start();
}

void RsyncRunner::onShellFinished(int exitCode, QProcess::ExitStatus status)
{
    readStdout();
    readStderr();
    m_process->deleteLater();
    m_process = nullptr;

    const bool ok = status == QProcess::NormalExit && exitCode == 0;
    if (!ok && !m_cancelRequested)
        m_log->append(LogModel::Error, i18n("The command exited with code %1.", exitCode));

    if (m_state == PreCommand) {
        if (m_cancelRequested) {
            finish(Cancelled, i18n("Synchronization cancelled"), QString());
            return;
        }
        if (!ok && m_session && m_session->option(u"preAbortOnFailure"_s).toBool()) {
            ++m_errors;
            finish(Failed,
                   i18n("Pre-sync command failed"),
                   i18n("The command run before synchronizing exited with code %1, so rsync was not started.", exitCode));
            return;
        }
        startRsync();
        return;
    }

    // Post-sync command finished; report the rsync outcome decided earlier.
    if (!ok)
        ++m_errors;
    finish(m_pendingState, m_resultTitle, m_resultMessage);
}

void RsyncRunner::startRsync()
{
    if (!m_session) {
        finish(Failed, i18n("Synchronization failed"), i18n("The session was removed."));
        return;
    }
    setState(Syncing);

    const QString rsync = KRsyncConfig::self()->rsyncPath();
    QStringList args = m_session->arguments(rsync, m_simulation, true);
    if (KRsyncConfig::self()->accurateProgress())
        args.insert(m_superuser ? 1 : 0, u"--no-inc-recursive"_s);

    m_log->append(LogModel::Command, KShell::joinArgs(QStringList{m_session->program(rsync)} + args));

    m_process = new QProcess(this);
    m_process->setProcessEnvironment(environment());
    if (!m_superuser)
        m_process->setChildProcessModifier(becomeGroupLeader);
    m_process->setProgram(m_session->program(rsync));
    m_process->setArguments(args);
    connect(m_process, &QProcess::readyReadStandardOutput, this, &RsyncRunner::readStdout);
    connect(m_process, &QProcess::readyReadStandardError, this, &RsyncRunner::readStderr);
    connect(m_process, &QProcess::finished, this, &RsyncRunner::onRsyncFinished);
    connect(m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart)
            return;
        const QString program = m_process->program();
        m_process->deleteLater();
        m_process = nullptr;
        ++m_errors;
        m_log->append(LogModel::Error, i18n("Could not start “%1”.", program));
        finish(Failed,
               i18n("Could not start rsync"),
               i18n("“%1” could not be run. Make sure rsync is installed, or set its location in the settings.", program));
    });
    m_process->start();
}

void RsyncRunner::onRsyncFinished(int exitCode, QProcess::ExitStatus status)
{
    readStdout();
    readStderr();
    // Leftovers without a trailing newline.
    if (!m_stdoutBuffer.isEmpty())
        handleLine(QString::fromUtf8(std::exchange(m_stdoutBuffer, {})));
    if (!m_stderrBuffer.isEmpty()) {
        ++m_errors;
        m_log->append(LogModel::Error, QString::fromUtf8(std::exchange(m_stderrBuffer, {})));
    }
    m_process->deleteLater();
    m_process = nullptr;

    if (m_paused) {
        m_paused = false;
        Q_EMIT pausedChanged();
    }

    m_exitCode = status == QProcess::CrashExit ? 20 : exitCode;
    const bool success = !m_cancelRequested && (m_exitCode == 0 || m_exitCode == 24);

    if (m_cancelRequested) {
        m_pendingState = Cancelled;
        m_resultTitle = m_simulation ? i18n("Simulation cancelled") : i18n("Synchronization cancelled");
        m_resultMessage = i18n("Files that were already transferred have been kept.");
    } else if (success) {
        m_pendingState = Succeeded;
        m_resultTitle = m_simulation ? i18n("Simulation complete") : i18n("Synchronization complete");
        if (m_exitCode == 24)
            m_resultMessage = describeExitCode(24);
    } else {
        m_pendingState = Failed;
        m_resultTitle = m_simulation ? i18n("Simulation failed") : i18n("Synchronization failed");
        m_resultMessage = describeExitCode(m_exitCode);
        if (m_superuser && m_exitCode == 126) {
            m_resultTitle = i18n("Authentication cancelled");
            m_resultMessage = i18n("Administrator privileges are required for this session.");
        } else if (m_superuser && m_exitCode == 127) {
            m_resultTitle = i18n("Not authorized");
            m_resultMessage = i18n("You are not allowed to run rsync as administrator.");
        }
    }

    const QString post = m_session ? m_session->option(u"postCommand"_s).toString().trimmed() : QString();
    const bool runPost = m_session && !m_simulation && !m_cancelRequested && m_session->option(u"postCommandEnabled"_s).toBool() && !post.isEmpty()
        && (success || !m_session->option(u"postOnlyOnSuccess"_s).toBool());
    if (runPost)
        runShell(post, PostCommand);
    else
        finish(m_pendingState, m_resultTitle, m_resultMessage);
}

void RsyncRunner::finish(State state, const QString &title, const QString &message)
{
    m_finalElapsed = elapsed();
    m_tick.stop();
    m_log->flush();
    m_resultTitle = title;
    m_resultMessage = message;
    if (state == Succeeded) {
        m_progress = 1;
        m_eta = 0;
    }
    m_speed = 0;
    m_desktop->clearTaskProgress();
    m_desktop->uninhibitSleep();

    if (m_session) {
        if (state == Failed && m_exitCode <= 0)
            m_exitCode = 255; // failed outside rsync, e.g. in the pre-sync command
        if (m_exitCode >= 0)
            m_session->recordRun(state == Succeeded ? 0 : m_exitCode, m_simulation);
    }

    if (KRsyncConfig::self()->notifyWhenDone() && QGuiApplication::applicationState() != Qt::ApplicationActive && state != Cancelled) {
        const QString name = m_session ? m_session->name() : QString();
        if (state == Succeeded)
            DesktopIntegration::notify(u"finished"_s, title, name, u"emblem-success"_s);
        else
            DesktopIntegration::notify(u"failed"_s, title, message.isEmpty() ? name : u"%1: %2"_s.arg(name, message), u"emblem-error"_s);
    }

    Q_EMIT progressChanged();
    setState(state);
    Q_EMIT runFinished(state == Succeeded);
}

void RsyncRunner::cancel()
{
    if (!isActive() || !m_process)
        return;
    m_cancelRequested = true;
    m_log->append(LogModel::Info, i18n("Cancelling…"));

    if (m_paused)
        resume();

    if (m_superuser && m_state == Syncing) {
        // Unable to signal root: drop the pipes so rsync dies on its next write.
        m_process->closeReadChannel(QProcess::StandardOutput);
        m_process->closeReadChannel(QProcess::StandardError);
        m_process->terminate();
        return;
    }

    signalGroup(SIGTERM);
    QPointer<QProcess> process = m_process;
    QTimer::singleShot(5000, this, [this, process] {
        if (process && process == m_process && process->state() != QProcess::NotRunning)
            signalGroup(SIGKILL);
    });
}

void RsyncRunner::pause()
{
    if (!canPause() || m_paused)
        return;
    signalGroup(SIGSTOP);
    m_paused = true;
    m_pauseClock.start();
    m_speed = 0;
    m_desktop->uninhibitSleep();
    Q_EMIT pausedChanged();
    emitProgress();
}

void RsyncRunner::resume()
{
    if (!m_paused)
        return;
    signalGroup(SIGCONT);
    m_pausedFor += m_pauseClock.elapsed();
    m_paused = false;
    if (!m_simulation && KRsyncConfig::self()->inhibitSleep() && m_session)
        m_desktop->inhibitSleep(i18n("Synchronizing “%1”", m_session->name()));
    Q_EMIT pausedChanged();
    emitProgress();
}

void RsyncRunner::signalGroup(int signal)
{
    if (!m_process)
        return;
    const qint64 pid = m_process->processId();
    if (pid > 0)
        ::kill(-pid_t(pid), signal);
}

void RsyncRunner::dismiss()
{
    if (!isFinished())
        return;
    setState(Idle);
}

bool RsyncRunner::saveLog(const QUrl &url) const
{
    QSaveFile file(url.isLocalFile() ? url.toLocalFile() : url.toString());
    if (!file.open(QIODevice::WriteOnly))
        return false;
    file.write(logText().toUtf8());
    return file.commit();
}

QString RsyncRunner::logText() const
{
    m_log->flush();
    return m_log->toPlainText();
}

static QList<QByteArray> takeLines(QByteArray &buffer)
{
    QList<QByteArray> lines;
    qsizetype start = 0;
    for (qsizetype i = 0; i < buffer.size(); ++i) {
        const char c = buffer.at(i);
        if (c == '\n' || c == '\r') {
            lines << buffer.mid(start, i - start);
            start = i + 1;
        }
    }
    buffer.remove(0, start);
    return lines;
}

void RsyncRunner::readStdout()
{
    if (!m_process)
        return;
    m_stdoutBuffer += m_process->readAllStandardOutput();
    const bool shell = m_state == PreCommand || m_state == PostCommand;
    const QList<QByteArray> lines = takeLines(m_stdoutBuffer);
    for (const QByteArray &raw : lines) {
        const QString line = QString::fromUtf8(raw);
        if (shell) {
            if (!line.trimmed().isEmpty())
                m_log->append(LogModel::Info, line);
        } else {
            handleLine(line);
        }
    }
}

void RsyncRunner::readStderr()
{
    if (!m_process)
        return;
    m_stderrBuffer += m_process->readAllStandardError();
    const QList<QByteArray> lines = takeLines(m_stderrBuffer);
    for (const QByteArray &raw : lines) {
        const QString line = QString::fromUtf8(raw).trimmed();
        if (line.isEmpty())
            continue;
        ++m_errors;
        m_log->append(LogModel::Error, line);
    }
}

static double parseNumber(QString text)
{
    text.remove(u',');
    return text.toDouble();
}

static double unitFactor(QStringView unit)
{
    if (unit.isEmpty())
        return 1;
    switch (unit.at(0).toUpper().unicode()) {
    case u'K':
        return 1024.0;
    case u'M':
        return 1024.0 * 1024;
    case u'G':
        return 1024.0 * 1024 * 1024;
    case u'T':
        return 1024.0 * 1024 * 1024 * 1024;
    case u'P':
        return 1024.0 * 1024 * 1024 * 1024 * 1024;
    }
    return 1;
}

bool RsyncRunner::parseProgress(const QString &line)
{
    // "  1,234,567  45%   12.34MB/s    0:00:12 (xfr#5, to-chk=10/100)"
    static const QRegularExpression re(
        uR"(^\s*([\d,.]+)([KMGTP]?)\s+(\d{1,3})%\s+([\d,.]+)([kKMGTP]?)i?B/s\s+(\d+):(\d\d):(\d\d)(?:\s+\(xfr#(\d+),\s*(?:ir|to)-chk=(\d+)/(\d+)\))?\s*$)"_s);
    const auto m = re.match(line);
    if (!m.hasMatch())
        return false;

    m_bytes = qint64(parseNumber(m.captured(1)) * unitFactor(m.captured(2)));
    const int percent = m.captured(3).toInt();
    m_progress = percent / 100.0;
    if (!m_paused)
        m_speed = parseNumber(m.captured(4)) * unitFactor(m.captured(5));

    const qint64 rsyncTime = m.captured(6).toLongLong() * 3600 + m.captured(7).toLongLong() * 60 + m.captured(8).toLongLong();
    if (m.capturedLength(9) > 0) {
        m_filesTransferred = m.captured(9).toInt();
        m_filesToCheck = m.captured(10).toInt();
        m_filesTotal = m.captured(11).toInt();
        // After a file completes rsync prints elapsed time; estimate instead.
        if (percent > 0 && percent < 100 && m_speed > 0) {
            const double total = double(m_bytes) * 100.0 / percent;
            m_eta = qint64((total - m_bytes) / m_speed);
        }
    } else {
        m_eta = rsyncTime;
    }
    return true;
}

void RsyncRunner::parseStatsLine(const QString &line)
{
    static const QList<std::pair<QString, QString>> labels = {
        {u"Number of files"_s, u"files"_s},
        {u"Number of created files"_s, u"createdFiles"_s},
        {u"Number of deleted files"_s, u"deletedFiles"_s},
        {u"Number of regular files transferred"_s, u"transferredFiles"_s},
        {u"Total file size"_s, u"totalSize"_s},
        {u"Total transferred file size"_s, u"transferredSize"_s},
        {u"Literal data"_s, u"literalData"_s},
        {u"Matched data"_s, u"matchedData"_s},
    };
    static const QRegularExpression labelled(uR"(^([A-Za-z ]+):\s+([\d,.]+))"_s);
    static const QRegularExpression sent(uR"(^sent ([\d,.]+) bytes\s+received ([\d,.]+) bytes\s+([\d,.]+) bytes/sec)"_s);
    static const QRegularExpression total(uR"(^total size is ([\d,.]+)\s+speedup is ([\d,.]+))"_s);

    if (const auto m = labelled.match(line); m.hasMatch()) {
        for (const auto &[label, key] : labels) {
            if (m.captured(1) == label)
                m_stats.insert(key, parseNumber(m.captured(2)));
        }
    } else if (const auto m = sent.match(line); m.hasMatch()) {
        m_stats.insert(u"sent"_s, parseNumber(m.captured(1)));
        m_stats.insert(u"received"_s, parseNumber(m.captured(2)));
        m_stats.insert(u"rate"_s, parseNumber(m.captured(3)));
    } else if (const auto m = total.match(line); m.hasMatch()) {
        m_stats.insert(u"totalSize"_s, parseNumber(m.captured(1)));
        m_stats.insert(u"speedup"_s, parseNumber(m.captured(2)));
    }
}

void RsyncRunner::handleLine(const QString &line)
{
    if (parseProgress(line))
        return;
    const QString trimmed = line.trimmed();
    if (trimmed.isEmpty())
        return;
    if (trimmed == u"done") {
        m_log->append(LogModel::Info, trimmed);
        return;
    }

    static const QStringList infoPrefixes = {
        u"sending incremental file list"_s,
        u"receiving incremental file list"_s,
        u"building file list"_s,
        u"receiving file list"_s,
        u"sending file list"_s,
        u"created directory"_s,
        u"skipping "_s,
        u"Number of "_s,
        u"Total "_s,
        u"Literal data:"_s,
        u"Matched data:"_s,
        u"File list "_s,
        u"sent "_s,
        u"total size is "_s,
        u"delta-transmission "_s,
        u"(DRY RUN)"_s,
    };
    for (const QString &prefix : infoPrefixes) {
        if (trimmed.startsWith(prefix)) {
            parseStatsLine(trimmed);
            m_log->append(LogModel::Info, trimmed);
            return;
        }
    }

    // Itemized output: "*deleting   path" or ">f+++++++++ path".
    static const QRegularExpression itemized(uR"(^([<>ch.*][fdLDS][^ ]{7,9}|\*deleting)\s+(.+)$)"_s);
    QString name = trimmed;
    bool deletion = trimmed.startsWith(u"deleting "_s);
    if (deletion) {
        name = trimmed.mid(9);
    } else if (const auto m = itemized.match(line); m.hasMatch()) {
        name = m.captured(2);
        deletion = m.captured(1) == u"*deleting";
    }

    if (deletion) {
        ++m_deleted;
        m_log->append(LogModel::Deletion, name);
        return;
    }
    if (name.endsWith(u'/')) {
        m_log->append(LogModel::Directory, trimmed);
        return;
    }
    m_currentFile = name;
    m_log->append(LogModel::Transfer, trimmed);
}

void RsyncRunner::emitProgress()
{
    if (isActive() && m_progress >= 0)
        m_desktop->setTaskProgress(m_progress);
    Q_EMIT progressChanged();
}

QString RsyncRunner::describeExitCode(int code)
{
    switch (code) {
    case 0:
        return i18n("Success.");
    case 1:
        return i18n("Syntax or usage error. Check the additional options.");
    case 2:
        return i18n("Protocol incompatibility between the local and remote rsync.");
    case 3:
        return i18n("Error selecting input or output files or folders.");
    case 4:
        return i18n("The requested action is not supported by this version of rsync.");
    case 5:
        return i18n("Error starting the client-server protocol.");
    case 6:
        return i18n("The rsync daemon was unable to append to its log file.");
    case 10:
        return i18n("Socket input/output error.");
    case 11:
        return i18n("File input/output error. Is the destination full or read-only?");
    case 12:
        return i18n("Error in the rsync protocol data stream. The connection may have dropped.");
    case 13:
        return i18n("Error with program diagnostics.");
    case 14:
        return i18n("Error in inter-process communication.");
    case 20:
        return i18n("rsync was interrupted.");
    case 21:
        return i18n("An error was returned by waitpid().");
    case 22:
        return i18n("rsync ran out of memory.");
    case 23:
        return i18n("Some files could not be transferred. See the errors in the log.");
    case 24:
        return i18n("Some source files vanished before they could be transferred.");
    case 25:
        return i18n("The maximum number of deletions was reached, so some files were not deleted.");
    case 30:
        return i18n("Timed out while sending or receiving data.");
    case 35:
        return i18n("Timed out waiting for the rsync daemon.");
    case 255:
        return i18n("The remote shell failed. Check the host name, your credentials and the network connection.");
    }
    return i18n("rsync exited with code %1.", code);
}
