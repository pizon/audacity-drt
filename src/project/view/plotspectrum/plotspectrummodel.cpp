/*
 * Audacity: A Digital Audio Editor
 */
#include "plotspectrummodel.h"

#include <cmath>
#include <algorithm>

#include <QFile>
#include <QTextStream>

#include "au3-fft/FFT.h"
#include "au3-math/PitchName.h"
#include "au3-project/Project.h"
#include "au3-project-rate/Decibels.h"
#include "au3-preferences/Prefs.h"

#include "au3wrap/internal/wxtypes_convert.h"
#include "project/iaudacityproject.h"
#include "shared/axis/axislabel.h"
#include "shared/axis/axisticks.h"
#include "shared/axis/axisscale.h"

#include "framework/global/translation.h"
#include "modularity/ioc.h"

using namespace au::project;

namespace {
QString pitchName(double freqHz)
{
    return QString::fromStdString(au::au3::wxToStdString(PitchName_Absolute(FreqToMIDInote(freqHz)).Translation()));
}

QVariantMap tickMap(const QString& label, double position)
{
    return {
        { QStringLiteral("label"), label },
        { QStringLiteral("position"), position },
    };
}
}

PlotSpectrumModel::PlotSpectrumModel(QObject* parent)
    : QObject(parent), muse::Contextable(muse::iocCtxForQmlObject(this))
{
}

PlotSpectrumModel::~PlotSpectrumModel() = default;

bool PlotSpectrumModel::ensureAnalyzer()
{
    const auto project = globalContext()->currentProject();
    if (!project) {
        return false;
    }

    auto* au3Project = reinterpret_cast<AudacityProject*>(project->au3ProjectPtr());
    if (!au3Project) {
        return false;
    }

    if (!m_analyzer) {
        m_analyzer = std::make_unique<PlotSpectrumAnalyzer>(*au3Project);
    }

    return true;
}

bool PlotSpectrumModel::load()
{
    clearHover();

    if (!ensureAnalyzer()) {
        m_ready = false;
        emit readyChanged();
        return false;
    }

    refreshDbRange();

    if (!m_analyzer->loadAudio()) {
        m_ready = false;
        emit readyChanged();
        return false;
    }

    m_ready = true;
    emit readyChanged();
    emit algorithmChanged();
    emit sizeChoiceChanged();
    emit windowFuncChanged();
    emit axisChoiceChanged();
    emit drawGridChanged();

    recalculate();
    return true;
}

void PlotSpectrumModel::replot()
{
    if (!ensureAnalyzer()) {
        return;
    }

    refreshDbRange();
    if (!m_analyzer->loadAudio()) {
        m_ready = false;
        emit readyChanged();
        return;
    }

    m_ready = true;
    emit readyChanged();
    recalculate();
}

void PlotSpectrumModel::close()
{
    if (m_analyzer) {
        m_analyzer->savePrefs();
    }
}

void PlotSpectrumModel::refreshDbRange()
{
    if (!m_analyzer) {
        return;
    }

    int range = DecibelScaleCutoff.Read();
    if (range < 90) {
        range = 90;
    }
    m_analyzer->setDbRange(range);
}

void PlotSpectrumModel::recalculate()
{
    if (!m_analyzer) {
        return;
    }

    m_analyzing = true;
    m_progress = 0.0;
    emit analyzingChanged();
    emit progressChanged();

    const bool ok = m_analyzer->recalculate([this](long long num, long long den) {
        if (den <= 0) {
            return;
        }
        m_progress = static_cast<double>(num) / static_cast<double>(den);
        emit progressChanged();
    });

    m_analyzing = false;
    m_progress = ok ? 1.0 : 0.0;
    emit analyzingChanged();
    emit progressChanged();

    m_pan = 0;
    updateVisibleRange();
    rebuildPlot();
}

bool PlotSpectrumModel::hasEnoughData() const
{
    return m_analyzer && m_analyzer->hasEnoughData();
}

