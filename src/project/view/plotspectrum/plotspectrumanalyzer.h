/*
 * Audacity: A Digital Audio Editor
 */
#pragma once

#include "au3-builtin-effects/PlotSpectrumBase.h"

namespace au::project {
//! Thin public wrapper around the au3 Plot Spectrum analysis engine.
class PlotSpectrumAnalyzer : public PlotSpectrumBase
{
public:
    explicit PlotSpectrumAnalyzer(AudacityProject& project);

    bool loadAudio();
    bool recalculate(SpectrumAnalyst::ProgressFn progress = nullptr);

    SpectrumAnalyst* analyst() const { return mAnalyst.get(); }

    bool drawGrid() const { return mDrawGrid; }
    void setDrawGrid(bool value) { mDrawGrid = value; }

    int sizeChoice() const { return mSize; }
    void setSizeChoice(int value);

    SpectrumAnalyst::Algorithm algorithm() const { return mAlg; }
    void setAlgorithm(SpectrumAnalyst::Algorithm value) { mAlg = value; }

    int windowFunc() const { return mFunc; }
    void setWindowFunc(int value) { mFunc = value; }

    int axisChoice() const { return mAxis; }
    void setAxisChoice(int value) { mAxis = value; }

    int dbRange() const { return dBRange; }
    void setDbRange(int value) { dBRange = value; }

    double rate() const { return mRate; }
    size_t dataLen() const { return mDataLen; }
    size_t windowSize() const { return mWindowSize; }
    bool hasEnoughData() const { return mData && mDataLen >= mWindowSize; }

    float yMin() const { return mYMin; }
    float yMax() const { return mYMax; }

    void savePrefs() const;

private:
    float mYMin = 0.f;
    float mYMax = 0.f;
};
}
