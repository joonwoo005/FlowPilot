import { useState, useRef, useEffect, useId } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  NativeSyntheticEvent,
  TextInputKeyPressEventData,
  AccessibilityInfo,
  InputAccessoryView,
  Keyboard,
} from "react-native";

// ============================================================================
// TypeScript Interfaces
// ============================================================================

export interface TimeValue {
  hour: number; // 1-12
  minute: number; // 0-59
  isPM: boolean;
}

export interface TimePickerProps {
  /** Current time value */
  value?: TimeValue;
  /** Callback when time changes */
  onChange?: (time: TimeValue) => void;
  /** Label displayed above the picker */
  label?: string;
  /** Error message displayed below the picker */
  errorMessage?: string;
  /** Whether the picker is disabled */
  isDisabled?: boolean;
  /** Accessibility label for screen readers */
  accessibilityLabel?: string;
}

// ============================================================================
// Constants
// ============================================================================

const DEFAULT_TIME: TimeValue = {
  hour: 9,
  minute: 0,
  isPM: false,
};

// ============================================================================
// Helper Functions
// ============================================================================

const formatTimeDisplay = (hour: number, minute: number): string => {
  return `${hour.toString().padStart(2, "0")}:${minute.toString().padStart(2, "0")}`;
};

const convert24to12 = (hour24: number): { hour12: number; isPM: boolean } => {
  if (hour24 === 0) {
    return { hour12: 12, isPM: false }; // 00:xx = 12:xx AM
  } else if (hour24 < 12) {
    return { hour12: hour24, isPM: false }; // 01-11 = AM
  } else if (hour24 === 12) {
    return { hour12: 12, isPM: true }; // 12:xx = 12:xx PM
  } else {
    return { hour12: hour24 - 12, isPM: true }; // 13-23 = 1-11 PM
  }
};

interface ParseResult {
  hour: number;
  minute: number;
  isPM?: boolean;
}

interface ValidationResult {
  parsed: ParseResult | null;
  error: string | null;
}

const validateTimeInput = (text: string): ValidationResult => {
  if (!text || text.trim() === "") {
    return { parsed: null, error: null };
  }

  // Remove any non-digit and non-colon characters
  const cleaned = text.replace(/[^0-9:]/g, "");

  // Try to parse HH:MM format
  const colonMatch = cleaned.match(/^(\d{1,2}):(\d{0,2})$/);
  if (colonMatch) {
    const hourInput = parseInt(colonMatch[1], 10);
    const minuteStr = colonMatch[2];
    const minute = minuteStr ? parseInt(minuteStr, 10) : 0;

    // Special case: 24:00 is valid (equals 00:00 / 12:00 AM)
    if (hourInput === 24) {
      if (minuteStr && minute > 0) {
        return { parsed: null, error: "24:00 is valid, but not 24:01+" };
      }
      return {
        parsed: { hour: 12, minute: 0, isPM: false },
        error: null,
      };
    }

    // Validate hour
    if (hourInput > 24) {
      return { parsed: null, error: "Hour must be 0-24" };
    }

    // Validate minute (only if user has entered minute digits)
    if (minuteStr && minute > 59) {
      return { parsed: null, error: "Minutes must be 0-59" };
    }

    // Valid - convert to 12-hour format
    const { hour12, isPM } = convert24to12(hourInput);
    return {
      parsed: { hour: hour12, minute, isPM },
      error: null,
    };
  }

  // Try to parse digits only (while typing)
  const digitsOnly = cleaned.replace(/:/g, "");
  if (/^\d{1,2}$/.test(digitsOnly)) {
    const hourInput = parseInt(digitsOnly, 10);
    // Allow 24 while typing (will validate minutes later)
    if (hourInput > 24) {
      return { parsed: null, error: "Hour must be 0-24" };
    }
    // For 24, default to 12:00 AM
    if (hourInput === 24) {
      return {
        parsed: { hour: 12, minute: 0, isPM: false },
        error: null,
      };
    }
    const { hour12, isPM } = convert24to12(hourInput);
    return {
      parsed: { hour: hour12, minute: 0, isPM },
      error: null,
    };
  }

  // Try to parse HHMM format (3-4 digits)
  if (/^\d{3,4}$/.test(digitsOnly)) {
    const hourInput = parseInt(digitsOnly.slice(0, 2), 10);
    const minute = parseInt(digitsOnly.slice(2), 10);

    // Special case: 24:00 is valid
    if (hourInput === 24) {
      if (minute > 0) {
        return { parsed: null, error: "24:00 is valid, but not 24:01+" };
      }
      return {
        parsed: { hour: 12, minute: 0, isPM: false },
        error: null,
      };
    }

    if (hourInput > 24) {
      return { parsed: null, error: "Hour must be 0-24" };
    }
    if (minute > 59) {
      return { parsed: null, error: "Minutes must be 0-59" };
    }

    const { hour12, isPM } = convert24to12(hourInput);
    return {
      parsed: { hour: hour12, minute, isPM },
      error: null,
    };
  }

  return { parsed: null, error: "Invalid time format" };
};