int PlotSpectrumModel::algorithm() const
{
    return m_analyzer ? static_cast<int>(m_analyzer->algorithm()) : 0;
}

void PlotSpectrumModel::setAlgorithm(int value)
{
    if (!m_analyzer || value < 0 || value >= SpectrumAnalyst::NumAlgorithms || algorithm() == value) {
        return;
    }

    m_analyzer->setAlgorithm(static_cast<SpectrumAnalyst::Algorithm>(value));
    if (m_analyzer->algorithm() != SpectrumAnalyst::Spectrum) {
        m_analyzer->setAxisChoice(0);
    }

    emit algorithmChanged();
    emit axisChoiceChanged();
    recalculate();
}

int PlotSpectrumModel::sizeChoice() const
{
    return m_analyzer ? m_analyzer->sizeChoice() : 3;
}

void PlotSpectrumModel::setSizeChoice(int value)
{
    if (!m_analyzer || sizeChoice() == value) {
        return;
    }

    m_analyzer->setSizeChoice(value);
    emit sizeChoiceChanged();
    recalculate();
}

int PlotSpectrumModel::windowFunc() const
{
    return m_analyzer ? m_analyzer->windowFunc() : 3;
}

void PlotSpectrumModel::setWindowFunc(int value)
{
    if (!m_analyzer || windowFunc() == value) {
        return;
    }

    m_analyzer->setWindowFunc(value);
    emit windowFuncChanged();
    recalculate();
}

int PlotSpectrumModel::axisChoice() const
{
    return m_analyzer ? m_analyzer->axisChoice() : 1;
}

void PlotSpectrumModel::setAxisChoice(int value)
{
    if (!m_analyzer || !axisEnabled() || axisChoice() == value) {
        return;
    }

    m_analyzer->setAxisChoice(value);
    emit axisChoiceChanged();
    rebuildPlot();
}

bool PlotSpectrumModel::drawGrid() const
{
    return m_analyzer ? m_analyzer->drawGrid() : true;
}

void PlotSpectrumModel::setDrawGrid(bool value)
{
    if (!m_analyzer || drawGrid() == value) {
        return;
    }

    m_analyzer->setDrawGrid(value);
    emit drawGridChanged();
}

bool PlotSpectrumModel::logAxis() const
{
    return axisEnabled() && axisChoice() != 0;
}

bool PlotSpectrumModel::axisEnabled() const
{
    return algorithm() == SpectrumAnalyst::Spectrum;
}

void PlotSpectrumModel::setZoom(int value)
{
    value = std::clamp(value, 1, 100);
    if (m_zoom == value) {
        return;
    }

    m_zoom = value;
    emit zoomChanged();
    updateVisibleRange();
    rebuildPlot();
}

void PlotSpectrumModel::setPan(int value)
{
    value = std::clamp(value, 0, std::max(0, m_panMax - m_panPage));
    if (m_pan == value) {
        return;
    }

    m_pan = value;
    emit panChanged();
    updateVisibleRange();
    rebuildPlot();
}

void PlotSpectrumModel::setPlotWidth(int value)
{
    value = std::max(0, value);
    if (m_plotWidth == value) {
        return;
    }

    m_plotWidth = value;
    emit plotWidthChanged();
    rebuildPlot();
}

void PlotSpectrumModel::setLabelWidth(int value)
{
    if (m_labelWidth == value) {
        return;
    }
    m_labelWidth = value;
    emit labelSizeChanged();
    rebuildTicks();
    emit plotChanged();
}

void PlotSpectrumModel::setLabelHeight(int value)
{
    if (m_labelHeight == value) {
        return;
    }
    m_labelHeight = value;
    emit labelSizeChanged();
    rebuildTicks();
    emit plotChanged();
}

