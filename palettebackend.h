#ifndef PALETTEBACKEND_H
#define PALETTEBACKEND_H

#include <QObject>
#include <QColor>
#include <QImage>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

class HotkeyFilter;

class PaletteBackend : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString hex READ hex NOTIFY colorChanged)
    Q_PROPERTY(QString rgb READ rgb NOTIFY colorChanged)
    Q_PROPERTY(QString hsl READ hsl NOTIFY colorChanged)
    Q_PROPERTY(QString bestText READ bestText NOTIFY colorChanged)
    Q_PROPERTY(double contrastWhite READ contrastWhite NOTIFY colorChanged)
    Q_PROPERTY(double contrastBlack READ contrastBlack NOTIFY colorChanged)
    Q_PROPERTY(QVariantList palette READ palette NOTIFY colorChanged)
    Q_PROPERTY(QVariantList history READ history NOTIFY historyChanged)
    Q_PROPERTY(bool autoCopy READ autoCopy WRITE setAutoCopy NOTIFY settingsChanged)
    Q_PROPERTY(QString defaultFormat READ defaultFormat WRITE setDefaultFormat NOTIFY settingsChanged)
    Q_PROPERTY(int zoom READ zoom WRITE setZoom NOTIFY settingsChanged)
    Q_PROPERTY(int dimAlpha READ dimAlpha WRITE setDimAlpha NOTIFY settingsChanged)
    Q_PROPERTY(QString hotkey READ hotkey NOTIFY settingsChanged)
    Q_PROPERTY(bool autostart READ autostart WRITE setAutostart NOTIFY settingsChanged)

public:
    explicit PaletteBackend(QObject *parent = nullptr);
    ~PaletteBackend() override;

    QString hex() const;
    QString rgb() const;
    QString hsl() const;
    QString bestText() const;
    double contrastWhite() const;
    double contrastBlack() const;
    QVariantList palette() const;
    QVariantList history() const;

    bool autoCopy() const { return m_autoCopy; }
    void setAutoCopy(bool value);

    QString defaultFormat() const { return m_defaultFormat; }
    void setDefaultFormat(const QString &value);

    int zoom() const { return m_zoom; }
    void setZoom(int value);

    int dimAlpha() const { return m_dimAlpha; }
    void setDimAlpha(int value);

    QString hotkey() const { return m_hotkeyString; }

    bool autostart() const { return m_autostart; }
    void setAutostart(bool value);

    Q_INVOKABLE QVariantMap captureScreen();
    Q_INVOKABLE QVariantMap sampleAt(int logicalX, int logicalY);
    Q_INVOKABLE void pickHex(const QString &hex);
    Q_INVOKABLE void copyText(const QString &text);
    Q_INVOKABLE bool trySetHotkey(const QString &text);
    Q_INVOKABLE void resetSettings();
    Q_INVOKABLE void clearHistory();
    Q_INVOKABLE void removeFromHistory(int index);

    void triggerHotkey();

signals:
    void colorChanged();
    void copied(const QString &text);
    void hotkeyPressed();
    void historyChanged();
    void settingsChanged();

private:
    void setColor(const QColor &color);
    void loadSettings();
    void saveSettings();
    void saveHistory();

    QColor m_color;
    QImage m_capture;
    qreal m_dpr = 1.0;
    QStringList m_historyHexes;
    bool m_autoCopy = true;
    QString m_defaultFormat = "hex";
    int m_zoom = 12;
    int m_dimAlpha = 0x50;
    QString m_hotkeyString = "ctrl+alt+c";
    bool m_autostart = false;
    HotkeyFilter *m_hotkeyFilter = nullptr;
};

#endif