const formatInputAsUserTypes = (text: string, previousText: string): string => {
  // Only keep digits
  const digits = text.replace(/[^0-9]/g, "");

  if (digits.length === 0) return "";
  if (digits.length === 1) return digits;
  if (digits.length === 2) {
    // If first two digits form valid hour, add colon
    const potentialHour = parseInt(digits, 10);
    if (potentialHour >= 1 && potentialHour <= 12) {
      // Only auto-add colon if user is adding characters, not deleting
      if (text.length > previousText.length) {
        return `${digits}:`;
      }
    }
    return digits;
  }
  if (digits.length === 3) {
    return `${digits.slice(0, 2)}:${digits.slice(2)}`;
  }
  if (digits.length >= 4) {
    return `${digits.slice(0, 2)}:${digits.slice(2, 4)}`;
  }

  return text;
};

// ============================================================================
// TimePicker Component
// ============================================================================

export function TimePicker({
  value,
  onChange,
  label,
  errorMessage,
  isDisabled = false,
  accessibilityLabel,
}: TimePickerProps) {
  const currentTime = value ?? DEFAULT_TIME;
  const accessoryId = useId();

  const [inputText, setInputText] = useState(
    formatTimeDisplay(currentTime.hour, currentTime.minute)
  );
  const [isFocused, setIsFocused] = useState(false);
  const [realtimeError, setRealtimeError] = useState<string | null>(null);

  const inputRef = useRef<TextInput>(null);
  const previousTextRef = useRef(inputText);

  // Sync with external value changes
  useEffect(() => {
    if (!isFocused) {
      setInputText(formatTimeDisplay(currentTime.hour, currentTime.minute));
    }
  }, [currentTime.hour, currentTime.minute, isFocused]);

  const emitChange = (newTime: Partial<TimeValue>) => {
    if (onChange && !isDisabled) {
      onChange({
        hour: newTime.hour ?? currentTime.hour,
        minute: newTime.minute ?? currentTime.minute,
        isPM: newTime.isPM ?? currentTime.isPM,
      });
    }
  };

  const handleTextChange = (text: string) => {
    const formatted = formatInputAsUserTypes(text, previousTextRef.current);
    previousTextRef.current = formatted;
    setInputText(formatted);

    // Real-time validation
    const { parsed, error } = validateTimeInput(formatted);
    setRealtimeError(error);

    // Emit change if valid
    if (parsed) {
      emitChange({
        hour: parsed.hour,
        minute: parsed.minute,
        ...(parsed.isPM !== undefined && { isPM: parsed.isPM }),
      });
    }
  };

  const handleFocus = () => {
    setIsFocused(true);
    // Select all text on focus for easy replacement
    inputRef.current?.setSelection(0, inputText.length);
  };

  const handleBlur = () => {
    setIsFocused(false);

    // Validate and format on blur
    const { parsed, error } = validateTimeInput(inputText);
    if (parsed) {
      setInputText(formatTimeDisplay(parsed.hour, parsed.minute));
      emitChange({
        hour: parsed.hour,
        minute: parsed.minute,
        ...(parsed.isPM !== undefined && { isPM: parsed.isPM }),
      });
      setRealtimeError(null);
    } else if (inputText.trim() !== "") {
      // Invalid input - reset to last valid value
      setInputText(formatTimeDisplay(currentTime.hour, currentTime.minute));
      setRealtimeError(null);
    }
  };

  const handleKeyPress = (e: NativeSyntheticEvent<TextInputKeyPressEventData>) => {
    const key = e.nativeEvent.key;

    if (key === "ArrowUp") {
      // Increment minute
      const newMinute = currentTime.minute >= 59 ? 0 : currentTime.minute + 1;
      const newHour = currentTime.minute >= 59
        ? (currentTime.hour >= 12 ? 1 : currentTime.hour + 1)
        : currentTime.hour;
      setInputText(formatTimeDisplay(newHour, newMinute));
      emitChange({ hour: newHour, minute: newMinute });
    } else if (key === "ArrowDown") {
      // Decrement minute
      const newMinute = currentTime.minute <= 0 ? 59 : currentTime.minute - 1;
      const newHour = currentTime.minute <= 0
        ? (currentTime.hour <= 1 ? 12 : currentTime.hour - 1)
        : currentTime.hour;
      setInputText(formatTimeDisplay(newHour, newMinute));
      emitChange({ hour: newHour, minute: newMinute });
    }
  };

  const handleAmPmToggle = () => {
    if (!isDisabled) {
      const newIsPM = !currentTime.isPM;
      emitChange({ isPM: newIsPM });
      AccessibilityInfo.announceForAccessibility(newIsPM ? "Changed to PM" : "Changed to AM");
    }
  };

  const displayError = errorMessage || realtimeError;

  return (
    <View style={styles.container}>
      {label && (
        <Text style={[styles.label, isDisabled && styles.labelDisabled]}>
          {label}
        </Text>
      )}

      <View
        style={[
          styles.inputRow,
          isFocused && styles.inputRowFocused,
          displayError && styles.inputRowError,
          isDisabled && styles.inputRowDisabled,
        ]}
        accessibilityLabel={accessibilityLabel ?? `Time: ${inputText} ${currentTime.isPM ? "PM" : "AM"}`}
        accessibilityRole="adjustable"
      >
        <TextInput
          ref={inputRef}
          style={[styles.timeInput, isDisabled && styles.timeInputDisabled]}
          value={inputText}
          onChangeText={handleTextChange}
          onFocus={handleFocus}
          onBlur={handleBlur}
          onKeyPress={handleKeyPress}
          keyboardType="numeric"
          maxLength={5}
          editable={!isDisabled}
          placeholder="09:00"
          placeholderTextColor="#9ca3af"
          accessibilityLabel="Time in hours and minutes"
          accessibilityHint="Enter time in HH:MM format (0-24 hours). Converts to 12-hour format automatically."
          inputAccessoryViewID={accessoryId}
        />

        <TouchableOpacity
          style={[
            styles.ampmButton,
            isDisabled && styles.ampmButtonDisabled,
          ]}
          onPress={handleAmPmToggle}
          disabled={isDisabled}
          accessibilityLabel={`${currentTime.isPM ? "PM" : "AM"}, tap to toggle`}
          accessibilityRole="button"
        >
          <Text style={[styles.ampmText, isDisabled && styles.ampmTextDisabled]}>
            {currentTime.isPM ? "PM" : "AM"}
          </Text>
        </TouchableOpacity>
      </View>

      {displayError && (
        <Text style={styles.errorMessage} accessibilityRole="alert">
          {displayError}
        </Text>
      )}

      <InputAccessoryView nativeID={accessoryId}>
        <View style={styles.accessoryView}>
          <TouchableOpacity
            onPress={() => Keyboard.dismiss()}
            style={styles.doneButton}
            accessibilityLabel="Done"
            accessibilityRole="button"
          >
            <Text style={styles.doneButtonText}>Done</Text>
          </TouchableOpacity>
        </View>
      </InputAccessoryView>
    </View>
  );
}

