#include "palettebackend.h"

#include <QGuiApplication>
#include <QCoreApplication>
#include <QScreen>
#include <QClipboard>
#include <QCursor>
#include <QPixmap>
#include <QImage>
#include <QSettings>
#include <QDir>
#include <QPoint>
#include <QRect>
#include <QBuffer>
#include <QIODevice>
#include <QAbstractNativeEventFilter>
#include <cmath>

#ifdef Q_OS_WIN
#include <windows.h>
#endif

namespace {

qreal clamp01(qreal value) { return qBound(0.0, value, 1.0); }

qreal channelLuminance(int channel)
{
    qreal c = channel / 255.0;
    if (c <= 0.03928) return c / 12.92;
    return std::pow((c + 0.055) / 1.055, 2.4);
}

qreal relativeLuminance(const QColor &color)
{
    return 0.2126 * channelLuminance(color.red())
    + 0.7152 * channelLuminance(color.green())
        + 0.0722 * channelLuminance(color.blue());
}

qreal contrastRatio(const QColor &a, const QColor &b)
{
    qreal l1 = relativeLuminance(a);
    qreal l2 = relativeLuminance(b);
    return (qMax(l1, l2) + 0.05) / (qMin(l1, l2) + 0.05);
}

QColor bestTextColor(const QColor &background)
{
    return contrastRatio(background, QColor(0, 0, 0)) >=
                   contrastRatio(background, QColor(255, 255, 255))
               ? QColor(0, 0, 0) : QColor(255, 255, 255);
}

QColor fromHslDegrees(qreal hueDegrees, qreal saturation, qreal lightness)
{
    hueDegrees = std::fmod(hueDegrees, 360.0);
    if (hueDegrees < 0.0) hueDegrees += 360.0;
    return QColor::fromHslF(
        static_cast<float>(hueDegrees / 360.0),
        static_cast<float>(clamp01(saturation)),
        static_cast<float>(clamp01(lightness)));
}

QVariantMap paletteItem(const QString &name, const QColor &color)
{
    QVariantMap item;
    item.insert("name", name);
    item.insert("hex", color.name().toUpper());
    item.insert("color", color.name().toUpper());
    item.insert("text", bestTextColor(color).name().toUpper());
    return item;
}

#ifdef Q_OS_WIN
bool parseHotkey(const QString &text, UINT &mods, UINT &vk)
{
    mods = 0; vk = 0;
    const QStringList parts = text.split('+', Qt::SkipEmptyParts);
    if (parts.isEmpty()) return false;

    for (int i = 0; i < parts.size() - 1; ++i) {
        const QString p = parts[i].trimmed().toLower();
        if (p == "ctrl") mods |= MOD_CONTROL;
        else if (p == "alt") mods |= MOD_ALT;
        else if (p == "shift") mods |= MOD_SHIFT;
        else if (p == "win" || p == "meta") mods |= MOD_WIN;
        else return false;
    }

    const QString key = parts.last().trimmed().toLower();
    if (key.size() == 1) {
        const QChar c = key[0];
        if (c >= 'a' && c <= 'z') { vk = static_cast<UINT>(c.toUpper().toLatin1()); return true; }
        if (c >= '0' && c <= '9') { vk = static_cast<UINT>(c.toLatin1()); return true; }
        return false;
    }
    if (key.startsWith('f')) {
        bool ok = false;
        const int n = key.mid(1).toInt(&ok);
        if (ok && n >= 1 && n <= 24) { vk = VK_F1 + static_cast<UINT>(n) - 1; return true; }
        return false;
    }
    if (key == "space") { vk = VK_SPACE; return true; }
    return false;
}
#endif

} // namespace

#ifdef Q_OS_WIN
class HotkeyFilter : public QAbstractNativeEventFilter
{
public:
    explicit HotkeyFilter(PaletteBackend *backend) : m_backend(backend) {}
    bool nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result) override
    {
        Q_UNUSED(result);
        if (eventType.startsWith("windows")) {
            MSG *msg = static_cast<MSG *>(message);
            if (msg->message == WM_HOTKEY) m_backend->triggerHotkey();
        }
        return false;
    }
private:
    PaletteBackend *m_backend;
};
#endif

PaletteBackend::PaletteBackend(QObject *parent)
    : QObject(parent), m_color("#7C9CFF")
{
    loadSettings();
#ifdef Q_OS_WIN
    UINT mods = 0, vk = 0;
    if (parseHotkey(m_hotkeyString, mods, vk)) RegisterHotKey(nullptr, 1, mods, vk);
    m_hotkeyFilter = new HotkeyFilter(this);
    QCoreApplication::instance()->installNativeEventFilter(m_hotkeyFilter);
#endif
}

PaletteBackend::~PaletteBackend()
{
#ifdef Q_OS_WIN
    UnregisterHotKey(nullptr, 1);
    if (m_hotkeyFilter) {
        QCoreApplication::instance()->removeNativeEventFilter(m_hotkeyFilter);
        delete m_hotkeyFilter;
        m_hotkeyFilter = nullptr;
    }
#endif
}

