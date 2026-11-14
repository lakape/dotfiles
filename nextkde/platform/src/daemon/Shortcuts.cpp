#include "KWinShortcutConflicts.h"
#include "Shortcuts.h"

#include <KGlobalAccel>
#include <KShell>
#include <QAction>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonObject>
#include <QKeySequence>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <QTextStream>
#include <QThread>
#include <QMetaObject>

namespace KosPlatform {

namespace {

// Desktop files written by superseded shortcut layouts: one-file-per-shortcut
// generations and the single-Action-file experiment. User created entries
// (net.local.qs*) are left alone.
const QStringList kLegacyDesktopIds = {
    QStringLiteral("net.local.kos"),
    QStringLiteral("net.local.kos-launcher"),
    QStringLiteral("net.local.kos-window-switcher"),
    QStringLiteral("net.local.kos-control-center"),
    QStringLiteral("net.local.kos-overview"),
    QStringLiteral("net.local.kos-clipboard"),
    QStringLiteral("net.local.kos-show-desktop"),
    QStringLiteral("net.local.quickshell-search"),
    QStringLiteral("net.local.quickshell-launcher"),
    QStringLiteral("net.local.quickshell-control-center"),
    QStringLiteral("net.local.quickshell-overview"),
};

QString normalizedShortcut(QString value)
{
    value = value.trimmed();
    const qsizetype comma = value.indexOf(QChar(','));
    if (comma >= 0)
        value.truncate(comma);
    return value.trimmed();
}

QString shortcutIdFromHeader(const QString &line)
{
    static const QRegularExpression header(
        QStringLiteral("^\\[services\\]\\[([^]]+)\\]$"));
    const auto match = header.match(line.trimmed());
    if (!match.hasMatch())
        return {};
    const QString desktop = match.captured(1);
    return desktop.endsWith(QStringLiteral(".desktop"))
        ? desktop.left(desktop.size() - 8) : QString{};
}

QString kglobalAccelerRcPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation)
        + QStringLiteral("/kglobalshortcutsrc");
}

QString applicationsPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::ApplicationsLocation);
}

// The only runnable Exec shape: `qs|quickshell [-c <name>] [-p|--path <dir>]
// ipc call <target> <action>...`. The shell-selector options mirror what
// ShortcutsService.qml composes (`-c kos` for the installed shell,
// `--path <dir>` for a development tree). Everything else is refused before
// a process ever spawns, so a forged shortcuts.apply payload cannot run
// arbitrary commands through the daemon.
QStringList shortcutExecArgv(const QString &exec, QString *error)
{
    auto reject = [error](const QString &exec, const QString &reason) {
        if (error)
            *error = reason;
        qWarning().noquote() << "[kos-platform] rejected shortcut exec:"
                             << exec << "—" << reason;
        return QStringList{};
    };
    // AbortOnMeta bails out on shell metacharacters (`;`, `|`, `$`, …), so
    // injection syntax never reaches the argument list.
    KShell::Errors splitError = KShell::NoError;
    const QStringList argv =
        KShell::splitArgs(exec, KShell::AbortOnMeta, &splitError);
    if (splitError != KShell::NoError || argv.isEmpty())
        return reject(exec, QStringLiteral("快捷键命令无法解析"));
    // argv[0] must name the quickshell binary. A bare `qs`/`quickshell`
    // resolves through PATH at spawn; an explicit path only passes when it
    // canonicalizes to the same binary PATH would find, so a lookalike
    // `/home/attacker/qs` cannot ride the allowlist.
    const QString &program = argv.first();
    bool allowed = program == QLatin1String("qs")
        || program == QLatin1String("quickshell");
    if (!allowed) {
        const QString canonical = QFileInfo(program).canonicalFilePath();
        for (const QString &name :
             {QStringLiteral("qs"), QStringLiteral("quickshell")}) {
            const QString resolved = QStandardPaths::findExecutable(name);
            if (!canonical.isEmpty() && !resolved.isEmpty()
                && QFileInfo(resolved).canonicalFilePath() == canonical) {
                allowed = true;
                break;
            }
        }
    }
    if (!allowed)
        return reject(exec, QStringLiteral("快捷键命令必须是 qs ipc call"));
    int index = 1;
    while (index < argv.size()) {
        const QString &option = argv.at(index);
        if (option != QLatin1String("-c") && option != QLatin1String("--config")
            && option != QLatin1String("-p") && option != QLatin1String("--path"))
            break;
        if (index + 1 >= argv.size())
            return reject(exec, QStringLiteral("快捷键命令选项缺少参数"));
        index += 2;
    }
    if (argv.size() - index < 4 || argv.at(index) != QLatin1String("ipc")
        || argv.at(index + 1) != QLatin1String("call"))
        return reject(exec, QStringLiteral("快捷键命令必须是 qs ipc call"));
    // Target/action words stay plain tokens: a quoted "foo;rm -rf" would
    // survive splitArgs, so the charset is checked explicitly.
    static const QRegularExpression token(QStringLiteral("^[A-Za-z0-9._-]+$"));
    for (int i = index + 2; i < argv.size(); ++i) {
        if (!token.match(argv.at(i)).hasMatch())
            return reject(exec, QStringLiteral("快捷键命令参数无效"));
    }
    return argv;
}

} // namespace

