import React from 'react';
import { StyleSheet, View, ScrollView, Text, TouchableOpacity } from 'react-native';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { useTheme } from '@/hooks/use-theme';
import { useExpenseStore } from '@/store/useExpenseStore';
import { BottomTabInset } from '@/constants/theme';
import { Ionicons } from '@expo/vector-icons';

export default function ProfileScreen() {
  const theme = useTheme();
  const { currentUser } = useExpenseStore();

  return (
    <ThemedView style={styles.container}>
      <View style={styles.header}>
        <ThemedText type="title">Profile</ThemedText>
      </View>

      <ScrollView
        contentContainerStyle={[styles.scrollContent, { paddingBottom: BottomTabInset + 24 }]}
        showsVerticalScrollIndicator={false}
      >
        <View style={[styles.profileCard, { backgroundColor: theme.backgroundElement }]}>
          <View style={[styles.avatar, { backgroundColor: '#6366F1' }]}>
            <Text style={styles.avatarText}>
              {currentUser.fullName.charAt(0)}
            </Text>
          </View>
          <View style={styles.profileInfo}>
            <Text style={[styles.name, { color: theme.text }]}>{currentUser.fullName}</Text>
            <Text style={[styles.email, { color: theme.textSecondary }]}>{currentUser.email}</Text>
          </View>
        </View>

        <View style={styles.settingsGroup}>
          <Text style={[styles.settingsTitle, { color: theme.textSecondary }]}>ACCOUNT</Text>
          <TouchableOpacity style={[styles.settingsRow, { backgroundColor: theme.backgroundElement }]}>
            <Ionicons name="card-outline" size={20} color={theme.text} />
            <Text style={[styles.settingsRowText, { color: theme.text }]}>Payment Methods (VPA: {currentUser.vpaId})</Text>
            <Ionicons name="chevron-forward" size={20} color={theme.textSecondary} />
          </TouchableOpacity>
          <TouchableOpacity style={[styles.settingsRow, { backgroundColor: theme.backgroundElement }]}>
            <Ionicons name="notifications-outline" size={20} color={theme.text} />
            <Text style={[styles.settingsRowText, { color: theme.text }]}>Notifications</Text>
            <Ionicons name="chevron-forward" size={20} color={theme.textSecondary} />
          </TouchableOpacity>
        </View>

        <View style={styles.settingsGroup}>
          <Text style={[styles.settingsTitle, { color: theme.textSecondary }]}>APP</Text>
          <TouchableOpacity style={[styles.settingsRow, { backgroundColor: theme.backgroundElement }]}>
            <Ionicons name="color-palette-outline" size={20} color={theme.text} />
            <Text style={[styles.settingsRowText, { color: theme.text }]}>Theme Settings</Text>
            <Ionicons name="chevron-forward" size={20} color={theme.textSecondary} />
          </TouchableOpacity>
          <TouchableOpacity style={[styles.settingsRow, { backgroundColor: theme.backgroundElement }]}>
            <Ionicons name="help-circle-outline" size={20} color={theme.text} />
            <Text style={[styles.settingsRowText, { color: theme.text }]}>Help & Support</Text>
            <Ionicons name="chevron-forward" size={20} color={theme.textSecondary} />
          </TouchableOpacity>
        </View>

        <TouchableOpacity style={styles.logoutBtn}>
          <Text style={styles.logoutText}>Log Out</Text>
        </TouchableOpacity>
      </ScrollView>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    paddingHorizontal: 16,
    paddingTop: 60,
    paddingBottom: 16,
  },
  scrollContent: {
    padding: 16,
    gap: 24,
  },
  profileCard: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 20,
    borderRadius: 16,
    gap: 16,
  },
  avatar: {
    width: 64,
    height: 64,
    borderRadius: 32,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    fontSize: 24,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  profileInfo: {
    flex: 1,
  },
  name: {
    fontSize: 20,
    fontWeight: '700',
  },
  email: {
    fontSize: 14,
    marginTop: 2,
  },
  settingsGroup: {
    gap: 8,
  },
  settingsTitle: {
    fontSize: 12,
    fontWeight: '700',
    letterSpacing: 1,
    marginLeft: 8,
    marginBottom: 4,
  },
  settingsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    borderRadius: 12,
    gap: 12,
    marginBottom: 4,
  },
  settingsRowText: {
    flex: 1,
    fontSize: 16,
    fontWeight: '500',
  },
  logoutBtn: {
    marginTop: 16,
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
    backgroundColor: 'rgba(239, 68, 68, 0.1)',
  },
  logoutText: {
    color: '#EF4444',
    fontSize: 16,
    fontWeight: '700',
  },
});
