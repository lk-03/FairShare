import { Text } from "@/components/ui/Text";
import { useExpenseStore } from "@/store/useExpenseStore";
import {
  getActiveThemeClass,
  getThemePalette,
  useThemeStore,
} from "@/store/useThemeStore";
import { showAlert } from "@/store/useAlertStore";
import { Ionicons } from "@expo/vector-icons";
import * as Clipboard from "expo-clipboard";
import { useEffect, useState } from "react";
import {
  Modal,
  ScrollView,
  StatusBar,
  TextInput,
  TouchableOpacity,
  useColorScheme,
  View,
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

interface SetUpiModalProps {
  visible: boolean;
  onClose: () => void;
}

// Validation Regex for Indian VPAs (e.g. name@okhdfcbank, 9876543210@paytm)
const UPI_REGEX = /^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$/;

// Quick Handles Pill Presets
const POPULAR_HANDLES = [
  "@okaxis",
  "@okhdfcbank",
  "@oksbi",
  "@okicici",
  "@paytm",
  "@ybl",
  "@ibl",
  "@apl",
];

export function SetUpiModal({ visible, onClose }: SetUpiModalProps) {
  const systemScheme = useColorScheme();
  const { themeBase, colorScheme } = useThemeStore();
  const activeThemeClass = getActiveThemeClass(
    themeBase,
    colorScheme,
    systemScheme,
  );
  const colors = getThemePalette(themeBase, colorScheme, systemScheme);

  const isDark =
    colorScheme === "dark" ||
    (colorScheme === "system" && (systemScheme === "dark" || !systemScheme));

  const { currentUser, updateCurrentUserVpa } = useExpenseStore();
  const [vpaInput, setVpaInput] = useState(currentUser.vpaId || "");
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    if (visible) {
      setVpaInput(currentUser.vpaId || "");
    }
  }, [visible, currentUser.vpaId]);

  const sanitizedVpa = vpaInput.trim().toLowerCase();
  const isValidVpa = UPI_REGEX.test(sanitizedVpa);

  const handleAppendHandle = (handle: string) => {
    const prefix = sanitizedVpa.includes("@")
      ? sanitizedVpa.split("@")[0]
      : sanitizedVpa;
    if (prefix) {
      setVpaInput(`${prefix}${handle}`);
    } else {
      setVpaInput(handle);
    }
  };

  const handlePasteFromClipboard = async () => {
    try {
      const text = await Clipboard.getStringAsync();
      if (!text) {
        showAlert("Empty Clipboard", "No text found in your clipboard.");
        return;
      }

      // Sanitize pasted content: extract UPI ID from potential upi:// links or text
      let cleaned = text.trim();
      if (cleaned.includes("pa=")) {
        const match = cleaned.match(/pa=([^&]+)/);
        if (match && match[1]) {
          cleaned = decodeURIComponent(match[1]);
        }
      } else if (cleaned.startsWith("upi://pay?")) {
        cleaned = cleaned.replace("upi://pay?", "");
      }

      // Remove any extra whitespace
      cleaned = cleaned.replace(/\s+/g, "").toLowerCase();

      if (UPI_REGEX.test(cleaned)) {
        setVpaInput(cleaned);
      } else {
        setVpaInput(cleaned);
      }
    } catch (e) {
      console.warn("Clipboard paste error:", e);
    }
  };

  const handleSave = async () => {
    if (!sanitizedVpa) {
      showAlert("Missing UPI ID", "Please enter your UPI Address.");
      return;
    }

    if (!isValidVpa) {
      showAlert(
        "Invalid UPI ID Format",
        "Please enter a valid UPI ID formatted as username@bank (e.g. rahul@okaxis, priya@oksbi).",
      );
      return;
    }

    setIsSaving(true);
    try {
      await updateCurrentUserVpa(sanitizedVpa);
      onClose();
    } catch (err) {
      showAlert("Save Failed", "Could not save UPI ID. Please try again.");
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <Modal
      visible={visible}
      animationType="slide"
      transparent={false}
      onRequestClose={onClose}
    >
      <View
        className={`flex-1 ${activeThemeClass}`}
        style={{ backgroundColor: colors.screen }}
      >
        <SafeAreaView className="flex-1" edges={["top", "bottom"]}>
          <StatusBar barStyle={isDark ? "light-content" : "dark-content"} />

          {/* Top Bar Header */}
          <View
            className="flex-row items-center justify-between px-4 py-3.5"
            style={{
              backgroundColor: colors.surface,
              borderBottomWidth: 1,
              borderBottomColor: colors.border,
            }}
          >
            <TouchableOpacity
              onPress={onClose}
              className="p-2 rounded-xl"
              activeOpacity={0.7}
            >
              <Ionicons
                name="arrow-back"
                size={24}
                color={colors.textSecondary}
              />
            </TouchableOpacity>
            <Text
              className="text-lg font-bold"
              style={{ color: colors.textMain }}
            >
              Set UPI ID
            </Text>
            <TouchableOpacity
              onPress={handleSave}
              className="p-2 rounded-xl"
              disabled={isSaving}
              activeOpacity={0.7}
            >
              <Ionicons
                name="checkmark"
                size={26}
                color={isValidVpa ? colors.cyan : colors.textSecondary}
              />
            </TouchableOpacity>
          </View>

          <ScrollView
            showsVerticalScrollIndicator={false}
            contentContainerClassName="p-6 gap-6"
            keyboardShouldPersistTaps="handled"
            keyboardDismissMode="none"
          >
            {/* Hero Card */}
            <View
              className="p-5 rounded-3xl gap-3"
              style={{
                backgroundColor: colors.surface,
                borderWidth: 1,
                borderColor: colors.border,
              }}
            >
              <View className="flex-row items-center gap-3">
                <View
                  className="w-12 h-12 rounded-2xl items-center justify-center shadow-sm"
                  style={{
                    backgroundColor: colors.accentPill,
                    borderWidth: 1,
                    borderColor: colors.border,
                  }}
                >
                  <Ionicons name="card-outline" size={24} color={colors.cyan} />
                </View>
                <View className="flex-1">
                  <Text
                    className="text-base font-bold"
                    style={{ color: colors.textMain }}
                  >
                    Direct 0-Fee Settlements
                  </Text>
                  <Text
                    className="text-xs"
                    style={{ color: colors.textSecondary }}
                  >
                    Your UPI ID allows friends to settle group debts with 1 tap
                    via GPay, PhonePe, or Paytm.
                  </Text>
                </View>
              </View>
            </View>

            {/* Input Section */}
            <View className="gap-2.5">
              <View className="flex-row items-center justify-between px-1">
                <Text
                  className="text-xs font-bold uppercase tracking-wider"
                  style={{ color: colors.textSecondary }}
                >
                  YOUR UPI ADDRESS
                </Text>

                {/* Paste from Clipboard Button */}
                <TouchableOpacity
                  className="flex-row items-center gap-1.5 px-3 py-1.5 rounded-xl"
                  style={{
                    backgroundColor: colors.accentPill,
                    borderWidth: 1,
                    borderColor: colors.border,
                  }}
                  onPress={handlePasteFromClipboard}
                  activeOpacity={0.7}
                >
                  <Ionicons
                    name="clipboard-outline"
                    size={14}
                    color={colors.cyan}
                  />
                  <Text
                    className="text-xs font-bold"
                    style={{ color: colors.cyan }}
                  >
                    Paste from Clipboard
                  </Text>
                </TouchableOpacity>
              </View>

              <View
                className="flex-row items-center px-4 rounded-2xl gap-3 shadow-sm"
                style={{
                  backgroundColor: colors.surface,
                  borderWidth: 1.5,
                  borderColor: isValidVpa ? colors.cyan : colors.border,
                  minHeight: 56,
                  height: 56,
                }}
              >
                <Ionicons
                  name="at"
                  size={20}
                  color={isValidVpa ? colors.cyan : colors.textSecondary}
                />
                <TextInput
                  className="flex-1 text-base font-bold"
                  style={{
                    color: colors.textMain,
                    textAlignVertical: "center",
                  }}
                  placeholder="e.g. mobile@okhdfcbank, name@upi"
                  placeholderTextColor={colors.textSecondary}
                  autoCapitalize="none"
                  autoCorrect={false}
                  value={vpaInput}
                  onChangeText={setVpaInput}
                  multiline={false}
                  scrollEnabled={false}
                />

                {isValidVpa && (
                  <View
                    className="px-2.5 py-1 rounded-xl flex-row items-center gap-1"
                    style={{ backgroundColor: colors.accentPill }}
                  >
                    <Ionicons
                      name="checkmark-circle"
                      size={16}
                      color={colors.cyan}
                    />
                    <Text
                      className="text-xs font-bold"
                      style={{ color: colors.cyan }}
                    >
                      Valid
                    </Text>
                  </View>
                )}
              </View>
            </View>

            {/* Quick-Tap Bank Handle Chips */}
            <View className="gap-2.5">
              <Text
                className="text-xs font-bold uppercase tracking-wider px-1"
                style={{ color: colors.textSecondary }}
              >
                QUICK BANK HANDLES
              </Text>
              <View className="flex-row flex-wrap gap-2.5">
                {POPULAR_HANDLES.map((handle) => {
                  const atIndex = sanitizedVpa.indexOf("@");
                  const currentHandle = atIndex > -1 ? sanitizedVpa.substring(atIndex) : "";
                  const isSelected = currentHandle === handle;
                  return (
                    <TouchableOpacity
                      key={handle}
                      className="px-4 py-3 rounded-2xl shadow-sm"
                      style={{
                        backgroundColor: isSelected
                          ? colors.cyan
                          : colors.surface,
                        borderWidth: 1,
                        borderColor: isSelected ? colors.cyan : colors.border,
                      }}
                      onPress={() => handleAppendHandle(handle)}
                      activeOpacity={0.7}
                    >
                      <Text
                        className="text-xs font-bold"
                        style={{
                          color: isSelected ? "#0F172A" : colors.textMain,
                        }}
                      >
                        {handle}
                      </Text>
                    </TouchableOpacity>
                  );
                })}
              </View>
            </View>

            {/* Format & Error Prevention Box */}
            <View
              className="p-4 rounded-2xl gap-2"
              style={{
                backgroundColor: colors.surface,
                borderWidth: 1,
                borderColor: colors.border,
              }}
            >
              <View className="flex-row items-center gap-2">
                <Ionicons
                  name="shield-checkmark-outline"
                  size={18}
                  color={colors.cyan}
                />
                <Text
                  className="text-xs font-bold"
                  style={{ color: colors.textMain }}
                >
                  Typo & Error Prevention
                </Text>
              </View>
              <Text
                className="text-xs leading-5"
                style={{ color: colors.textSecondary }}
              >
                Ensure your UPI ID matches the one in your Google Pay, PhonePe,
                or BHIM settings. You can paste directly using the button above
                or tap one of the common bank handles.
              </Text>
            </View>

            {/* Save Button */}
            <TouchableOpacity
              className="py-4 rounded-2xl items-center justify-center shadow-sm mt-2"
              style={{
                backgroundColor: isValidVpa ? colors.cyan : colors.accentPill,
              }}
              onPress={handleSave}
              disabled={isSaving}
              activeOpacity={0.85}
            >
              <Text
                className="text-base font-extrabold"
                style={{ color: isValidVpa ? "#0F172A" : colors.textSecondary }}
              >
                {isSaving ? "Saving..." : "Save UPI ID"}
              </Text>
            </TouchableOpacity>
          </ScrollView>
        </SafeAreaView>
      </View>
    </Modal>
  );
}
