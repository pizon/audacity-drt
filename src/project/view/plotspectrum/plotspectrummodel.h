/*
 * Audacity: A Digital Audio Editor
 */
#pragma once

#include <memory>

#include <QObject>
#include <QVariantList>

#include "framework/global/async/asyncable.h"
#include "framework/global/modularity/ioc.h"
#include "framework/interactive/iinteractive.h"

#include "context/iglobalcontext.h"

#include "plotspectrumanalyzer.h"

namespace au::project {
class PlotSpectrumModel : public QObject, public muse::Contextable, public muse::async::Asyncable
{
    Q_OBJECT

    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged FINAL)
    Q_PROPERTY(bool hasEnoughData READ hasEnoughData NOTIFY readyChanged FINAL)
    Q_PROPERTY(bool analyzing READ analyzing NOTIFY analyzingChanged FINAL)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged FINAL)

    Q_PROPERTY(int algorithm READ algorithm WRITE setAlgorithm NOTIFY algorithmChanged FINAL)
    Q_PROPERTY(int sizeChoice READ sizeChoice WRITE setSizeChoice NOTIFY sizeChoiceChanged FINAL)
    Q_PROPERTY(int windowFunc READ windowFunc WRITE setWindowFunc NOTIFY windowFuncChanged FINAL)
    Q_PROPERTY(int axisChoice READ axisChoice WRITE setAxisChoice NOTIFY axisChoiceChanged FINAL)
    Q_PROPERTY(bool drawGrid READ drawGrid WRITE setDrawGrid NOTIFY drawGridChanged FINAL)
    Q_PROPERTY(bool logAxis READ logAxis NOTIFY axisChoiceChanged FINAL)
    Q_PROPERTY(bool axisEnabled READ axisEnabled NOTIFY algorithmChanged FINAL)

    Q_PROPERTY(int zoom READ zoom WRITE setZoom NOTIFY zoomChanged FINAL)
    Q_PROPERTY(int pan READ pan WRITE setPan NOTIFY panChanged FINAL)
    Q_PROPERTY(int panMax READ panMax NOTIFY panRangeChanged FINAL)
    Q_PROPERTY(int panPage READ panPage NOTIFY panRangeChanged FINAL)

    Q_PROPERTY(double xMin READ xMin NOTIFY rangeChanged FINAL)
    Q_PROPERTY(double xMax READ xMax NOTIFY rangeChanged FINAL)
    Q_PROPERTY(double yMin READ yMin NOTIFY rangeChanged FINAL)
    Q_PROPERTY(double yMax READ yMax NOTIFY rangeChanged FINAL)
    Q_PROPERTY(QString xUnit READ xUnit NOTIFY algorithmChanged FINAL)
    Q_PROPERTY(QString yUnit READ yUnit NOTIFY algorithmChanged FINAL)

    Q_PROPERTY(QVariantList algorithmNames READ algorithmNames CONSTANT FINAL)
    Q_PROPERTY(QVariantList sizeNames READ sizeNames CONSTANT FINAL)
    Q_PROPERTY(QVariantList windowFuncNames READ windowFuncNames CONSTANT FINAL)
    Q_PROPERTY(QVariantList axisNames READ axisNames CONSTANT FINAL)

    Q_PROPERTY(QVariantList plotSamples READ plotSamples NOTIFY plotChanged FINAL)
    Q_PROPERTY(QVariantList xTicks READ xTicks NOTIFY plotChanged FINAL)
    Q_PROPERTY(QVariantList yTicks READ yTicks NOTIFY plotChanged FINAL)

    Q_PROPERTY(QString cursorText READ cursorText NOTIFY hoverChanged FINAL)
    Q_PROPERTY(QString peakText READ peakText NOTIFY hoverChanged FINAL)
    Q_PROPERTY(double peakPosition READ peakPosition NOTIFY hoverChanged FINAL)
    Q_PROPERTY(bool hoverActive READ hoverActive NOTIFY hoverChanged FINAL)

    Q_PROPERTY(int plotWidth READ plotWidth WRITE setPlotWidth NOTIFY plotWidthChanged FINAL)
    Q_PROPERTY(int labelWidth READ labelWidth WRITE setLabelWidth NOTIFY labelSizeChanged FINAL)
    Q_PROPERTY(int labelHeight READ labelHeight WRITE setLabelHeight NOTIFY labelSizeChanged FINAL)

    muse::ContextInject<au::context::IGlobalContext> globalContext { this };
    muse::ContextInject<muse::IInteractive> interactive { this };

