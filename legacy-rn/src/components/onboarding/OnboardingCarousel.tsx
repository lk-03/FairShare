import React, { useState, useRef } from 'react';
import {
  View,
  Text,
  Image,
  TouchableOpacity,
  ScrollView,
  useWindowDimensions,
  useColorScheme,
  NativeSyntheticEvent,
  NativeScrollEvent,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useThemeStore, getThemePalette } from '../../store/useThemeStore';
import { AppLogo } from '../ui/AppLogo';

interface OnboardingCarouselProps {
  onComplete: () => void;
  onSkip: () => void;
}

export function OnboardingCarousel({ onComplete, onSkip }: OnboardingCarouselProps) {
  const systemScheme = useColorScheme();
  const { width: SCREEN_WIDTH } = useWindowDimensions();
  const { themeBase, colorScheme } = useThemeStore();
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

  const [currentSlide, setCurrentSlide] = useState(0);
  const scrollViewRef = useRef<ScrollView>(null);

  const slides = [
    {
      badge: 'ALGORITHM POWERED',
      badgeColor: colors.cyan,
      title: 'Split Smarter,\nSettle Faster',
      description:
        'Stop dealing with tangled group IOUs. FairShare calculates the minimum cash transfers so everyone settles with the fewest possible payments.',
      renderGraphic: () => (
        <View
          className="w-full p-4 rounded-3xl gap-3 border shadow-sm"
          style={{
            backgroundColor: isDark ? colors.surface : '#FFFFFF',
            borderColor: colors.border,
          }}
        >
          <View className="flex-row items-center justify-between">
            <Text className="text-[11px] font-bold uppercase tracking-wider" style={{ color: colors.cyan }}>
              DEBT SIMPLIFICATION
            </Text>
            <View
              className="px-2 py-0.5 rounded-full"
              style={{ backgroundColor: `${colors.emerald}25` }}
            >
              <Text className="text-[10px] font-bold" style={{ color: colors.emerald }}>
                2 Fewer Payments
              </Text>
            </View>
          </View>

          {/* Before */}
          <View
            className="p-2.5 rounded-2xl gap-1.5"
            style={{
              backgroundColor: isDark ? colors.accentPill : '#F1F5F9',
              borderWidth: 1,
              borderColor: colors.border,
            }}
          >
            <Text className="text-[10px] font-bold uppercase tracking-wider" style={{ color: colors.textSecondary }}>
              Before: 3 Tangled Debts
            </Text>
            <View className="flex-row items-center justify-between">
              <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                Alex owes Sam ₹300
              </Text>
              <Text className="text-xs font-semibold" style={{ color: colors.textSecondary }}>
                Sam owes Pri ₹750
              </Text>
            </View>
          </View>

          {/* Arrow */}
          <View className="items-center -my-1">
            <Ionicons name="arrow-down-circle" size={20} color={colors.cyan} />
          </View>

          {/* After Simplified */}
          <View
            className="p-3 rounded-2xl flex-row items-center justify-between"
            style={{
              backgroundColor: `${colors.emerald}15`,
              borderWidth: 1,
              borderColor: `${colors.emerald}40`,
            }}
          >
            <View className="flex-row items-center gap-2">
              <View
                className="w-7 h-7 rounded-full items-center justify-center"
                style={{ backgroundColor: colors.emerald }}
              >
                <Ionicons name="checkmark" size={16} color="#FFFFFF" />
              </View>
              <View>
                <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                  Alex pays Pri ₹450
                </Text>
                <Text className="text-[10px] font-semibold" style={{ color: colors.emerald }}>
                  Fully Settled in 1 Payment
                </Text>
              </View>
            </View>
            <Text className="text-sm font-black" style={{ color: colors.emerald }}>
              ₹450
            </Text>
          </View>
        </View>
      ),
    },
    {
      badge: 'INSTANT & ZERO FEES',
      badgeColor: colors.emerald,
      title: 'Pay Directly.\nNo Middleman Fees.',
      description:
        'Settle debts directly into any UPI app. 1-tap opens Google Pay, PhonePe, or Paytm with the payee and amount pre-filled.',
      renderGraphic: () => (
        <View
          className="w-full p-4 rounded-3xl gap-3 border shadow-sm"
          style={{
            backgroundColor: isDark ? colors.surface : '#FFFFFF',
            borderColor: colors.border,
          }}
        >
          <View className="flex-row items-center justify-between">
            <Text className="text-[11px] font-bold uppercase tracking-wider" style={{ color: colors.emerald }}>
              DIRECT UPI INTENT
            </Text>
            <View
              className="flex-row items-center gap-1 px-2 py-0.5 rounded-full"
              style={{ backgroundColor: `${colors.cyan}20` }}
            >
              <Ionicons name="shield-checkmark" size={12} color={colors.cyan} />
              <Text className="text-[10px] font-bold" style={{ color: colors.cyan }}>
                Verified VPA
              </Text>
            </View>
          </View>

          <View
            className="flex-row items-center justify-between p-3 rounded-2xl"
            style={{
              backgroundColor: isDark ? colors.accentPill : '#F1F5F9',
              borderWidth: 1,
              borderColor: colors.border,
            }}
          >
            <View>
              <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                Settle up with Rahul
              </Text>
              <Text className="text-[11px] font-semibold" style={{ color: colors.cyan }}>
                rahul@okhdfcbank
              </Text>
            </View>
            <Text className="text-base font-black" style={{ color: colors.cyan }}>
              ₹620.00
            </Text>
          </View>

          {/* Quick UPI App Badges */}
          <View className="flex-row items-center justify-between gap-2 pt-1">
            <View
              className="flex-1 py-2 rounded-xl items-center border"
              style={{ backgroundColor: colors.surface, borderColor: colors.border }}
            >
              <Text className="text-xs font-extrabold" style={{ color: colors.cyan }}>
                GPay
              </Text>
            </View>
            <View
              className="flex-1 py-2 rounded-xl items-center border"
              style={{ backgroundColor: colors.surface, borderColor: colors.border }}
            >
              <Text className="text-xs font-extrabold text-indigo-400">
                PhonePe
              </Text>
            </View>
            <View
              className="flex-1 py-2 rounded-xl items-center border"
              style={{ backgroundColor: colors.surface, borderColor: colors.border }}
            >
              <Text className="text-xs font-extrabold text-sky-400">
                Paytm
              </Text>
            </View>
          </View>
        </View>
      ),
    },
    {
      badge: 'FLEXIBLE MATH',
      badgeColor: colors.cyan,
      title: '5 Granular\nSplit Modes',
      description:
        'Split by Equal shares, Exact rupees, Percentages (%), Custom Ratios (2:1:1), or Adjustments with auto-calculated remainder.',
      renderGraphic: () => (
        <View
          className="w-full p-4 rounded-3xl gap-3 border shadow-sm"
          style={{
            backgroundColor: isDark ? colors.surface : '#FFFFFF',
            borderColor: colors.border,
          }}
        >
          <View className="flex-row items-center justify-between">
            <Text className="text-[11px] font-bold uppercase tracking-wider" style={{ color: colors.cyan }}>
              SPLIT ENGINES
            </Text>
            <Text className="text-[10px] font-bold" style={{ color: colors.textSecondary }}>
              Custom Ratios & %
            </Text>
          </View>

          {/* Mode Badges */}
          <View className="flex-row flex-wrap gap-1.5">
            {['Equal', 'Unequal', 'Percent (%)', 'Shares (2:1)', 'Adjust'].map((mode, i) => (
              <View
                key={mode}
                className="px-2.5 py-1 rounded-xl border"
                style={{
                  backgroundColor: i === 3 ? `${colors.cyan}25` : colors.accentPill,
                  borderColor: i === 3 ? colors.cyan : colors.border,
                }}
              >
                <Text
                  className="text-[10px] font-bold"
                  style={{ color: i === 3 ? colors.cyan : colors.textSecondary }}
                >
                  {mode}
                </Text>
              </View>
            ))}
          </View>

          {/* Split Visual Bar */}
          <View
            className="p-3 rounded-2xl gap-2"
            style={{
              backgroundColor: isDark ? colors.accentPill : '#F1F5F9',
              borderWidth: 1,
              borderColor: colors.border,
            }}
          >
            <View className="flex-row items-center justify-between">
              <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                Dinner at Biggies (₹900)
              </Text>
              <Text className="text-xs font-bold" style={{ color: colors.cyan }}>
                3 Members
              </Text>
            </View>

            <View className="h-2 rounded-full flex-row overflow-hidden w-full bg-slate-700/20">
              <View className="flex-[2] h-full bg-cyan-400" />
              <View className="flex-[1] h-full bg-emerald-400" />
              <View className="flex-[1] h-full bg-amber-400" />
            </View>

            <View className="flex-row items-center justify-between">
              <Text className="text-[10px] font-semibold" style={{ color: colors.textSecondary }}>
                Alex: ₹450 (2x)
              </Text>
              <Text className="text-[10px] font-semibold" style={{ color: colors.textSecondary }}>
                Sam: ₹225 (1x)
              </Text>
              <Text className="text-[10px] font-semibold" style={{ color: colors.textSecondary }}>
                Pri: ₹225 (1x)
              </Text>
            </View>
          </View>
        </View>
      ),
    },
    {
      badge: 'HOUSEHOLD & TRIPS',
      badgeColor: colors.amber,
      title: 'Shared House Cart\n& Needs List',
      description:
        'Keep a shared household supply checklist. When someone buys an item, check it off to auto-convert it into a shared group expense!',
      renderGraphic: () => (
        <View
          className="w-full p-4 rounded-3xl gap-3 border shadow-sm"
          style={{
            backgroundColor: isDark ? colors.surface : '#FFFFFF',
            borderColor: colors.border,
          }}
        >
          <View className="flex-row items-center justify-between">
            <Text className="text-[11px] font-bold uppercase tracking-wider" style={{ color: colors.amber }}>
              SHARED HOUSE CART
            </Text>
            <View
              className="px-2 py-0.5 rounded-full"
              style={{ backgroundColor: `${colors.emerald}20` }}
            >
              <Text className="text-[10px] font-bold" style={{ color: colors.emerald }}>
                Auto-Log Expense
              </Text>
            </View>
          </View>

          {/* Checked Item */}
          <View
            className="flex-row items-center justify-between p-3 rounded-2xl"
            style={{
              backgroundColor: isDark ? colors.accentPill : '#F1F5F9',
              borderWidth: 1,
              borderColor: colors.border,
            }}
          >
            <View className="flex-row items-center gap-2">
              <Ionicons name="checkmark-circle" size={18} color={colors.emerald} />
              <Text
                className="text-xs font-bold line-through"
                style={{ color: colors.textSecondary }}
              >
                Water Can (20L)
              </Text>
            </View>
            <Text className="text-xs font-bold" style={{ color: colors.emerald }}>
              ₹90 (Auto-logged)
            </Text>
          </View>

          {/* Pending Item */}
          <View
            className="flex-row items-center justify-between p-3 rounded-2xl"
            style={{
              backgroundColor: isDark ? colors.accentPill : '#F1F5F9',
              borderWidth: 1,
              borderColor: colors.border,
            }}
          >
            <View className="flex-row items-center gap-2">
              <Ionicons name="ellipse-outline" size={18} color={colors.amber} />
              <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                Cooking Oil & Masalas
              </Text>
            </View>
            <Text className="text-[10px] font-semibold" style={{ color: colors.textSecondary }}>
              Urgent Need
            </Text>
          </View>
        </View>
      ),
    },
    {
      badge: 'EASY MIGRATION',
      badgeColor: colors.cyan,
      title: 'Splitwise CSV Import\n& 1-Tap Shortcuts',
      description:
        'Migrate years of Splitwise history with 1-tap CSV import, preserve shadow member history, and bookmark frequent expenses as 1-tap shortcuts.',
      renderGraphic: () => (
        <View
          className="w-full p-4 rounded-3xl gap-3 border shadow-sm"
          style={{
            backgroundColor: isDark ? colors.surface : '#FFFFFF',
            borderColor: colors.border,
          }}
        >
          <View className="flex-row items-center justify-between">
            <Text className="text-[11px] font-bold uppercase tracking-wider" style={{ color: colors.cyan }}>
              IMPORT & PRESETS
            </Text>
            <View
              className="px-2 py-0.5 rounded-full"
              style={{ backgroundColor: `${colors.emerald}20` }}
            >
              <Text className="text-[10px] font-bold" style={{ color: colors.emerald }}>
                100% Free
              </Text>
            </View>
          </View>

          {/* CSV Import Demo */}
          <View
            className="flex-row items-center justify-between p-3 rounded-2xl"
            style={{
              backgroundColor: isDark ? colors.accentPill : '#F1F5F9',
              borderWidth: 1,
              borderColor: colors.border,
            }}
          >
            <View className="flex-row items-center gap-2.5">
              <View
                className="w-8 h-8 rounded-full items-center justify-center"
                style={{ backgroundColor: `${colors.cyan}20` }}
              >
                <Ionicons name="cloud-download-outline" size={16} color={colors.cyan} />
              </View>
              <View>
                <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                  Flatmates_export.csv
                </Text>
                <Text className="text-[10px] font-semibold" style={{ color: colors.cyan }}>
                  270+ Transactions Imported
                </Text>
              </View>
            </View>
            <Ionicons name="checkmark-done" size={18} color={colors.emerald} />
          </View>

          {/* Preset Shortcut Demo */}
          <View
            className="flex-row items-center justify-between p-3 rounded-2xl"
            style={{
              backgroundColor: isDark ? colors.accentPill : '#F1F5F9',
              borderWidth: 1,
              borderColor: colors.border,
            }}
          >
            <View className="flex-row items-center gap-2">
              <Ionicons name="bookmark" size={16} color={colors.cyan} />
              <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                Hostel Tea & Snacks
              </Text>
            </View>
            <Text className="text-[10px] font-bold" style={{ color: colors.cyan }}>
              1-TAP PRESET
            </Text>
          </View>
        </View>
      ),
    },
  ];

  const handleScroll = (event: NativeSyntheticEvent<NativeScrollEvent>) => {
    const slideIndex = Math.round(event.nativeEvent.contentOffset.x / SCREEN_WIDTH);
    if (slideIndex !== currentSlide && slideIndex >= 0 && slideIndex < slides.length) {
      setCurrentSlide(slideIndex);
    }
  };

  const goToSlide = (index: number) => {
    setCurrentSlide(index);
    scrollViewRef.current?.scrollTo({
      x: index * SCREEN_WIDTH,
      animated: true,
    });
  };

  const handleNext = () => {
    if (currentSlide < slides.length - 1) {
      goToSlide(currentSlide + 1);
    } else {
      onComplete();
    }
  };

  return (
    <View className="flex-1 justify-between pt-12 pb-6">
      {/* Top Bar with Skip & Branding */}
      <View className="flex-row items-center justify-between px-6 mb-2">
        <View className="flex-row items-center gap-2">
          <AppLogo size={28} withShadow withGlow />
          <Text className="text-base font-black tracking-tight" style={{ color: colors.textMain }}>
            FairShare
          </Text>
        </View>

        <TouchableOpacity onPress={onSkip} className="px-3 py-1.5 rounded-full" activeOpacity={0.7}>
          <Text className="text-xs font-bold" style={{ color: colors.textSecondary }}>
            Skip
          </Text>
        </TouchableOpacity>
      </View>

      {/* Swipeable Horizontal Carousel Pages */}
      <ScrollView
        ref={scrollViewRef}
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={handleScroll}
        className="flex-1"
        contentContainerClassName="items-center"
      >
        {slides.map((slide, index) => (
          <View
            key={index}
            style={{ width: SCREEN_WIDTH }}
            className="px-6 items-center justify-center my-auto gap-6"
          >
            {/* Slide Graphic */}
            <View className="w-full max-w-sm">{slide.renderGraphic()}</View>

            {/* Text Content */}
            <View className="gap-2.5 items-center text-center px-2">
              <View
                className="px-3 py-1 rounded-full"
                style={{ backgroundColor: `${slide.badgeColor}20` }}
              >
                <Text
                  className="text-[10px] font-black tracking-wider uppercase"
                  style={{ color: slide.badgeColor }}
                >
                  {slide.badge}
                </Text>
              </View>

              <Text
                className="text-2xl font-black text-center leading-8"
                style={{ color: colors.textMain }}
              >
                {slide.title}
              </Text>

              <Text
                className="text-xs font-semibold text-center leading-5 px-4"
                style={{ color: colors.textSecondary }}
              >
                {slide.description}
              </Text>
            </View>
          </View>
        ))}
      </ScrollView>

      {/* Bottom Controls */}
      <View className="gap-5 px-6 pt-2">
        {/* Interactive Pagination Dots */}
        <View className="flex-row items-center justify-center gap-2">
          {slides.map((_, idx) => {
            const isActive = idx === currentSlide;
            return (
              <TouchableOpacity
                key={idx}
                onPress={() => goToSlide(idx)}
                activeOpacity={0.7}
                className="h-2 rounded-full"
                style={{
                  width: isActive ? 24 : 8,
                  backgroundColor: isActive ? colors.cyan : colors.border,
                }}
              />
            );
          })}
        </View>

        {/* Next / Get Started Button */}
        <TouchableOpacity
          onPress={handleNext}
          className="h-14 rounded-2xl items-center justify-center shadow-lg"
          style={{ backgroundColor: colors.cyan }}
          activeOpacity={0.85}
        >
          <Text className="text-base font-black text-slate-900">
            {currentSlide === slides.length - 1 ? 'Get Started' : 'Next'}
          </Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}
