/*
 * Audacity: A Digital Audio Editor
 */
#include "axislabel.h"

#include "framework/global/translation.h"

#include <QString>

#include <algorithm>
#include <cmath>

namespace au {
namespace {
std::string valueToLabel(double value, int decimalDigits)
{
    if (value >= 1000 && decimalDigits < 3) {
        auto label = QString::number(value / 1000, 'f', decimalDigits);
        // Trim trailing zeros and a trailing dot, without using regex.
        while (((label.contains('.') && (label.endsWith('0'))) || label.endsWith('.'))) {
            label.chop(1);
        }
        return label.toStdString() + muse::trc("axis", "k");
    } else {
        return QString::number(value, 'f', decimalDigits).toStdString();
    }
}

// Higher is rounder: 1 * 10^n, then 5 * 10^n, then 2 * 10^n, then anything else.
int roundness(double value)
{
    value = std::abs(value);
    if (value == 0) {
        return 3;
    }
    const auto mantissa = value / std::pow(10., std::floor(std::log10(value)));
    const auto isMantissa = [mantissa](double m) { return std::abs(mantissa - m) < 1e-6 * m; };
    if (isMantissa(1) || isMantissa(10)) {
        return 3;
    }
    if (isMantissa(5)) {
        return 2;
    }
    if (isMantissa(2)) {
        return 1;
    }
    return 0;
}

struct TickAndIndex {
    shared::AxisTick tick;
    int index = 0;
};

void removeOverlappingTicks(std::vector<TickAndIndex>& ticks, double labelSize, double axisSize)
{
    if (ticks.size() <= 1) {
        return;
    }

    const auto minDistance = labelSize / axisSize;
    // The labels of the first and last ticks are kept inside the axis rather than centered on their tick,
    // so they need an extra half label of clearance.
    const auto minDistanceToEnd = minDistance * 1.5;

    const TickAndIndex first = ticks.front();
    const TickAndIndex last = ticks.back();
    const auto lastFits = std::abs(last.tick.position - first.tick.position) >= minDistance;

    // Rounder values get the first pick of the free space.
    std::vector<TickAndIndex> candidates(ticks.begin() + 1, ticks.end() - 1);
    std::stable_sort(candidates.begin(), candidates.end(), [](const TickAndIndex& a, const TickAndIndex& b) {
        return roundness(a.tick.val) > roundness(b.tick.val);
    });

    std::vector<TickAndIndex> kept;
    for (const auto& candidate : candidates) {
        const auto pos = candidate.tick.position;
        if (std::abs(pos - first.tick.position) < minDistanceToEnd
            || (lastFits && std::abs(last.tick.position - pos) < minDistanceToEnd)) {
            continue;
        }
        const auto overlaps = std::any_of(kept.begin(), kept.end(), [pos, minDistance](const TickAndIndex& k) {
            return std::abs(k.tick.position - pos) < minDistance;
        });
        if (!overlaps) {
            kept.push_back(candidate);
        }
    }

    kept.push_back(first);
    if (lastFits) {
        kept.push_back(last);
    }
    std::sort(kept.begin(), kept.end(), [](const TickAndIndex& a, const TickAndIndex& b) {
        return a.tick.position < b.tick.position;
    });
    ticks = std::move(kept);
}
}

std::vector<std::string> shared::labelsForTicks(const std::vector<AxisTick>& ticks, double labelSize, double axisSize,
                                                int maxDecimalDigits)
{
    if (ticks.empty()) {
        return {};
    }

    std::vector<TickAndIndex> ticksWithIndex;
    ticksWithIndex.reserve(ticks.size());
    std::transform(ticks.begin(), ticks.end(), std::back_inserter(ticksWithIndex), [index = 0](const AxisTick& tick) mutable {
        return TickAndIndex { tick, index++ };
    });
    removeOverlappingTicks(ticksWithIndex, labelSize, axisSize);

    std::vector<std::string> labels;
    labels.resize(ticks.size());
    int numDecimalDigits = 0;
    while (numDecimalDigits <= maxDecimalDigits) {
        for (const auto& tick : ticksWithIndex) {
            labels[tick.index] = valueToLabel(tick.tick.val, numDecimalDigits);
        }
        const auto someLabelsAreTheSame = std::adjacent_find(labels.begin(), labels.end(), [](const std::string& a, const std::string& b) {
            return !(a.empty() || b.empty()) && a == b;
        }) != labels.end();
        if (!someLabelsAreTheSame) {
            break;
        }
        ++numDecimalDigits;
    }
    return labels;
}
}
