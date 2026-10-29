// SPDX-License-Identifier: GPL-3.0-or-later

#include <QApplication>
#include <QCommandLineParser>
#include <QDir>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QUrl>

#include <KAboutData>
#include <KCrash>
#include <KDBusService>
#include <KIconTheme>
#include <KLocalizedQmlContext>
#include <KLocalizedString>

#include "krsync-version.h"
#include "krsyncconfig.h"
#include "rsyncrunner.h"
#include "session.h"
#include "sessionmanager.h"

using namespace Qt::StringLiterals;

namespace
{
struct CommandLine {
    QString runSession;
    bool simulate = false;
    bool closeWhenDone = false;
    QStringList imports;
};

void addOptions(QCommandLineParser &parser)
{
    parser.addOption({{u"e"_s, u"execute"_s}, i18n("Synchronize the given session immediately."), i18n("session")});
    parser.addOption({{u"s"_s, u"simulate"_s}, i18n("Simulate the given session immediately (dry run)."), i18n("session")});
    parser.addOption({{u"c"_s, u"close-when-done"_s}, i18n("Quit after the session started with --execute or --simulate finishes.")});
    parser.addOption({{u"i"_s, u"import"_s}, i18n("Import sessions from a Grsync session file."), i18n("file")});
    parser.addPositionalArgument(u"files"_s, i18n("Grsync session files to import."), u"[files…]"_s);
}

CommandLine readCommandLine(const QCommandLineParser &parser, const QString &workingDir)
{
    CommandLine cmd;
    if (parser.isSet(u"execute"_s)) {
        cmd.runSession = parser.value(u"execute"_s);
    } else if (parser.isSet(u"simulate"_s)) {
        cmd.runSession = parser.value(u"simulate"_s);
        cmd.simulate = true;
    }
    cmd.closeWhenDone = parser.isSet(u"close-when-done"_s);
    const QStringList files = parser.values(u"import"_s) + parser.positionalArguments();
    for (const QString &file : files)
        cmd.imports << QDir(workingDir).absoluteFilePath(file);
    return cmd;
}

void apply(const CommandLine &cmd)
{
    auto *manager = SessionManager::instance();
    for (const QString &file : cmd.imports) {
        if (manager->importFile(QUrl::fromLocalFile(file)) < 0)
            qWarning().noquote() << i18n("Could not import “%1”.", file);
    }

    if (cmd.runSession.isEmpty())
        return;
    Session *session = manager->find(cmd.runSession);
    if (!session) {
        qWarning().noquote() << i18n("No session named “%1”.", cmd.runSession);
        if (cmd.closeWhenDone)
            QCoreApplication::exit(2);
        return;
    }
    auto *runner = RsyncRunner::instance();
    if (cmd.closeWhenDone) {
        QObject::connect(runner, &RsyncRunner::runFinished, qApp, [](bool success) {
            QCoreApplication::exit(success ? 0 : 1);
        }, Qt::SingleShotConnection);
    }
    runner->start(session, cmd.simulate);
}
}

int main(int argc, char *argv[])
{
    KIconTheme::initTheme();
    QApplication app(argc, argv);
    KLocalizedString::setApplicationDomain("krsync");

    // Native look on Plasma, with a sane fallback elsewhere.
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE"))
        QQuickStyle::setStyle(u"org.kde.desktop"_s);
    if (qEnvironmentVariableIsEmpty("QT_STYLE_OVERRIDE"))
        QApplication::setStyle(u"breeze"_s);

    KAboutData about(u"krsync"_s,
                     i18n("KRsync"),
                     QStringLiteral(KRSYNC_VERSION_STRING),
                     i18n("Synchronize folders with rsync"),
                     KAboutLicense::GPL_V3,
                     i18n("© 2026 KRsync contributors"));
    about.setDesktopFileName(u"org.kde.krsync"_s);
    about.setProgramLogo(QIcon::fromTheme(u"org.kde.krsync"_s, QIcon::fromTheme(u"folder-sync"_s)));
    about.addCredit(i18n("Piero Orsoni"), i18n("Author of Grsync, which inspired KRsync"));
    KAboutData::setApplicationData(about);
    QGuiApplication::setWindowIcon(QIcon::fromTheme(u"org.kde.krsync"_s, QIcon::fromTheme(u"folder-sync"_s)));

    KCrash::initialize();

    QCommandLineParser parser;
    about.setupCommandLine(&parser);
    addOptions(parser);
    parser.process(app);
    about.processCommandLine(&parser);

    KDBusService service(KDBusService::Unique);

    QQmlApplicationEngine engine;
    KLocalization::setupLocalizedContext(&engine);
    qmlRegisterSingletonInstance("org.kde.krsync.config", 1, 0, "Config", KRsyncConfig::self());

    QObject::connect(&app, &QCoreApplication::aboutToQuit, [] {
        SessionManager::instance()->save();
        KRsyncConfig::self()->save();
    });

    engine.loadFromModule("org.kde.krsync", "Main");
    if (engine.rootObjects().isEmpty())
        return 1;

    // A second launch hands its arguments to this instance and brings it forward.
    QObject::connect(&service, &KDBusService::activateRequested, &engine, [&engine](const QStringList &arguments, const QString &workingDir) {
        QCommandLineParser remote;
        addOptions(remote);
        remote.parse(arguments);
        apply(readCommandLine(remote, workingDir));
        if (auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().constFirst())) {
            window->show();
            window->raise();
            window->requestActivate();
        }
    });

    apply(readCommandLine(parser, QDir::currentPath()));

    return app.exec();
}
