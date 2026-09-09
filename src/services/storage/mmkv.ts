import { StateStorage } from 'zustand/middleware';

let mmkvStorageInstance: any = null;

try {
  const { MMKV } = require('react-native-mmkv');
  mmkvStorageInstance = new MMKV({ id: 'fairshare-local-storage' });
} catch (e) {
  // Expo Go or web environment where native MMKV C++ binding is not present
  console.log('MMKV not available in current environment (e.g. Expo Go). Falling back to in-memory storage.');
}

const memoryStorage = new Map<string, string>();

export const zustandMMKVStorage: StateStorage = {
  setItem: (name: string, value: string) => {
    try {
      if (mmkvStorageInstance) {
        mmkvStorageInstance.set(name, value);
        return;
      }
    } catch (e) {}
    memoryStorage.set(name, value);
  },
  getItem: (name: string) => {
    try {
      if (mmkvStorageInstance) {
        return mmkvStorageInstance.getString(name) ?? null;
      }
    } catch (e) {}
    return memoryStorage.get(name) ?? null;
  },
  removeItem: (name: string) => {
    try {
      if (mmkvStorageInstance) {
        mmkvStorageInstance.delete(name);
        return;
      }
    } catch (e) {}
    memoryStorage.delete(name);
  },
};

export const supabaseMMKVStorage = {
  getItem: (key: string): string | null => zustandMMKVStorage.getItem(key) as string | null,
  setItem: (key: string, value: string): void => {
    zustandMMKVStorage.setItem(key, value);
  },
  removeItem: (key: string): void => {
    zustandMMKVStorage.removeItem(key);
  },
};
