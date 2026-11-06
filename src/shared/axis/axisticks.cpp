/*
 * Audacity: A Digital Audio Editor
 */
#include "axisticks.h"

#include "numberscale.h"

#include "framework/global/log.h"
#include "framework/global/types/number.h"

#include <algorithm>
#include <cmath>

namespace au {
namespace {
// Sorted by decreasing value.
std::vector<double> getTicksValues(double maxVal, double minVal, double step, shared::AxisScale scale)
{
    using namespace shared;

    std::vector<double> values;
    auto tick = std::floor(maxVal / step) * step;
    while (tick >= minVal) {
        if (scale == AxisScale::Logarithmic && tick <= 0) {
            break;
        }
        values.push_back(tick);
        tick -= step;
    }
    return values;
}

std::vector<shared::AxisTick> toTicks(const std::vector<double>& values, const shared::NumberScale& numberScale)
{
    using namespace shared;

    std::vector<AxisTick> ticks;
    ticks.reserve(values.size());
    std::transform(values.begin(), values.end(), std::back_inserter(ticks), [&numberScale](double value) {
        return AxisTick { value, static_cast<double>(numberScale.valueToPosition(static_cast<float>(value))) };
    });

    // Sort ascending by position so the overlap-rejection loop is orientation-agnostic.
    std::sort(ticks.begin(), ticks.end(), [](const AxisTick& a, const AxisTick& b) {
        return a.position < b.position;
    });

    return ticks;
}

bool containsValue(const std::vector<double>& values, double value)
{
    return std::any_of(values.begin(), values.end(), [value](double v) { return muse::is_equal(v, value); });
}

// Ensures min and max are major bookends, and that no minor tick duplicates a major one.
shared::AxisTicks makeAxisTicks(std::vector<double> majorValues, std::vector<double> minorValues, double min, double max,
                                const shared::NumberScale& numberScale)
{
    if (!containsValue(majorValues, max)) {
        majorValues.push_back(max);
    }
    if (!containsValue(majorValues, min)) {
        majorValues.push_back(min);
    }
    minorValues.erase(std::remove_if(minorValues.begin(), minorValues.end(), [&majorValues](double minorValue) {
        return containsValue(majorValues, minorValue);
    }),
                      minorValues.end());

    return { toTicks(majorValues, numberScale), toTicks(minorValues, numberScale) };
}

shared::AxisTicks steppedAxisTicks(double min, double max, shared::AxisScale scale, const shared::NumberScale& numberScale)
{
    const auto range = max - min;
    auto minorPerMajor = 10;

    auto majorStep = std::pow(10, std::floor(std::log10(range)));
    if (muse::is_equal(majorStep, range)) {
        majorStep = range / 10;
    }
    // Too sparse major ticks don't look good. Double the rate of major ticks,
    // but preserve 10 steps per decade.
    if (range / majorStep < shared::kMinMajorTicks) {
        majorStep /= 2;
        minorPerMajor = 5;
    }

    const auto minorStep = majorStep / minorPerMajor;
    return makeAxisTicks(getTicksValues(max, min, majorStep, scale), getTicksValues(max, min, minorStep, scale), min, max,
                         numberScale);
}

// Ticks at every digit of every decade, i.e. m * 10^e for m in [1, 9], which are evenly spread on a log axis.
// 1, 2 and 5 are majors; the other digits are minors.
shared::AxisTicks decadeAxisTicks(double min, double max, const shared::NumberScale& numberScale)
{
    std::vector<double> majorValues;
    std::vector<double> minorValues;
    for (auto exponent = std::floor(std::log10(min)); ; ++exponent) {
        const auto decade = std::pow(10., exponent);
        if (decade > max) {
            break;
        }
        for (auto mantissa = 1; mantissa <= 9; ++mantissa) {
            const auto value = mantissa * decade;
            if (value < min || value > max) {
                continue;
            }
            const auto isMajor = mantissa == 1 || mantissa == 2 || mantissa == 5;
            (isMajor ? majorValues : minorValues).push_back(value);
        }
    }
    return makeAxisTicks(std::move(majorValues), std::move(minorValues), min, max, numberScale);
}
}

shared::AxisTicks shared::axisTicks(double min, double max, AxisScale scale)
{
    const auto range = max - min;
    if (range <= 0) {
        LOGE() << "Invalid range: " << range;
        return {};
    }

    const auto safeMin = scale == AxisScale::Logarithmic ? std::max(min, 1e-6) : min;
    const auto numberScale = NumberScale{ scale, safeMin, max };

    if (scale == AxisScale::Logarithmic) {
        // When zoomed in to a fraction of a decade, the log axis is close to linear, and stepped ticks are denser.
        auto ticks = decadeAxisTicks(safeMin, max, numberScale);
        if (ticks.major.size() >= static_cast<size_t>(kMinMajorTicks)) {
            return ticks;
        }
    }

    return steppedAxisTicks(safeMin, max, scale, numberScale);
}
}
