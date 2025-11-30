/** @type {import('@bacons/apple-targets').Config} */
module.exports = {
  type: "widget",
  name: "WeekFillWidget",
  icon: "../../assets/icon.png",
  colors: {
    $accent: "#2563eb",
    $widgetBackground: "#ffffff",
  },
  entitlements: {
    "com.apple.security.application-groups": ["group.com.junyutoh.weekfill"],
  },
};
