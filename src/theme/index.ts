// PlannerApp Theme - Dark theme matching FlowPilot macOS

export const colors = {
  // Background gradients
  background: {
    start: "rgb(25, 25, 38)",
    end: "rgb(38, 30, 51)",
  },

  // Surface colors (cards, containers)
  surface: {
    primary: "rgba(255, 255, 255, 0.03)",
    secondary: "rgba(255, 255, 255, 0.05)",
    elevated: "rgba(255, 255, 255, 0.08)",
    border: "rgba(255, 255, 255, 0.1)",
  },

  // Primary gradient colors
  primary: {
    blue: "#3B82F6",
    purple: "#8B5CF6",
  },

  // Text colors
  text: {
    primary: "#FFFFFF",
    secondary: "rgba(255, 255, 255, 0.7)",
    tertiary: "rgba(255, 255, 255, 0.5)",
    muted: "rgba(255, 255, 255, 0.3)",
  },

  // Status colors
  status: {
    success: "#22C55E",
    warning: "#F59E0B",
    error: "#EF4444",
    info: "#3B82F6",
  },

  // Activity action colors
  activity: {
    created: "#22C55E",
    completed: "#3B82F6",
    uncompleted: "#F59E0B",
    deleted: "#EF4444",
  },

  // Tab bar
  tabBar: {
    background: "rgba(25, 25, 38, 0.95)",
    active: "#FFFFFF",
    inactive: "rgba(255, 255, 255, 0.4)",
  },
};

export const typography = {
  fontSize: {
    xs: 11,
    sm: 13,
    base: 15,
    md: 17,
    lg: 20,
    xl: 24,
    "2xl": 30,
    "3xl": 36,
  },
  fontWeight: {
    regular: "400" as const,
    medium: "500" as const,
    semibold: "600" as const,
    bold: "700" as const,
  },
};

export const spacing = {
  xs: 4,
  sm: 8,
  md: 12,
  base: 16,
  lg: 20,
  xl: 24,
  "2xl": 32,
  "3xl": 40,
};

export const borderRadius = {
  sm: 6,
  md: 8,
  lg: 12,
  xl: 16,
  "2xl": 20,
  full: 9999,
};

export const shadows = {
  sm: {
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.2,
    shadowRadius: 2,
    elevation: 2,
  },
  md: {
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 4,
    elevation: 4,
  },
  lg: {
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
};
