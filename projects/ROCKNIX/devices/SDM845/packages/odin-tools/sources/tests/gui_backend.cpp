#define main odin_gui_main
#include "../main.cpp"
#undef main
#include <QElapsedTimer>
#include <QFile>
#include <QTemporaryDir>
#include <QThread>

bool waitFor(QApplication &app, const std::function<bool()> &ready, int timeout = 3000) {
    QElapsedTimer timer;
    timer.start();
    while (!ready() && timer.elapsed() < timeout) {
        app.processEvents();
        QThread::msleep(5);
    }
    return ready();
}

int main(int argc, char **argv) {
    QApplication app(argc, argv);
    QTemporaryDir temporary;
    const auto provider = temporary.filePath("ledctl.py");
    QFile file(provider);
    if (!file.open(QIODevice::WriteOnly)) return 1;
    file.write(R"(#!/usr/bin/python3
import json, pathlib, time
marker = pathlib.Path(__file__).with_suffix('.called')
if not marker.exists():
    marker.touch()
    print(json.dumps({'error': 'unsupported_model'}))
    raise SystemExit(1)
print(json.dumps({'leds': {name: {'available': True, 'on': False, 'effects': ['steady']} for name in ('left-stick', 'right-stick', 'left-side', 'right-side')}}))
)");
    file.close();
    file.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
    qputenv("ODIN_LEDCTL", provider.toUtf8());
    LedWindow window(false);
    window.show();
    if (!waitFor(app, [&] { return !window.pending && QFile::exists(temporary.filePath("ledctl.called")); })) return 2;
    QPushButton *retry = nullptr;
    for (auto button : window.findChildren<QPushButton *>())
        if (button->text() == "다시 확인") retry = button;
    if (!retry || !retry->isEnabled()) {
        std::fprintf(stderr, "Missing usable retry after backend failure\n");
        return 3;
    }
    retry->click();
    if (!waitFor(app, [&] { return window.loaded && !window.pending; })) return 4;
    if (!window.toggles[0]->isEnabled()) return 5;
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) return 6;
    file.write("#!/usr/bin/python3\nimport time\ntime.sleep(60)\n");
    file.close();
    window.request({"status"});
    if (!waitFor(app, [&] { return !window.pending; }, 12500)) {
        std::fprintf(stderr, "Unbounded backend request\n");
        return 7;
    }
    if (!retry->isEnabled()) return 8;
    std::puts("GUI_BACKEND_FAILURE_RETRY_AND_TIMEOUT=PASS");
    return 0;
}