public:
    explicit PlotSpectrumModel(QObject* parent = nullptr);
    ~PlotSpectrumModel() override;

    Q_INVOKABLE bool load();
    Q_INVOKABLE void replot();
    Q_INVOKABLE void exportData();
    Q_INVOKABLE void close();
    Q_INVOKABLE void updateHover(double x, double y, double width, double height);
    Q_INVOKABLE void clearHover();

    bool ready() const { return m_ready; }
    bool hasEnoughData() const;
    bool analyzing() const { return m_analyzing; }
    double progress() const { return m_progress; }

    int algorithm() const;
    void setAlgorithm(int value);

    int sizeChoice() const;
    void setSizeChoice(int value);

    int windowFunc() const;
    void setWindowFunc(int value);

    int axisChoice() const;
    void setAxisChoice(int value);

    bool drawGrid() const;
    void setDrawGrid(bool value);

    bool logAxis() const;
    bool axisEnabled() const;

    int zoom() const { return m_zoom; }
    void setZoom(int value);

    int pan() const { return m_pan; }
    void setPan(int value);
    int panMax() const { return m_panMax; }
    int panPage() const { return m_panPage; }

    double xMin() const { return m_xMin; }
    double xMax() const { return m_xMax; }
    double yMin() const { return m_yMin; }
    double yMax() const { return m_yMax; }
    QString xUnit() const;
    QString yUnit() const;

    QVariantList algorithmNames() const;
    QVariantList sizeNames() const;
    QVariantList windowFuncNames() const;
    QVariantList axisNames() const;

    QVariantList plotSamples() const { return m_plotSamples; }
    QVariantList xTicks() const { return m_xTicks; }
    QVariantList yTicks() const { return m_yTicks; }

    QString cursorText() const { return m_cursorText; }
    QString peakText() const { return m_peakText; }
    double peakPosition() const { return m_peakPosition; }
    bool hoverActive() const { return m_hoverActive; }

    int plotWidth() const { return m_plotWidth; }
    void setPlotWidth(int value);

    int labelWidth() const { return m_labelWidth; }
    void setLabelWidth(int value);

    int labelHeight() const { return m_labelHeight; }
    void setLabelHeight(int value);

signals:
    void readyChanged();
    void analyzingChanged();
    void progressChanged();
    void algorithmChanged();
    void sizeChoiceChanged();
    void windowFuncChanged();
    void axisChoiceChanged();
    void drawGridChanged();
    void zoomChanged();
    void panChanged();
    void panRangeChanged();
    void rangeChanged();
    void plotChanged();
    void hoverChanged();
    void plotWidthChanged();
    void labelSizeChanged();

private:
    bool ensureAnalyzer();
    void refreshDbRange();
    void recalculate();
    void updateVisibleRange();
    void rebuildPlot();
    void rebuildTicks();
    double xAtPixel(int pixel, int width) const;
    double xStep(int width) const;

    std::unique_ptr<PlotSpectrumAnalyzer> m_analyzer;
    bool m_ready = false;
    bool m_analyzing = false;
    double m_progress = 0.0;

    int m_zoom = 100;
    int m_pan = 0;
    int m_panMax = 0;
    int m_panPage = 1;

    double m_xMin = 0.0;
    double m_xMax = 1.0;
    double m_yMin = 0.0;
    double m_yMax = 1.0;

    int m_plotWidth = 0;
    int m_labelWidth = 40;
    int m_labelHeight = 16;

    QVariantList m_plotSamples;
    QVariantList m_xTicks;
    QVariantList m_yTicks;

    QString m_cursorText;
    QString m_peakText;
    double m_peakPosition = -1.0;
    bool m_hoverActive = false;
};
}
