import React, { useState } from 'react';
import {
  StyleSheet,
  View,
  Text,
  TextInput,
  TouchableOpacity,
  FlatList,
} from 'react-native';
import { useTheme } from '@/hooks/use-theme';
import { useExpenseStore } from '@/store/useExpenseStore';
import { TransactionComment } from '@/types';

interface TransactionCommentsProps {
  expenseId: string;
}

export function TransactionComments({ expenseId }: TransactionCommentsProps) {
  const theme = useTheme();
  const { comments, addComment, currentUser } = useExpenseStore();
  const expenseComments = comments[expenseId] || [];

  const [text, setText] = useState('');

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

  return (
    <View style={[styles.container, { backgroundColor: theme.backgroundElement }]}>
      <Text style={[styles.title, { color: theme.text }]}>Discussion & Notes</Text>

      {expenseComments.length === 0 ? (
        <Text style={[styles.emptyText, { color: theme.textSecondary }]}>
          No comments yet. Start a discussion or add a note about this expense.
        </Text>
      ) : (
        <View style={styles.list}>
          {expenseComments.map((item) => (
            <View key={item.id} style={styles.commentRow}>
              <View style={styles.avatar}>
                <Text style={styles.avatarText}>
                  {item.profile?.fullName?.[0]?.toUpperCase() || 'U'}
                </Text>
              </View>
              <View style={styles.bubble}>
                <Text style={[styles.author, { color: theme.text }]}>
                  {item.profile?.fullName || 'User'}
                </Text>
                <Text style={[styles.body, { color: theme.text }]}>{item.content}</Text>
              </View>
            </View>
          ))}
        </View>
      )}

      {/* Input row */}
      <View style={styles.inputRow}>
        <TextInput
          style={[
            styles.input,
            {
              backgroundColor: theme.backgroundSelected,
              color: theme.text,
            },
          ]}
          placeholder="Add a comment or note..."
          placeholderTextColor={theme.textSecondary}
          value={text}
          onChangeText={setText}
        />
        <TouchableOpacity style={styles.sendButton} onPress={handleSend}>
          <Text style={styles.sendText}>Send</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    borderRadius: 12,
    padding: 14,
    gap: 12,
    marginTop: 12,
  },
  title: {
    fontSize: 15,
    fontWeight: '700',
  },
  emptyText: {
    fontSize: 13,
    fontStyle: 'italic',
  },
  list: {
    gap: 10,
  },
  commentRow: {
    flexDirection: 'row',
    gap: 10,
    alignItems: 'flex-start',
  },
  avatar: {
    width: 28,
    height: 28,
    borderRadius: 14,
    backgroundColor: '#6366F1',
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    color: '#FFF',
    fontWeight: '700',
    fontSize: 11,
  },
  bubble: {
    flex: 1,
    gap: 2,
  },
  author: {
    fontSize: 12,
    fontWeight: '700',
  },
  body: {
    fontSize: 14,
  },
  inputRow: {
    flexDirection: 'row',
    gap: 8,
    marginTop: 4,
  },
  input: {
    flex: 1,
    height: 38,
    borderRadius: 19,
    paddingHorizontal: 14,
    fontSize: 13,
  },
  sendButton: {
    backgroundColor: '#6366F1',
    paddingHorizontal: 16,
    borderRadius: 19,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sendText: {
    color: '#FFF',
    fontWeight: '700',
    fontSize: 13,
  },
});