QString PlotSpectrumModel::xUnit() const
{
    return algorithm() == SpectrumAnalyst::Spectrum
           ? muse::qtrc("project/plotspectrum", "Hz")
           : muse::qtrc("project/plotspectrum", "s");
}

QString PlotSpectrumModel::yUnit() const
{
    return algorithm() == SpectrumAnalyst::Spectrum
           ? muse::qtrc("project/plotspectrum", "dB")
           : QString();
}

QVariantList PlotSpectrumModel::algorithmNames() const
{
    return {
        muse::qtrc("project/plotspectrum", "Spectrum"),
        muse::qtrc("project/plotspectrum", "Standard Autocorrelation"),
        muse::qtrc("project/plotspectrum", "Cuberoot Autocorrelation"),
        muse::qtrc("project/plotspectrum", "Enhanced Autocorrelation"),
        muse::qtrc("project/plotspectrum", "Cepstrum"),
    };
}

QVariantList PlotSpectrumModel::sizeNames() const
{
    return {
        QStringLiteral("128"), QStringLiteral("256"), QStringLiteral("512"),
        QStringLiteral("1024"), QStringLiteral("2048"), QStringLiteral("4096"),
        QStringLiteral("8192"), QStringLiteral("16384"), QStringLiteral("32768"),
        QStringLiteral("65536"), QStringLiteral("131072"),
    };
}

QVariantList PlotSpectrumModel::windowFuncNames() const
{
    QVariantList names;
    const int count = NumWindowFuncs();
    names.reserve(count);
    for (int i = 0; i < count; ++i) {
        const QString name = QString::fromStdString(au::au3::wxToStdString(WindowFuncName(i).Translation()));
        names.append(muse::qtrc("project/plotspectrum", "%1 window").arg(name));
    }
    return names;
}

QVariantList PlotSpectrumModel::axisNames() const
{
    return {
        muse::qtrc("project/plotspectrum", "Linear frequency"),
        muse::qtrc("project/plotspectrum", "Log frequency"),
    };
}

void PlotSpectrumModel::updateVisibleRange()
{
    if (!m_analyzer || !m_analyzer->hasEnoughData() || m_analyzer->analyst()->GetProcessedSize() == 0) {
        m_xMin = 0.0;
        m_xMax = 1.0;
        m_yMin = -90.0;
        m_yMax = 0.0;
        m_panMax = 0;
        m_panPage = 1;
        emit panRangeChanged();
        emit rangeChanged();
        return;
    }

    const float dataYMin = m_analyzer->yMin();
    const float dataYMax = m_analyzer->yMax();
    const float yRange = dataYMax - dataYMin;
    const float yTotal = yRange * (static_cast<float>(m_zoom) / 100.0f);

    m_panPage = std::max(1, static_cast<int>(yTotal * 100.0f));
    m_panMax = std::max(m_panPage, static_cast<int>(yRange * 100.0f));
    m_pan = std::clamp(m_pan, 0, std::max(0, m_panMax - m_panPage));

    m_yMax = dataYMax - (static_cast<float>(m_pan) / 100.0f);
    m_yMin = m_yMax - yTotal;

    if (m_analyzer->algorithm() == SpectrumAnalyst::Spectrum) {
        m_xMin = m_analyzer->rate() / m_analyzer->windowSize();
        m_xMax = m_analyzer->rate() / 2.0;
    } else {
        m_xMin = 0.0;
        m_xMax = m_analyzer->analyst()->GetProcessedSize() / m_analyzer->rate();
    }

    emit panRangeChanged();
    emit panChanged();
    emit rangeChanged();
}

double PlotSpectrumModel::xStep(int width) const
{
    if (width <= 0 || m_xMax <= m_xMin) {
        return 1.0;
    }

    if (logAxis()) {
        const float ratio = static_cast<float>(m_xMax / m_xMin);
        return std::pow(2.0f, (std::log(ratio) / std::log(2.0f)) / width);
    }

    return (m_xMax - m_xMin) / width;
}

