import { Platform } from 'react-native';
import * as Notifications from 'expo-notifications';
import { PersonalReminderSettings } from '@/types';

// Configure foreground notification behavior
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
    shouldShowBanner: true,
    shouldShowList: true,
  }),
});

const CHANNEL_ID = 'house-cart-reminders';

/**
 * Ensures high-priority Android notification channel is registered.
 */
export async function setupNotificationChannels(): Promise<void> {
  if (Platform.OS === 'android') {
    try {
      await Notifications.setNotificationChannelAsync(CHANNEL_ID, {
        name: 'House Cart Reminders',
        description: 'Scheduled reminders for shared house cart and grocery shopping items',
        importance: Notifications.AndroidImportance.HIGH,
        vibrationPattern: [0, 250, 250, 250],
        lightColor: '#00E599',
      });
    } catch (err) {
      console.warn('[NotificationService] setupNotificationChannels error:', err);
    }
  }
}

/**
 * Requests native system notification permissions (including Android 13+ POST_NOTIFICATIONS).
 */
export async function requestNotificationPermissions(): Promise<boolean> {
  try {
    const { status: existingStatus } = await Notifications.getPermissionsAsync();
    let finalStatus = existingStatus;

    if (existingStatus !== 'granted') {
      const { status } = await Notifications.requestPermissionsAsync();
      finalStatus = status;
    }

    return finalStatus === 'granted';
  } catch (err) {
    console.warn('[NotificationService] requestNotificationPermissions error:', err);
    return false;
  }
}

/**
 * Deterministic notification ID per cohort.
 */
function getReminderIdentifier(cohortId: string): string {
  return `needs_reminder_${cohortId}`;
}

/**
 * Schedules a local recurring shopping list reminder for a cohort.
 */
export async function scheduleNeedsListReminder(
  cohortId: string,
  cohortName: string,
  pendingItemsCount: number,
  settings: PersonalReminderSettings
): Promise<string | null> {
  try {
    // Cancel any previous reminder for this cohort first
    await cancelNeedsListReminder(cohortId);

    if (!settings.enabled || pendingItemsCount <= 0) {
      return null;
    }

    const hasPermission = await requestNotificationPermissions();
    if (!hasPermission) {
      console.warn('[NotificationService] Permissions not granted, skipping schedule.');
      return null;
    }

    await setupNotificationChannels();

    const identifier = getReminderIdentifier(cohortId);
    const title = `${cohortName} Cart Reminder`;
    const body =
      pendingItemsCount === 1
        ? 'There is 1 item waiting in your house shopping cart.'
        : `There are ${pendingItemsCount} items waiting in your house shopping cart.`;

    let trigger: Notifications.NotificationTriggerInput;

    if (settings.frequencyUnit === 'hours') {
      const hours = Math.max(1, settings.frequencyHours || 6);
      trigger = {
        type: Notifications.SchedulableTriggerInputTypes.TIME_INTERVAL,
        seconds: hours * 3600,
        repeats: true,
        channelId: CHANNEL_ID,
      };
    } else {
      const [hhStr, mmStr] = (settings.reminderTime || '18:00').split(':');
      const hour = parseInt(hhStr, 10) || 18;
      const minute = parseInt(mmStr, 10) || 0;
      trigger = {
        type: Notifications.SchedulableTriggerInputTypes.DAILY,
        hour,
        minute,
        channelId: CHANNEL_ID,
      };
    }

    const scheduledId = await Notifications.scheduleNotificationAsync({
      identifier,
      content: {
        title,
        body,
        data: { cohortId, type: 'needs_cart_reminder' },
        sound: true,
      },
      trigger,
    });

    return scheduledId;
  } catch (err) {
    console.warn('[NotificationService] scheduleNeedsListReminder error:', err);
    return null;
  }
}

/**
 * Cancels a cohort's scheduled reminder.
 */
export async function cancelNeedsListReminder(cohortId: string): Promise<void> {
  try {
    const identifier = getReminderIdentifier(cohortId);
    await Notifications.cancelScheduledNotificationAsync(identifier);
  } catch (err) {
    console.warn('[NotificationService] cancelNeedsListReminder error:', err);
  }
}