QString normalizedShortcutCombo(QString value)
{
    return normalizedShortcut(std::move(value));
}

void cleanShortcutLayouts()
{
    const QString appDir = applicationsPath();
    for (const QString &id : kLegacyDesktopIds)
        QFile::remove(QDir(appDir).filePath(id + QStringLiteral(".desktop")));

    QFile rc(kglobalAccelerRcPath());
    if (!rc.open(QIODevice::ReadOnly | QIODevice::Text))
        return;
    const QStringList lines = QString::fromUtf8(rc.readAll()).split(QChar('\n'));
    rc.close();

    QSet<QString> legacy(kLegacyDesktopIds.cbegin(), kLegacyDesktopIds.cend());
    QStringList kept;
    bool dropping = false;
    for (const QString &line : lines) {
        const QString id = shortcutIdFromHeader(line);
        if (!id.isEmpty()) {
            dropping = legacy.contains(id);
            if (dropping)
                continue;
        }
        if (dropping)
            continue;

        // Clean competing shortcuts from plasmashell and powerdevil
        if (line.startsWith(QLatin1String("activate application launcher="))) {
            kept.append(QStringLiteral("activate application launcher=none,none,Activate Application Launcher"));
            continue;
        }
        if (line.startsWith(QLatin1String("show-on-mouse-pos="))) {
            kept.append(QStringLiteral("show-on-mouse-pos=none,none,Show Clipboard Items at Mouse Position"));
            continue;
        }
        if (line.startsWith(QLatin1String("powerProfile=")) && line.contains(QLatin1String("Meta+B"))) {
            kept.append(QStringLiteral("powerProfile=Battery,Battery,Switch Power Profile"));
            continue;
        }

        kept.append(line);
    }
    if (kept.size() == lines.size() && kept == lines)
        return;
    QSaveFile output(kglobalAccelerRcPath());
    if (!output.open(QIODevice::WriteOnly | QIODevice::Text))
        return;
    output.write(kept.join(QChar('\n')).toUtf8());
    output.commit();
}

void clearExternalShortcutConflicts()
{
    const QDBusConnection bus = QDBusConnection::sessionBus();
    const QString service = QStringLiteral("org.kde.kglobalaccel");
    const QString path = QStringLiteral("/kglobalaccel");
    const QString iface = QStringLiteral("org.kde.KGlobalAccel");
    constexpr uint flags = 0x6; // kSetPresent | kNoAutoloading

    // Clear plasmashell activate application launcher
    QDBusMessage msg1 = QDBusMessage::createMethodCall(service, path, iface, QStringLiteral("setShortcut"));
    msg1.setArguments({QStringList{QStringLiteral("plasmashell"), QStringLiteral("activate application launcher"), QStringLiteral("plasmashell"), QStringLiteral("Activate Application Launcher")},
                       QVariant::fromValue(QList<int>{}),
                       QVariant::fromValue(flags)});
    bus.call(msg1, QDBus::NoBlock);

    // Clear plasmashell show-on-mouse-pos
    QDBusMessage msg2 = QDBusMessage::createMethodCall(service, path, iface, QStringLiteral("setShortcut"));
    msg2.setArguments({QStringList{QStringLiteral("plasmashell"), QStringLiteral("show-on-mouse-pos"), QStringLiteral("plasmashell"), QStringLiteral("Show Clipboard Items at Mouse Position")},
                       QVariant::fromValue(QList<int>{}),
                       QVariant::fromValue(flags)});
    bus.call(msg2, QDBus::NoBlock);

    // Clear powerdevil powerProfile Meta+B conflict
    QDBusMessage msg3 = QDBusMessage::createMethodCall(service, path, iface, QStringLiteral("setShortcut"));
    msg3.setArguments({QStringList{QStringLiteral("org_kde_powerdevil"), QStringLiteral("powerProfile"), QStringLiteral("Power Management"), QStringLiteral("Switch Power Profile")},
                       QVariant::fromValue(QList<int>{16777470}),
                       QVariant::fromValue(flags)});
    bus.call(msg3, QDBus::NoBlock);
}

void removeShortcuts()
{
    if (QThread::currentThread() != qApp->thread()) {
        QMetaObject::invokeMethod(qApp, []() {
            removeShortcuts();
        }, Qt::BlockingQueuedConnection);
        return;
    }
    cleanShortcutLayouts();
    KGlobalAccel *accel = KGlobalAccel::self();
    const auto actions = QGuiApplication::instance()->findChildren<QAction *>();
    for (QAction *action : actions) {
        if (!action->property("kosShortcut").toBool())
            continue;
        accel->setShortcut(action, {});
        action->deleteLater();
    }
}

