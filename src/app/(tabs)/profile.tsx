import React, { useState } from 'react';
import { View, ScrollView, TouchableOpacity } from 'react-native';
import { useExpenseStore } from '@/store/useExpenseStore';
import { BottomTabInset } from '@/constants/theme';
import { Ionicons } from '@expo/vector-icons';
import { Button } from '@/components/ui/Button';
import { Text } from '@/components/ui/Text';
import { ThemeSettingsModal } from '@/components/ThemeSettingsModal';

export default function ProfileScreen() {
  const { currentUser } = useExpenseStore();
  const [themeModalVisible, setThemeModalVisible] = useState(false);

  return (
    <View className="flex-1 bg-screen pt-safe">
      <View className="screen-header">
        <Text className="screen-title">Profile</Text>
        <Button variant="ghost" size="icon" className="btn-icon-circle" onPress={() => setThemeModalVisible(true)}>
          <Ionicons name="color-palette-outline" size={20} color="#94A3B8" />
        </Button>
      </View>

      <ScrollView
        contentContainerClassName="px-5 pb-10 gap-6"
        style={{ paddingBottom: BottomTabInset + 24 }}
        showsVerticalScrollIndicator={false}
      >
        <View className="card-main p-8 items-center mt-2">
          <View className="w-24 h-24 bg-accent-pill rounded-full items-center justify-center mb-4 border border-surface">
            <Text className="text-4xl font-bold text-main">
              {currentUser.fullName.charAt(0)}
            </Text>
          </View>
          <Text className="text-xl font-bold text-main mb-1">{currentUser.fullName}</Text>
          <Text className="text-sm text-secondary">{currentUser.email}</Text>
        </View>

        <View className="gap-3">
          <Text className="section-label ml-1 mb-1">
            ACCOUNT
          </Text>
          
          <TouchableOpacity activeOpacity={0.8} className="card-item">
            <View className="flex-row items-center gap-4 flex-1">
              <Ionicons name="card-outline" size={24} color="#94A3B8" />
              <View className="flex-1">
                <Text className="text-base font-bold text-main">Payment Methods</Text>
                <Text className="text-sm text-secondary">VPA: {currentUser.vpaId}</Text>
              </View>
            </View>
            <Ionicons name="chevron-forward" size={20} color="#94A3B8" />
          </TouchableOpacity>
          
          <TouchableOpacity activeOpacity={0.8} className="card-item">
            <View className="flex-row items-center gap-4 flex-1">
              <Ionicons name="notifications-outline" size={24} color="#94A3B8" />
              <View className="flex-1">
                <Text className="text-base font-bold text-main">Notifications</Text>
              </View>
            </View>
            <Ionicons name="chevron-forward" size={20} color="#94A3B8" />
          </TouchableOpacity>
        </View>

        <View className="gap-3 mt-2">
          <Text className="section-label ml-1 mb-1">
            APP & THEME
          </Text>
          
          <TouchableOpacity
            activeOpacity={0.8}
            className="card-item"
            onPress={() => setThemeModalVisible(true)}
          >
            <View className="flex-row items-center gap-4 flex-1">
              <Ionicons name="sparkles-outline" size={24} color="#38BDF8" />
              <View className="flex-1">
                <Text className="text-base font-bold text-main">Theme & Appearance</Text>
                <Text className="text-xs text-secondary mt-0.5">Choose from 4 aesthetic palettes</Text>
              </View>
            </View>
            <Ionicons name="chevron-forward" size={20} color="#94A3B8" />
          </TouchableOpacity>
          
          <TouchableOpacity activeOpacity={0.8} className="card-item">
            <View className="flex-row items-center gap-4 flex-1">
              <Ionicons name="help-circle-outline" size={24} color="#94A3B8" />
              <View className="flex-1">
                <Text className="text-base font-bold text-main">Help & Support</Text>
              </View>
            </View>
            <Ionicons name="chevron-forward" size={20} color="#94A3B8" />
          </TouchableOpacity>
        </View>

        <TouchableOpacity activeOpacity={0.8} className="w-full rounded-2xl py-4 mt-4 border border-surface bg-surface items-center shadow-sm">
          <Text className="text-base font-bold text-negative">Log Out</Text>
        </TouchableOpacity>
      </ScrollView>

      <ThemeSettingsModal
        visible={themeModalVisible}
        onClose={() => setThemeModalVisible(false)}
      />
    </View>
  );
}