double PlotSpectrumModel::xAtPixel(int pixel, int width) const
{
    if (logAxis()) {
        return m_xMin * std::pow(xStep(width), pixel);
    }
    return m_xMin + xStep(width) * pixel;
}

void PlotSpectrumModel::rebuildPlot()
{
    m_plotSamples.clear();

    if (!m_analyzer || !m_analyzer->hasEnoughData() || m_analyzer->analyst()->GetProcessedSize() == 0 || m_plotWidth <= 0) {
        rebuildTicks();
        emit plotChanged();
        return;
    }

    const int width = m_plotWidth;
    const double yTotal = m_yMax - m_yMin;
    m_plotSamples.reserve(width);

    for (int i = 0; i < width; ++i) {
        const double x0 = xAtPixel(i, width);
        const double x1 = logAxis() ? x0 * xStep(width) : x0 + xStep(width);
        const float y = m_analyzer->analyst()->GetProcessedValue(static_cast<float>(x0), static_cast<float>(x1));
        double norm = yTotal > 0.0 ? (y - m_yMin) / yTotal : 0.0;
        norm = std::clamp(norm, 0.0, 1.0);
        m_plotSamples.append(norm);
    }

    rebuildTicks();
    emit plotChanged();
}

void PlotSpectrumModel::rebuildTicks()
{
    m_xTicks.clear();
    m_yTicks.clear();

    const shared::AxisScale xScale = logAxis() ? shared::AxisScale::Logarithmic : shared::AxisScale::Linear;
    const shared::AxisTicks xAxisTicks = shared::axisTicks(m_xMin, m_xMax, xScale);
    const auto xLabels = shared::labelsForTicks(xAxisTicks.major, m_labelWidth, std::max(1, m_plotWidth));
    for (size_t i = 0; i < xAxisTicks.major.size(); ++i) {
        m_xTicks.append(tickMap(QString::fromStdString(xLabels[i]), xAxisTicks.major[i].position));
    }
    for (const auto& tick : xAxisTicks.minor) {
        m_xTicks.append(tickMap(QString(), tick.position));
    }

    // Vertical axis is drawn top=max to bottom=min; positions are from bottom (0) to top (1)
    const shared::AxisTicks yAxisTicks = shared::axisTicks(m_yMin, m_yMax, shared::AxisScale::Linear);
    const auto yLabels = shared::labelsForTicks(yAxisTicks.major, m_labelHeight, 240);
    for (size_t i = 0; i < yAxisTicks.major.size(); ++i) {
        m_yTicks.append(tickMap(QString::fromStdString(yLabels[i]), yAxisTicks.major[i].position));
    }
    for (const auto& tick : yAxisTicks.minor) {
        m_yTicks.append(tickMap(QString(), tick.position));
    }
}

