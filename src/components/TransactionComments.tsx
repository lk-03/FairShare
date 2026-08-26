import React, { useState } from 'react';
import {
  View,
  TextInput,
  TouchableOpacity,
} from 'react-native';
import { useExpenseStore } from '@/store/useExpenseStore';
import { TransactionComment } from '@/types';
import { Text } from '@/components/ui/Text';

interface TransactionCommentsProps {
  expenseId: string;
}

export function TransactionComments({ expenseId }: TransactionCommentsProps) {
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
    <View className="gap-3">
      <Text className="section-label">Discussion & Notes</Text>

      {expenseComments.length === 0 ? (
        <Text className="text-xs text-slate-400 italic py-2">
          No comments yet. Start a discussion or add a note about this expense.
        </Text>
      ) : (
        <View className="gap-2.5 my-1">
          {expenseComments.map((item) => (
            <View key={item.id} className="flex-row gap-2.5 items-start">
              <View className="w-7 h-7 rounded-full bg-slate-200 items-center justify-center">
                <Text className="text-slate-700 font-bold text-[10px]">
                  {item.profile?.fullName?.[0]?.toUpperCase() || 'U'}
                </Text>
              </View>
              <View className="flex-1 bg-slate-50 border border-slate-100 p-2.5 rounded-2xl">
                <Text className="text-xs font-bold text-slate-900 mb-0.5">
                  {item.profile?.fullName || 'User'}
                </Text>
                <Text className="text-xs text-slate-700">{item.content}</Text>
              </View>
            </View>
          ))}
        </View>
      )}

      {/* Input row */}
      <View className="flex-row gap-2 mt-1">
        <TextInput
          className="flex-1 h-11 bg-slate-50 border border-slate-200 rounded-2xl px-3.5 text-xs text-slate-900"
          placeholder="Add a comment or note..."
          placeholderTextColor="#94A3B8"
          value={text}
          onChangeText={setText}
        />
        <TouchableOpacity
          className="bg-slate-900 px-4 rounded-2xl items-center justify-center shadow-sm"
          onPress={handleSend}
        >
          <Text className="text-white font-bold text-xs">Send</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}
