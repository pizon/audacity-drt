/*
 * Audacity: A Digital Audio Editor
 */
#include "plotspectrumanalyzer.h"

#include "au3-preferences/Prefs.h"
#include "au3-project-rate/Decibels.h"

namespace au::project {
namespace {
constexpr int kSizeChoices[] = {
    128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072
};
constexpr int kSizeChoiceCount = static_cast<int>(sizeof(kSizeChoices) / sizeof(kSizeChoices[0]));

int windowSizeForChoice(int choice)
{
    if (choice < 0 || choice >= kSizeChoiceCount) {
        choice = 3;
    }
    return kSizeChoices[choice];
}
}

PlotSpectrumAnalyzer::PlotSpectrumAnalyzer(AudacityProject& project)
    : PlotSpectrumBase(project)
{
    mWindowSize = windowSizeForChoice(mSize);

    dBRange = DecibelScaleCutoff.Read();
    if (dBRange < 90) {
        dBRange = 90;
    }
}

bool PlotSpectrumAnalyzer::loadAudio()
{
    return GetAudio();
}

void PlotSpectrumAnalyzer::setSizeChoice(int value)
{
    mSize = value;
    mWindowSize = windowSizeForChoice(mSize);
}

bool PlotSpectrumAnalyzer::recalculate(SpectrumAnalyst::ProgressFn progress)
{
    mYMin = 0.f;
    mYMax = 0.f;

    if (!hasEnoughData()) {
        return false;
    }

    const bool ok = mAnalyst->Calculate(
        mAlg, mFunc, mWindowSize, mRate,
        mData.get(), mDataLen,
        &mYMin, &mYMax, std::move(progress));

    if (!ok) {
        return false;
    }

    if (mAlg == SpectrumAnalyst::Spectrum) {
        if (mYMin < -dBRange) {
            mYMin = -dBRange;
        }
        if (mYMax <= -dBRange) {
            mYMax = -dBRange + 10.f;
        } else {
            mYMax += .5f;
        }
    }

    return true;
}

void PlotSpectrumAnalyzer::savePrefs() const
{
    gPrefs->Write(wxT("/FrequencyPlotDialog/DrawGrid"), mDrawGrid);
    gPrefs->Write(wxT("/FrequencyPlotDialog/SizeChoice"), mSize);
    gPrefs->Write(wxT("/FrequencyPlotDialog/AlgChoice"), static_cast<int>(mAlg));
    gPrefs->Write(wxT("/FrequencyPlotDialog/FuncChoice"), mFunc);
    gPrefs->Write(wxT("/FrequencyPlotDialog/AxisChoice"), mAxis);
    gPrefs->Flush();
}
}