bool applyShortcutSet(const QJsonArray &shortcuts, QString *error)
{
    if (QThread::currentThread() != qApp->thread()) {
        bool ok = false;
        QString err;
        QMetaObject::invokeMethod(qApp, [&ok, &err, shortcuts]() {
            ok = applyShortcutSet(shortcuts, &err);
        }, Qt::BlockingQueuedConnection);
        if (error)
            *error = err;
        return ok;
    }
    // Validate before touching any QAction so a malformed request never
    // leaves a half-registered state.
    struct Request {
        QString id;
        QString description;
        QString combo;
        QStringList argv;
    };
    QList<Request> requests;
    QSet<QString> ids;
    QSet<QString> combos;
    for (const QJsonValue &value : shortcuts) {
        const QJsonObject item = value.toObject();
        Request request;
        request.id = item.value(QStringLiteral("id")).toString().trimmed();
        request.description = item.value(QStringLiteral("description")).toString();
        request.combo = normalizedShortcut(item.value(QStringLiteral("combo")).toString());
        const QString exec = item.value(QStringLiteral("exec")).toString().trimmed();
        if (request.id.isEmpty() || request.combo.isEmpty() || exec.isEmpty()) {
            if (error)
                *error = QStringLiteral("快捷键定义不完整：%1").arg(request.id);
            return false;
        }
        // Exec allowlist: only `qs|quickshell … ipc call <target> <action>`,
        // parsed once here so the stored argv is what actually runs.
        request.argv = shortcutExecArgv(exec, error);
        if (request.argv.isEmpty())
            return false;
        if (ids.contains(request.id) || combos.contains(request.combo)) {
            if (error)
                *error = QStringLiteral("重复的 KOS 快捷键定义：%1 / %2")
                             .arg(request.id, request.combo);
            return false;
        }
        const QKeySequence sequence(request.combo);
        if (sequence.isEmpty()) {
            if (error)
                *error = QStringLiteral("无效的快捷键组合：%1").arg(request.combo);
            return false;
        }
        ids.insert(request.id);
        combos.insert(request.combo);
        requests.append(request);
    }

    // Superseded layouts would keep dead service entries in the Shortcuts
    // KCM alongside the real component.
    cleanShortcutLayouts();

    // KOS binds its own set through the same KGlobalAccel the compositor
    // uses. Repair the KWin side first (see KWinShortcutConflicts.h): the
    // workspace overview's Meta+Tab has to be released from "Walk Through
    // Windows" while Alt+Tab keeps working, and a KWin action that lost its
    // present state (a non-present shortcut stops firing while the registry
    // still lists everything) is revived here. A failure is logged but must
    // not stop the KOS shortcuts from applying.
    QStringList comboList;
    comboList.reserve(requests.size());
    for (const Request &request : requests)
        comboList.append(request.combo);
    QString conflictError;
    const QStringList repaired =
        repairKWinKeyConflicts(comboList, &conflictError);
    if (!conflictError.isEmpty())
        qWarning().noquote() << "[kos-platform] KWin shortcut repair:"
                             << conflictError;
    for (const QString &line : repaired)
        qInfo().noquote() << "[kos-platform] KWin shortcut repaired:" << line;

    clearExternalShortcutConflicts();

    KGlobalAccel *accel = KGlobalAccel::self();
    for (const Request &request : requests) {
        QAction *action = QGuiApplication::instance()->findChild<QAction *>(
            request.id);
        const bool created = action == nullptr;
        if (created) {
            action = new QAction(QGuiApplication::instance());
            action->setObjectName(request.id);
            action->setProperty("kosShortcut", true);
            // Read the argv from the property at trigger time so a later
            // apply (dev shell -> installed shell switch) takes effect.
            // Parsed argv — no shell — so quoting survives and injection
            // syntax is dead text (it was already rejected on apply).
            QObject::connect(action, &QAction::triggered, action, [action]() {
                const QStringList argv = action->property("kosExec").toStringList();
                if (!argv.isEmpty())
                    QProcess::startDetached(argv.first(), argv.mid(1));
            });
        }
        action->setText(request.description);
        action->setProperty("kosExec", request.argv);
        const QKeySequence sequence(request.combo);
        QList<QKeySequence> sequences{sequence};
        if (request.id == QLatin1String("net.local.kos-launcher")) {
            sequences.append(QKeySequence(QStringLiteral("Alt+F1")));
        }
        // NoAutoloading: kos-settings is the authoritative source; without
        // it a first registration could silently pick up a stale saved value.
        if (created)
            accel->setDefaultShortcut(action, sequences);
        accel->setShortcut(action, sequences, KGlobalAccel::NoAutoloading);
    }
    return true;
}

} // namespace KosPlatform