void PlotSpectrumModel::updateHover(double x, double y, double width, double height)
{
    Q_UNUSED(y)
    Q_UNUSED(height)

    if (!m_analyzer || !m_analyzer->hasEnoughData() || m_analyzer->analyst()->GetProcessedSize() == 0
        || width <= 2.0 || x <= 0.0 || x >= width - 1.0) {
        clearHover();
        return;
    }

    const int pixel = static_cast<int>(x);
    const int plotW = static_cast<int>(width);
    const double xPos = xAtPixel(pixel, plotW);
    const double nextX = logAxis() ? xPos * xStep(plotW) : xPos + xStep(plotW);
    const float value = m_analyzer->analyst()->GetProcessedValue(static_cast<float>(xPos), static_cast<float>(nextX));

    float bestValue = 0.f;
    const float bestPeak = m_analyzer->analyst()->FindPeak(static_cast<float>(xPos), &bestValue);

    if (logAxis()) {
        m_peakPosition = std::log(bestPeak / m_xMin) / std::log(xStep(plotW)) / (width - 2.0);
    } else {
        m_peakPosition = (bestPeak - m_xMin) / (m_xMax - m_xMin);
    }
    m_peakPosition = std::clamp(m_peakPosition, 0.0, 1.0);

    if (m_analyzer->algorithm() == SpectrumAnalyst::Spectrum) {
        m_cursorText = muse::qtrc("project/plotspectrum", "%1 Hz (%2) = %3 dB")
                       .arg(static_cast<int>(xPos + 0.5))
                       .arg(pitchName(xPos))
                       .arg(static_cast<int>(value + 0.5));
        m_peakText = muse::qtrc("project/plotspectrum", "%1 Hz (%2) = %3 dB")
                     .arg(static_cast<int>(bestPeak + 0.5))
                     .arg(pitchName(bestPeak))
                     .arg(bestValue, 0, 'f', 1);
    } else if (xPos > 0.0 && bestPeak > 0.0) {
        m_cursorText = muse::qtrc("project/plotspectrum", "%1 sec (%2 Hz) (%3) = %4")
                       .arg(xPos, 0, 'f', 4)
                       .arg(static_cast<int>(1.0 / xPos + 0.5))
                       .arg(pitchName(1.0 / xPos))
                       .arg(value);
        m_peakText = muse::qtrc("project/plotspectrum", "%1 sec (%2 Hz) (%3) = %4")
                     .arg(bestPeak, 0, 'f', 4)
                     .arg(static_cast<int>(1.0 / bestPeak + 0.5))
                     .arg(pitchName(1.0 / bestPeak))
                     .arg(bestValue, 0, 'f', 3);
    } else {
        m_cursorText.clear();
        m_peakText.clear();
    }

    m_hoverActive = true;
    emit hoverChanged();
}

void PlotSpectrumModel::clearHover()
{
    if (!m_hoverActive && m_cursorText.isEmpty() && m_peakText.isEmpty() && m_peakPosition < 0.0) {
        return;
    }

    m_hoverActive = false;
    m_cursorText.clear();
    m_peakText.clear();
    m_peakPosition = -1.0;
    emit hoverChanged();
}

void PlotSpectrumModel::exportData()
{
    if (!m_analyzer || !m_analyzer->hasEnoughData() || m_analyzer->analyst()->GetProcessedSize() == 0) {
        return;
    }

    const muse::io::path_t path = interactive()->selectSavingFileSync(
        muse::trc("project/plotspectrum", "Export Spectral Data As:"),
        muse::io::path_t("spectrum.txt"),
        { muse::trc("project/plotspectrum", "Text files") + " (*.txt)",
          muse::trc("project/plotspectrum", "All files") + " (*)" });

    if (path.empty()) {
        return;
    }

    QFile file(QString::fromStdString(path.toStdString()));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        interactive()->error(
            muse::trc("project/plotspectrum", "Error"),
            muse::qtrc("project/plotspectrum", "Couldn't write to file: %1")
            .arg(QString::fromStdString(path.toStdString())).toStdString());
        return;
    }

    QTextStream out(&file);
    const int processedSize = m_analyzer->analyst()->GetProcessedSize();
    const float* processed = m_analyzer->analyst()->GetProcessed();

    if (m_analyzer->algorithm() == SpectrumAnalyst::Spectrum) {
        out << muse::qtrc("project/plotspectrum", "Frequency (Hz)\tLevel (dB)") << '\n';
        for (int i = 1; i < processedSize; ++i) {
            out << (i * m_analyzer->rate() / m_analyzer->windowSize()) << '\t' << processed[i] << '\n';
        }
    } else {
        out << muse::qtrc("project/plotspectrum", "Lag (seconds)\tFrequency (Hz)\tLevel") << '\n';
        for (int i = 1; i < processedSize; ++i) {
            out << (i / m_analyzer->rate()) << '\t' << (m_analyzer->rate() / i) << '\t' << processed[i] << '\n';
        }
    }
}
