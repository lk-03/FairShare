import React, { useState, useMemo } from 'react';
import {
  View,
  TextInput,
  TouchableOpacity,
  ScrollView,
  Image,
  useColorScheme,
} from 'react-native';
import { Ionicons } from '@expo/vector-icons';
import { useExpenseStore } from '@/store/useExpenseStore';
import { useThemeStore, getThemePalette } from '@/store/useThemeStore';
import { TransactionComment, GroupMember, UserProfile } from '@/types';
import { MemberProfileModal } from '@/components/MemberProfileModal';
import { Text } from '@/components/ui/Text';

interface TransactionCommentsProps {
  expenseId: string;
  cohortId?: string;
}

export function TransactionComments({ expenseId, cohortId }: TransactionCommentsProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);
  const isDark =
    colorScheme === 'dark' ||
    (colorScheme === 'system' && (systemScheme === 'dark' || !systemScheme));

  const { comments, addComment, currentUser, members } = useExpenseStore();
  const expenseComments = comments[expenseId] || [];

  const [selectedMember, setSelectedMember] = useState<GroupMember | null>(null);
  const [selectedProfile, setSelectedProfile] = useState<UserProfile | null>(null);

  // Group members available for tagging
  const groupMembers = useMemo(() => {
    if (!cohortId) return [];
    return members[cohortId] || [];
  }, [cohortId, members]);

  const [text, setText] = useState('');

  // Detect active @ tag query
  const tagQuery = useMemo(() => {
    const lastAtIndex = text.lastIndexOf('@');
    if (lastAtIndex === -1) return null;
    const query = text.substring(lastAtIndex + 1).toLowerCase();
    // Only suggest if there's no space after the @
    if (query.includes(' ')) return null;
    return { query, index: lastAtIndex };
  }, [text]);

  const showAllChip = useMemo(() => {
    if (!tagQuery) return false;
    return 'all'.includes(tagQuery.query) || 'everyone'.includes(tagQuery.query) || tagQuery.query === '';
  }, [tagQuery]);

  const matchingMembers = useMemo(() => {
    if (!tagQuery) return [];
    return groupMembers.filter((m) => {
      const username = m.profile?.username?.toLowerCase() || '';
      const nickname = m.profile?.nickname?.toLowerCase() || '';
      const fullName = m.profile?.fullName?.toLowerCase() || '';
      return (
        username.includes(tagQuery.query) ||
        nickname.includes(tagQuery.query) ||
        fullName.includes(tagQuery.query)
      );
    });
  }, [tagQuery, groupMembers]);

  const handleSelectAll = () => {
    if (!tagQuery) return;
    const beforeAt = text.substring(0, tagQuery.index);
    setText(`${beforeAt}@all `);
  };

  const handleSelectMention = (member: GroupMember) => {
    if (!tagQuery) return;
    const handle = member.profile?.username || member.profile?.nickname?.toLowerCase().replace(/\s+/g, '_') || 'user';
    const beforeAt = text.substring(0, tagQuery.index);
    setText(`${beforeAt}@${handle} `);
  };

  const handleOpenMemberProfile = (usernameOrId: string) => {
    const cleanTag = usernameOrId.replace(/^@/, '').toLowerCase();
    if (cleanTag === 'all' || cleanTag === 'everyone') return;

    // Search in current group members
    const foundMember = groupMembers.find(
      (m) =>
        m.profile?.username?.toLowerCase() === cleanTag ||
        m.userId === cleanTag ||
        m.profile?.nickname?.toLowerCase() === cleanTag
    );

    if (foundMember) {
      setSelectedMember(foundMember);
      setSelectedProfile(foundMember.profile || null);
      return;
    }

    // Fallback: check if it's current user
    if (
      currentUser.username?.toLowerCase() === cleanTag ||
      currentUser.id === cleanTag ||
      currentUser.nickname?.toLowerCase() === cleanTag
    ) {
      setSelectedMember(null);
      setSelectedProfile(currentUser);
    }
  };

  const handleSend = () => {
    if (!text.trim()) return;

    const newComment: TransactionComment = {
      id: `cmt_${Date.now()}`,
      expenseId,
      userId: currentUser.id,
      content: text.trim(),
      createdAt: new Date().toISOString(),
      profile: currentUser,
    };

    addComment(newComment);
    setText('');
  };

  // Helper to parse text and highlight @mentions & make them clickable
  const renderFormattedContent = (content: string) => {
    const parts = content.split(/(@[a-zA-Z0-9_]+)/g);
    return (
      <Text className="text-xs leading-relaxed" style={{ color: colors.textMain }}>
        {parts.map((part, i) => {
          if (part.toLowerCase() === '@all' || part.toLowerCase() === '@everyone') {
            return (
              <Text
                key={i}
                className="font-extrabold px-1"
                style={{ color: colors.cyan }}
              >
                {part}
              </Text>
            );
          }

          if (part.startsWith('@')) {
            return (
              <Text
                key={i}
                className="font-bold"
                style={{ color: colors.cyan, textDecorationLine: 'underline' }}
                onPress={() => handleOpenMemberProfile(part)}
              >
                {part}
              </Text>
            );
          }
          return part;
        })}
      </Text>
    );
  };

  return (
    <View className="gap-3">
      <Text className="section-label">Discussion & Notes</Text>

      {expenseComments.length === 0 ? (
        <Text className="text-xs italic py-2" style={{ color: colors.textSecondary }}>
          No comments yet. Start a discussion or tag friends with @username or @all.
        </Text>
      ) : (
        <View className="gap-2.5 my-1">
          {expenseComments.map((item) => {
            const authorName = item.profile?.nickname || item.profile?.fullName || 'User';
            const authorHandle = item.profile?.username;
            const hasVpa = !!item.profile?.vpaId;

            return (
              <View key={item.id} className="flex-row gap-2.5 items-start">
                <TouchableOpacity
                  activeOpacity={0.8}
                  onPress={() => {
                    if (item.profile) {
                      setSelectedMember(null);
                      setSelectedProfile(item.profile);
                    }
                  }}
                  className="w-8 h-8 rounded-full items-center justify-center overflow-hidden"
                  style={{
                    backgroundColor: isDark ? colors.accentPill : '#F1F5F9',
                    borderWidth: 1,
                    borderColor: colors.border,
                  }}
                >
                  {item.profile?.avatarUrl ? (
                    <Image source={{ uri: item.profile.avatarUrl }} className="w-8 h-8 rounded-full" />
                  ) : (
                    <Text className="font-bold text-xs" style={{ color: colors.textMain }}>
                      {authorName.charAt(0).toUpperCase()}
                    </Text>
                  )}
                </TouchableOpacity>

                <View
                  className="flex-1 p-3 rounded-2xl gap-1 shadow-sm"
                  style={{
                    backgroundColor: colors.surface,
                    borderWidth: 1,
                    borderColor: colors.border,
                  }}
                >
                  <TouchableOpacity
                    activeOpacity={0.8}
                    onPress={() => {
                      if (item.profile) {
                        setSelectedMember(null);
                        setSelectedProfile(item.profile);
                      }
                    }}
                    className="flex-row items-center gap-1.5 flex-wrap"
                  >
                    <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                      {authorName}
                    </Text>
                    {authorHandle && (
                      <Text className="text-[11px] font-semibold" style={{ color: colors.cyan }}>
                        @{authorHandle}
                      </Text>
                    )}
                    {hasVpa && (
                      <Ionicons name="checkmark-circle" size={13} color={colors.cyan} />
                    )}
                  </TouchableOpacity>
                  {renderFormattedContent(item.content)}
                </View>
              </View>
            );
          })}
        </View>
      )}

      {/* Mention Auto-Complete Bar */}
      {tagQuery && (showAllChip || matchingMembers.length > 0) && (
        <View
          className="p-2 rounded-2xl gap-1.5"
          style={{ backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border }}
        >
          <Text className="text-[10px] font-bold uppercase tracking-wider px-2" style={{ color: colors.textSecondary }}>
            MENTION
          </Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerClassName="gap-2 p-1">
            {/* @all Broadcast Chip */}
            {showAllChip && (
              <TouchableOpacity
                className="px-3 py-1.5 rounded-xl flex-row items-center gap-1.5 shadow-sm"
                style={{ backgroundColor: colors.accentPill, borderWidth: 1.5, borderColor: colors.cyan }}
                onPress={handleSelectAll}
                activeOpacity={0.7}
              >
                <Ionicons name="megaphone-outline" size={14} color={colors.cyan} />
                <Text className="text-xs font-extrabold" style={{ color: colors.cyan }}>
                  @all
                </Text>
                <Text className="text-[10px]" style={{ color: colors.textSecondary }}>
                  (Notify everyone in group)
                </Text>
              </TouchableOpacity>
            )}

            {/* Member Suggestions */}
            {matchingMembers.map((m) => {
              const name = m.profile?.nickname || m.profile?.fullName || 'Member';
              const handle = m.profile?.username || name.toLowerCase().replace(/\s+/g, '_');
              return (
                <TouchableOpacity
                  key={m.userId}
                  className="px-3 py-1.5 rounded-xl flex-row items-center gap-1.5 shadow-sm"
                  style={{ backgroundColor: colors.accentPill, borderWidth: 1, borderColor: colors.border }}
                  onPress={() => handleSelectMention(m)}
                  activeOpacity={0.7}
                >
                  <Text className="text-xs font-bold" style={{ color: colors.textMain }}>
                    {name}
                  </Text>
                  <Text className="text-[11px] font-semibold" style={{ color: colors.cyan }}>
                    @{handle}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </ScrollView>
        </View>
      )}

      {/* Input row */}
      <View className="flex-row gap-2 mt-1">
        <TextInput
          className="flex-1 h-12 rounded-2xl px-4 text-xs font-semibold shadow-sm"
          style={{
            backgroundColor: colors.surface,
            borderWidth: 1,
            borderColor: colors.border,
            color: colors.textMain,
          }}
          placeholder="Add a comment or tag with @username or @all..."
          placeholderTextColor={colors.textSecondary}
          value={text}
          onChangeText={setText}
        />
        <TouchableOpacity
          className="px-4 h-12 rounded-2xl items-center justify-center shadow-sm"
          style={{ backgroundColor: colors.cyan }}
          onPress={handleSend}
          activeOpacity={0.85}
        >
          <Text className="font-extrabold text-xs" style={{ color: '#0F172A' }}>
            Send
          </Text>
        </TouchableOpacity>
      </View>

      {/* Member Profile Modal */}
      <MemberProfileModal
        visible={!!selectedMember || !!selectedProfile}
        onClose={() => {
          setSelectedMember(null);
          setSelectedProfile(null);
        }}
        member={selectedMember}
        profile={selectedProfile}
      />
    </View>
  );
}