void PaletteBackend::loadSettings()
{
    QSettings s;
    m_autoCopy = s.value("autoCopy", true).toBool();
    m_defaultFormat = s.value("defaultFormat", "hex").toString();
    m_zoom = s.value("zoom", 12).toInt();
    m_dimAlpha = s.value("dimAlpha", 0x50).toInt();
    m_hotkeyString = s.value("hotkey", "ctrl+alt+c").toString();
    m_historyHexes = s.value("history").toStringList();

    m_theme = s.value("theme", "dark").toString();
    if (m_theme != "dark" && m_theme != "light") {
        m_theme = "dark";
    }

#ifdef Q_OS_WIN
    QSettings reg("HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Run", QSettings::NativeFormat);
    m_autostart = reg.contains("PaletteSniper");
#else
    m_autostart = false;
#endif
}

void PaletteBackend::saveSettings()
{
    QSettings s;
    s.setValue("autoCopy", m_autoCopy);
    s.setValue("defaultFormat", m_defaultFormat);
    s.setValue("zoom", m_zoom);
    s.setValue("dimAlpha", m_dimAlpha);
    s.setValue("hotkey", m_hotkeyString);
    s.setValue("theme", m_theme);
}

void PaletteBackend::saveHistory()
{
    QSettings s;
    s.setValue("history", m_historyHexes);
}

QString PaletteBackend::hex() const { return m_color.name().toUpper(); }

QString PaletteBackend::rgb() const
{
    return QString("rgb(%1, %2, %3)").arg(m_color.red()).arg(m_color.green()).arg(m_color.blue());
}

QString PaletteBackend::hsl() const
{
    float h = 0.0f, s = 0.0f, l = 0.0f;
    m_color.getHslF(&h, &s, &l);
    if (h < 0.0f) h = 0.0f;
    return QString("hsl(%1, %2%, %3%)").arg(qRound(h * 360.0f)).arg(qRound(s * 100.0f)).arg(qRound(l * 100.0f));
}

QString PaletteBackend::bestText() const { return bestTextColor(m_color).name().toUpper(); }
double PaletteBackend::contrastWhite() const { return contrastRatio(m_color, QColor(255, 255, 255)); }
double PaletteBackend::contrastBlack() const { return contrastRatio(m_color, QColor(0, 0, 0)); }

QVariantList PaletteBackend::palette() const
{
    QVariantList result;
    float h = 0.0f, s = 0.0f, l = 0.0f;
    m_color.getHslF(&h, &s, &l);
    if (h < 0.0f) h = 0.0f;
    qreal hue = h * 360.0;

    auto addColor = [&](const QString &name, qreal hueShift, qreal lightShift = 0.0) {
        result.append(paletteItem(name, fromHslDegrees(hue + hueShift, s, l + lightShift)));
    };

    addColor("Base", 0.0);
    addColor("Complement", 180.0);
    addColor("Analog +25", 25.0);
    addColor("Analog -25", -25.0);
    addColor("Triadic +120", 120.0);
    addColor("Triadic -120", -120.0);
    addColor("Shade 1", 0.0, -0.30);
    addColor("Shade 2", 0.0, -0.15);
    addColor("Shade 3", 0.0, 0.0);
    addColor("Shade 4", 0.0, 0.15);
    addColor("Shade 5", 0.0, 0.30);

    return result;
}

QVariantList PaletteBackend::history() const
{
    QVariantList result;
    for (const QString &hx : m_historyHexes) {
        QVariantMap item;
        item.insert("hex", hx);
        item.insert("text", bestTextColor(QColor(hx)).name().toUpper());
        result.append(item);
    }
    return result;
}

void PaletteBackend::setAutoCopy(bool value)
{
    if (m_autoCopy == value) return;
    m_autoCopy = value;
    saveSettings();
    emit settingsChanged();
}

void PaletteBackend::setDefaultFormat(const QString &value)
{
    if (value != "hex" && value != "rgb" && value != "hsl") return;
    if (m_defaultFormat == value) return;
    m_defaultFormat = value;
    saveSettings();
    emit settingsChanged();
}

void PaletteBackend::setZoom(int value)
{
    if (value != 8 && value != 12 && value != 16 && value != 24) return;
    if (m_zoom == value) return;
    m_zoom = value;
    saveSettings();
    emit settingsChanged();
}

void PaletteBackend::setDimAlpha(int value)
{
    value = qBound(0, value, 200);
    if (m_dimAlpha == value) return;
    m_dimAlpha = value;
    saveSettings();
    emit settingsChanged();
}

void PaletteBackend::setAutostart(bool value)
{
    if (m_autostart == value) return;
    m_autostart = value;
#ifdef Q_OS_WIN
    QSettings reg("HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Run", QSettings::NativeFormat);
    if (value) reg.setValue("PaletteSniper", QDir::toNativeSeparators(QCoreApplication::applicationFilePath()));
    else reg.remove("PaletteSniper");
#endif
    emit settingsChanged();
}

