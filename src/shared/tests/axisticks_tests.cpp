/*
 * Audacity: A Digital Audio Editor
 */
#include "shared/axis/axislabel.h"
#include "shared/axis/axisticks.h"

#include "framework/global/types/number.h"

#include <gtest/gtest.h>

using namespace au::shared;

TEST(axisTicks, real_world_cases)
{
    // These test cases are based on real-world scenarios and helped tuning the algorithm.

    {
        constexpr auto min = 20.0;
        constexpr auto max = 24000.0;
        constexpr auto scale = AxisScale::Linear;
        const AxisTicks ticks = axisTicks(min, max, scale);

        EXPECT_GE(ticks.major.size(), kMinMajorTicks);

        // End ticks are always major and exactly on the min and max values.
        EXPECT_EQ(ticks.major.front().val, min);
        EXPECT_EQ(ticks.major.back().val, max);

        for (const auto freq : { 5000.0, 10000.0, 15000.0, 20000.0 }) {
            EXPECT_TRUE(std::any_of(ticks.major.begin(), ticks.major.end(), [freq](const AxisTick& tick) {
                return muse::is_equal(tick.val, freq);
            })) << "Expected major tick at " << freq;
        }
    }

    {
        constexpr auto min = 0.0;
        constexpr auto max = 23999.99609375;
        constexpr auto scale = AxisScale::Mel;
        const AxisTicks ticks = axisTicks(min, max, scale);

        EXPECT_GE(ticks.major.size(), kMinMajorTicks);

        // End ticks are always major and exactly on the min and max values.
        EXPECT_EQ(ticks.major.front().val, min);
        EXPECT_EQ(ticks.major.back().val, max);

        // Some expected major ticks
        EXPECT_TRUE(std::any_of(ticks.major.begin(), ticks.major.end(), [](const AxisTick& tick) {
            return muse::is_equal(tick.val, 10000.0);
        }));
        EXPECT_TRUE(std::any_of(ticks.major.begin(), ticks.major.end(), [](const AxisTick& tick) {
            return muse::is_equal(tick.val, 5000.0);
        }));
    }
}

namespace {
bool containsTick(const std::vector<AxisTick>& ticks, double val)
{
    return std::any_of(ticks.begin(), ticks.end(), [val](const AxisTick& tick) { return muse::is_equal(tick.val, val); });
}
}

TEST(axisTicks, logarithmic_scale_ticks_every_decade)
{
    constexpr auto min = 20.0;
    constexpr auto max = 20000.0;
    const AxisTicks ticks = axisTicks(min, max, AxisScale::Logarithmic);

    for (const auto freq : { 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0, 20000.0 }) {
        EXPECT_TRUE(containsTick(ticks.major, freq)) << "Expected major tick at " << freq;
    }
    for (const auto freq : { 30.0, 300.0, 3000.0, 9000.0 }) {
        EXPECT_TRUE(containsTick(ticks.minor, freq)) << "Expected minor tick at " << freq;
    }
    for (const auto& tick : ticks.minor) {
        EXPECT_FALSE(containsTick(ticks.major, tick.val)) << "Minor tick duplicates major tick at " << tick.val;
    }
}

TEST(axisTicks, logarithmic_scale_zoomed_within_a_decade)
{
    const AxisTicks ticks = axisTicks(1000.0, 3000.0, AxisScale::Logarithmic);
    EXPECT_GE(ticks.major.size(), kMinMajorTicks);
    EXPECT_TRUE(containsTick(ticks.major, 1500.0));
    EXPECT_TRUE(containsTick(ticks.major, 2500.0));
}

TEST(labelsForTicks, short_logarithmic_axis_keeps_round_labels)
{
    // A spectrogram channel of a multi-view track: short axis, 3 decades.
    constexpr auto labelHeight = 16.0;
    constexpr auto channelHeight = 120.0;
    const AxisTicks ticks = axisTicks(20.0, 20000.0, AxisScale::Logarithmic);
    const auto labels = labelsForTicks(ticks.major, labelHeight, channelHeight);
    ASSERT_EQ(labels.size(), ticks.major.size());

    std::vector<AxisTick> labelled;
    for (size_t i = 0; i < labels.size(); ++i) {
        if (!labels[i].empty()) {
            labelled.push_back(ticks.major[i]);
        }
    }

    EXPECT_GE(labelled.size(), 4u);
    EXPECT_TRUE(containsTick(labelled, 20.0));
    EXPECT_TRUE(containsTick(labelled, 20000.0));
    EXPECT_TRUE(containsTick(labelled, 100.0));
    EXPECT_TRUE(containsTick(labelled, 1000.0));

    for (size_t i = 1; i < labelled.size(); ++i) {
        EXPECT_GE(labelled[i].position - labelled[i - 1].position, labelHeight / channelHeight - 1e-9);
    }
}

TEST(axisTicks, normalized_scales_are_supported) {
    constexpr auto min = 0.0;
    constexpr auto max = 1.0;
    constexpr auto scale = AxisScale::Logarithmic;
    const AxisTicks ticks = axisTicks(min, max, scale);
    EXPECT_GE(ticks.major.size(), kMinMajorTicks);
}