// ============================================================================
// Styles
// ============================================================================

const styles = StyleSheet.create({
  container: {
    width: "100%",
  },
  label: {
    fontSize: 14,
    fontWeight: "500",
    color: "#374151",
    marginBottom: 8,
  },
  labelDisabled: {
    color: "#9ca3af",
  },
  inputRow: {
    flexDirection: "row",
    alignItems: "center",
    backgroundColor: "#fff",
    borderWidth: 1,
    borderColor: "#d1d5db",
    borderRadius: 12,
    paddingHorizontal: 4,
    paddingVertical: 4,
  },
  inputRowFocused: {
    borderColor: "#2563eb",
    borderWidth: 2,
  },
  inputRowError: {
    borderColor: "#ef4444",
  },
  inputRowDisabled: {
    backgroundColor: "#f3f4f6",
    borderColor: "#e5e7eb",
  },
  timeInput: {
    flex: 1,
    fontSize: 20,
    fontWeight: "500",
    color: "#111827",
    paddingVertical: 12,
    paddingHorizontal: 12,
    letterSpacing: 2,
  },
  timeInputDisabled: {
    color: "#9ca3af",
  },
  ampmButton: {
    backgroundColor: "#f3f4f6",
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 8,
    marginRight: 4,
  },
  ampmButtonDisabled: {
    backgroundColor: "#e5e7eb",
  },
  ampmText: {
    fontSize: 16,
    fontWeight: "600",
    color: "#2563eb",
  },
  ampmTextDisabled: {
    color: "#9ca3af",
  },
  errorMessage: {
    fontSize: 12,
    color: "#ef4444",
    marginTop: 4,
  },
  accessoryView: {
    backgroundColor: "#f3f4f6",
    paddingVertical: 8,
    paddingHorizontal: 16,
    flexDirection: "row",
    justifyContent: "flex-end",
    borderTopWidth: 1,
    borderTopColor: "#e5e7eb",
  },
  doneButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
  },
  doneButtonText: {
    color: "#2563eb",
    fontSize: 16,
    fontWeight: "600",
  },
});

// ============================================================================
// Utility Functions
// ============================================================================

export function timeValueTo24Hour(time: TimeValue): string {
  let hour24 = time.hour;
  if (time.isPM && time.hour !== 12) {
    hour24 = time.hour + 12;
  } else if (!time.isPM && time.hour === 12) {
    hour24 = 0;
  }
  return `${hour24.toString().padStart(2, "0")}:${time.minute.toString().padStart(2, "0")}`;
}

export function timeValueFrom24Hour(time24: string): TimeValue {
  const [hours, minutes] = time24.split(":").map(Number);
  let hour12 = hours % 12;
  if (hour12 === 0) hour12 = 12;
  return {
    hour: hour12,
    minute: minutes,
    isPM: hours >= 12,
  };
}

export function formatTimeValue(time: TimeValue): string {
  const hour = time.hour.toString().padStart(2, "0");
  const minute = time.minute.toString().padStart(2, "0");
  return `${hour}:${minute} ${time.isPM ? "PM" : "AM"}`;
}

export default TimePicker;