void PaletteBackend::setTheme(const QString &value)
{
    if (value != "dark" && value != "light") return;
    if (m_theme == value) return;
    m_theme = value;
    saveSettings();
    emit settingsChanged();
}

bool PaletteBackend::trySetHotkey(const QString &text)
{
    const QString trimmed = text.trimmed().toLower();
    if (trimmed.isEmpty()) return false;

#ifdef Q_OS_WIN
    UINT mods = 0, vk = 0;
    if (!parseHotkey(trimmed, mods, vk)) return false;

    UnregisterHotKey(nullptr, 1);
    if (!RegisterHotKey(nullptr, 1, mods, vk)) {
        UINT om = 0, ov = 0;
        if (parseHotkey(m_hotkeyString, om, ov)) RegisterHotKey(nullptr, 1, om, ov);
        return false;
    }
#endif
    m_hotkeyString = trimmed;
    saveSettings();
    emit settingsChanged();
    return true;
}

void PaletteBackend::resetSettings()
{
    m_autoCopy = true;
    m_defaultFormat = "hex";
    m_zoom = 12;
    m_dimAlpha = 0x50;
    m_theme = "dark";

#ifdef Q_OS_WIN
    UnregisterHotKey(nullptr, 1);
    UINT mods = 0, vk = 0;
    m_hotkeyString = "ctrl+alt+c";
    if (parseHotkey(m_hotkeyString, mods, vk)) {
        RegisterHotKey(nullptr, 1, mods, vk);
    }
#else
    m_hotkeyString = "ctrl+alt+c";
#endif
    saveSettings();
    emit settingsChanged();
}

void PaletteBackend::clearHistory()
{
    if (m_historyHexes.isEmpty()) return;
    m_historyHexes.clear();
    saveHistory();
    emit historyChanged();
}

void PaletteBackend::removeFromHistory(int index)
{
    if (index < 0 || index >= m_historyHexes.size()) return;
    m_historyHexes.removeAt(index);
    saveHistory();
    emit historyChanged();
}

QVariantMap PaletteBackend::captureScreen()
{
    QVariantMap result;
    QScreen *screen = QGuiApplication::screenAt(QCursor::pos());
    if (!screen) screen = QGuiApplication::primaryScreen();
    if (!screen) {
        result.insert("image", QString());
        result.insert("dpr", 1.0);
        return result;
    }

    m_dpr = screen->devicePixelRatio();
    QPixmap pixmap = screen->grabWindow(0, 0, 0, -1, -1);
    m_capture = pixmap.toImage().convertToFormat(QImage::Format_RGB32);

    QByteArray bytes;
    QBuffer buffer(&bytes);
    buffer.open(QIODevice::WriteOnly);
    m_capture.save(&buffer, "JPG", 90);

    result.insert("image", "data:image/jpeg;base64," + QString::fromLatin1(bytes.toBase64()));
    result.insert("dpr", m_dpr);
    return result;
}

QVariantMap PaletteBackend::sampleAt(int logicalX, int logicalY)
{
    QVariantMap result;
    if (m_capture.isNull()) {
        result.insert("hex", "#000000");
        result.insert("magnifier", QString());
        return result;
    }

    int cx = qBound(0, qRound(logicalX * m_dpr), m_capture.width() - 1);
    int cy = qBound(0, qRound(logicalY * m_dpr), m_capture.height() - 1);
    QColor center = m_capture.pixelColor(cx, cy);

    const int size = 13, half = 6;
    int x0 = qBound(0, cx - half, qMax(0, m_capture.width() - size));
    int y0 = qBound(0, cy - half, qMax(0, m_capture.height() - size));
    QImage sub = m_capture.copy(x0, y0, qMin(size, m_capture.width()), qMin(size, m_capture.height()));

    QByteArray bytes;
    QBuffer buffer(&bytes);
    buffer.open(QIODevice::WriteOnly);
    sub.save(&buffer, "PNG");

    result.insert("hex", center.name().toUpper());
    result.insert("magnifier", "data:image/png;base64," + QString::fromLatin1(bytes.toBase64()));
    return result;
}

void PaletteBackend::pickHex(const QString &hex)
{
    QColor color(hex);
    if (color.isValid()) setColor(color);
}

void PaletteBackend::copyText(const QString &text)
{
    QGuiApplication::clipboard()->setText(text);
    emit copied(text);
}

void PaletteBackend::triggerHotkey()
{
    emit hotkeyPressed();
}

void PaletteBackend::setColor(const QColor &color)
{
    m_color = color;
    const QString hx = color.name().toUpper();
    if (m_historyHexes.isEmpty() || m_historyHexes.first() != hx) {
        m_historyHexes.prepend(hx);
        while (m_historyHexes.size() > 48) m_historyHexes.removeLast();
        saveHistory();
        emit historyChanged();
    }

    if (m_autoCopy) {
        QString t = hex();
        if (m_defaultFormat == "rgb") t = rgb();
        else if (m_defaultFormat == "hsl") t = hsl();
        copyText(t);
    }
    emit colorChanged();
}
