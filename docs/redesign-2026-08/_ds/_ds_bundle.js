/* @ds-bundle: {"format":3,"namespace":"JeebDesignSystem_f5873d","components":[{"name":"Avatar","sourcePath":"components/core/Avatar.jsx"},{"name":"Badge","sourcePath":"components/core/Badge.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Card","sourcePath":"components/core/Card.jsx"},{"name":"IconButton","sourcePath":"components/core/IconButton.jsx"},{"name":"RatingStars","sourcePath":"components/core/RatingStars.jsx"},{"name":"ChatInput","sourcePath":"components/forms/ChatInput.jsx"},{"name":"Input","sourcePath":"components/forms/Input.jsx"},{"name":"MessageBubble","sourcePath":"components/jeeb/MessageBubble.jsx"},{"name":"OfferCard","sourcePath":"components/jeeb/OfferCard.jsx"},{"name":"ProgressTracker","sourcePath":"components/jeeb/ProgressTracker.jsx"},{"name":"JEEB_TIERS","sourcePath":"components/jeeb/TierBadge.jsx"},{"name":"TierBadge","sourcePath":"components/jeeb/TierBadge.jsx"},{"name":"TierOption","sourcePath":"components/jeeb/TierOption.jsx"},{"name":"TopAppBar","sourcePath":"components/jeeb/TopAppBar.jsx"}],"sourceHashes":{"components/core/Avatar.jsx":"9bb4e1bd9c48","components/core/Badge.jsx":"e6580832c5c6","components/core/Button.jsx":"a363d84381fd","components/core/Card.jsx":"e6df62f1dfcd","components/core/IconButton.jsx":"da2a0d88fa8f","components/core/RatingStars.jsx":"a3061d9d505c","components/forms/ChatInput.jsx":"2dc8e0565e74","components/forms/Input.jsx":"e4509dd69274","components/jeeb/MessageBubble.jsx":"bacad59a1352","components/jeeb/OfferCard.jsx":"869b379be59d","components/jeeb/ProgressTracker.jsx":"7db9f8fed327","components/jeeb/TierBadge.jsx":"7e0eab9d9f5f","components/jeeb/TierOption.jsx":"e6825b52fa45","components/jeeb/TopAppBar.jsx":"20ed8ceb4285","ui_kits/jeeb-app/ChatOffersScreen.jsx":"d30a76c26343","ui_kits/jeeb-app/RequestScreen.jsx":"272d064ffa80","ui_kits/jeeb-app/SplashScreen.jsx":"173a4fa8cfc7","ui_kits/jeeb-app/TrackingScreen.jsx":"74994e561fb8","ui_kits/jeeb-app/VoiceRequestScreen.jsx":"8f582f8a571f"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.JeebDesignSystem_f5873d = window.JeebDesignSystem_f5873d || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/core/Avatar.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/** Circular avatar with image or initials fallback. */
function Avatar({
  src,
  name = "",
  size = 40,
  ring = false,
  style,
  ...rest
}) {
  const initials = name.split(" ").filter(Boolean).slice(0, 2).map(w => w[0]).join("").toUpperCase();
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      width: size,
      height: size,
      borderRadius: "var(--radius-pill)",
      background: "var(--jeeb-periwinkle)",
      color: "var(--jeeb-white)",
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      fontFamily: "var(--font-sans)",
      fontWeight: 600,
      fontSize: Math.round(size * 0.38),
      overflow: "hidden",
      flexShrink: 0,
      boxShadow: ring ? "0 0 0 2px var(--jeeb-white), 0 0 0 4px var(--jeeb-navy)" : "none",
      ...style
    }
  }, rest), src ? /*#__PURE__*/React.createElement("img", {
    src: src,
    alt: name,
    style: {
      width: "100%",
      height: "100%",
      objectFit: "cover"
    }
  }) : initials || "?");
}
Object.assign(__ds_scope, { Avatar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Avatar.jsx", error: String((e && e.message) || e) }); }

// components/core/Badge.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Small status / count pill. tone: navy | orange | success | muted | tier color name.
 */
function Badge({
  children,
  tone = "navy",
  soft = false,
  style,
  ...rest
}) {
  const palette = {
    navy: "var(--jeeb-navy)",
    orange: "var(--jeeb-orange)",
    success: "var(--jeeb-success)",
    muted: "var(--jeeb-periwinkle)",
    flash: "var(--jeeb-tier-flash)",
    express: "var(--jeeb-tier-express)",
    standard: "var(--jeeb-tier-standard)",
    ontheway: "var(--jeeb-tier-ontheway)",
    eco: "var(--jeeb-tier-eco)"
  };
  const c = palette[tone] || palette.navy;
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 4,
      fontFamily: "var(--font-sans)",
      fontWeight: 600,
      fontSize: 12,
      lineHeight: 1,
      padding: "5px 10px",
      borderRadius: "var(--radius-pill)",
      color: soft ? c : "var(--jeeb-white)",
      background: soft ? `color-mix(in srgb, ${c} 14%, white)` : c,
      ...style
    }
  }, rest), children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Jeeb primary action button. Full-pill, navy-filled by default.
 * Variants: primary (navy), accent (orange), secondary (navy outline), ghost (text).
 */
function Button({
  children,
  variant = "primary",
  size = "md",
  disabled = false,
  full = false,
  leadingIcon,
  trailingIcon,
  style,
  ...rest
}) {
  const sizes = {
    sm: {
      padding: "8px 16px",
      fontSize: 14,
      minHeight: 36
    },
    md: {
      padding: "12px 24px",
      fontSize: 15,
      minHeight: 48
    },
    lg: {
      padding: "16px 28px",
      fontSize: 16,
      minHeight: 56
    }
  };
  const variants = {
    primary: {
      background: "var(--jeeb-navy)",
      color: "var(--jeeb-white)",
      border: "none"
    },
    accent: {
      background: "var(--jeeb-orange)",
      color: "var(--jeeb-white)",
      border: "none"
    },
    secondary: {
      background: "transparent",
      color: "var(--jeeb-navy)",
      border: "1.5px solid var(--jeeb-navy)"
    },
    ghost: {
      background: "transparent",
      color: "var(--jeeb-navy)",
      border: "none"
    }
  };
  const s = sizes[size] || sizes.md;
  const v = variants[variant] || variants.primary;
  return /*#__PURE__*/React.createElement("button", _extends({
    disabled: disabled,
    style: {
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      gap: 8,
      fontFamily: "var(--font-sans)",
      fontWeight: 600,
      borderRadius: "var(--radius-pill)",
      cursor: disabled ? "not-allowed" : "pointer",
      opacity: disabled ? 0.45 : 1,
      width: full ? "100%" : "auto",
      transition: "transform .12s ease, filter .12s ease",
      letterSpacing: "0.1px",
      ...s,
      ...v,
      ...style
    },
    onMouseDown: e => !disabled && (e.currentTarget.style.transform = "scale(0.97)"),
    onMouseUp: e => e.currentTarget.style.transform = "scale(1)",
    onMouseLeave: e => e.currentTarget.style.transform = "scale(1)"
  }, rest), leadingIcon ? /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: s.fontSize + 5
    }
  }, leadingIcon) : null, children, trailingIcon ? /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: s.fontSize + 5
    }
  }, trailingIcon) : null);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Card.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Surface container. variant: "outlined" (warm/navy border), "filled" (navy),
 * "muted" (light grey, used for offer/message cards), "plain" (white + soft shadow).
 */
function Card({
  children,
  variant = "plain",
  selected = false,
  style,
  ...rest
}) {
  const base = {
    borderRadius: "var(--radius-lg)",
    padding: "var(--space-4)",
    boxSizing: "border-box"
  };
  const variants = {
    plain: {
      background: "var(--jeeb-white)",
      boxShadow: "var(--shadow-card)",
      border: "none"
    },
    outlined: {
      background: "var(--jeeb-white)",
      border: "1.5px solid var(--jeeb-navy)"
    },
    muted: {
      background: "var(--jeeb-surface-muted)",
      border: "none"
    },
    filled: {
      background: "var(--jeeb-navy)",
      color: "var(--jeeb-white)",
      border: "none"
    }
  };
  const sel = selected ? {
    background: "var(--jeeb-navy)",
    color: "var(--jeeb-white)",
    border: "none",
    boxShadow: "var(--shadow-raised)"
  } : {};
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      ...base,
      ...(variants[variant] || variants.plain),
      ...sel,
      ...style
    }
  }, rest), children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Card.jsx", error: String((e && e.message) || e) }); }

// components/core/IconButton.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Circular/pill icon button using Material Symbols Rounded.
 * tone: "navy" (filled), "ghost" (transparent, navy ink), "light" (on navy).
 */
function IconButton({
  icon,
  tone = "ghost",
  size = 44,
  filled = false,
  style,
  ...rest
}) {
  const tones = {
    navy: {
      background: "var(--jeeb-navy)",
      color: "var(--jeeb-white)"
    },
    ghost: {
      background: "transparent",
      color: "var(--jeeb-navy)"
    },
    light: {
      background: "transparent",
      color: "var(--jeeb-white)"
    },
    surface: {
      background: "var(--jeeb-surface-high)",
      color: "var(--jeeb-navy)"
    }
  };
  const t = tones[tone] || tones.ghost;
  return /*#__PURE__*/React.createElement("button", _extends({
    style: {
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      width: size,
      height: size,
      borderRadius: "var(--radius-pill)",
      border: "none",
      cursor: "pointer",
      flexShrink: 0,
      transition: "filter .12s ease, transform .12s ease",
      ...t,
      ...style
    },
    onMouseDown: e => e.currentTarget.style.transform = "scale(0.92)",
    onMouseUp: e => e.currentTarget.style.transform = "scale(1)",
    onMouseLeave: e => e.currentTarget.style.transform = "scale(1)"
  }, rest), /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: Math.round(size * 0.52),
      fontVariationSettings: `'FILL' ${filled ? 1 : 0}, 'wght' 500`
    }
  }, icon));
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/core/RatingStars.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/** Amber star rating row. Supports halves via decimal value. */
function RatingStars({
  value = 0,
  max = 5,
  size = 18,
  showValue = false,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 2,
      ...style
    }
  }, rest), Array.from({
    length: max
  }).map((_, i) => {
    const fill = Math.max(0, Math.min(1, value - i));
    return /*#__PURE__*/React.createElement("span", {
      key: i,
      className: "material-symbols-rounded",
      style: {
        fontSize: size,
        color: fill > 0 ? "var(--jeeb-star)" : "var(--jeeb-surface-highest)",
        fontVariationSettings: `'FILL' ${fill >= 0.5 ? 1 : 0}, 'wght' 500`
      }
    }, "star");
  }), showValue ? /*#__PURE__*/React.createElement("span", {
    style: {
      marginLeft: 4,
      fontFamily: "var(--font-sans)",
      fontWeight: 600,
      fontSize: size - 4,
      color: "var(--jeeb-navy)"
    }
  }, value.toFixed(1)) : null);
}
Object.assign(__ds_scope, { RatingStars });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/RatingStars.jsx", error: String((e && e.message) || e) }); }

// components/forms/ChatInput.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Jeeb chat composer — the signature voice-first input row.
 * A capsule field (+ attach, placeholder, mic) beside a navy send pill.
 */
function ChatInput({
  value = "",
  onChange,
  onSend,
  onMic,
  onAttach,
  placeholder = "Send message ...",
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      display: "flex",
      alignItems: "center",
      gap: 12,
      padding: "16px 24px 28px",
      background: "var(--jeeb-white)",
      borderTop: "1px solid var(--jeeb-surface-muted)",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: "flex",
      alignItems: "center",
      gap: 10,
      background: "var(--jeeb-surface-high)",
      borderRadius: "var(--radius-field)",
      padding: "0 16px",
      minHeight: 56
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    onClick: onAttach,
    style: {
      fontSize: 26,
      color: "var(--jeeb-navy)",
      cursor: "pointer"
    }
  }, "add"), /*#__PURE__*/React.createElement("input", {
    value: value,
    onChange: onChange,
    placeholder: placeholder,
    style: {
      flex: 1,
      border: "none",
      outline: "none",
      background: "transparent",
      fontFamily: "var(--font-sans)",
      fontSize: 16,
      color: "var(--jeeb-ink)"
    }
  }), /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    onClick: onMic,
    style: {
      fontSize: 24,
      color: "var(--jeeb-navy)",
      cursor: "pointer",
      fontVariationSettings: "'FILL' 1"
    }
  }, "mic")), /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    icon: "send",
    tone: "navy",
    size: 56,
    filled: true,
    onClick: onSend
  }));
}
Object.assign(__ds_scope, { ChatInput });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/ChatInput.jsx", error: String((e && e.message) || e) }); }

// components/forms/Input.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/** Single-line / multiline text field. Optional leading + trailing Material icons. */
function Input({
  value,
  onChange,
  placeholder = "",
  leadingIcon,
  trailingIcon,
  onTrailingClick,
  multiline = false,
  rows = 1,
  style,
  ...rest
}) {
  const Field = multiline ? "textarea" : "input";
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 10,
      background: "var(--jeeb-surface-high)",
      borderRadius: "var(--radius-field)",
      padding: "0 16px",
      minHeight: 56,
      ...style
    }
  }, leadingIcon ? /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 24,
      color: "var(--jeeb-navy)"
    }
  }, leadingIcon) : null, /*#__PURE__*/React.createElement(Field, _extends({
    value: value,
    onChange: onChange,
    placeholder: placeholder,
    rows: multiline ? rows : undefined,
    style: {
      flex: 1,
      border: "none",
      outline: "none",
      background: "transparent",
      resize: "none",
      fontFamily: "var(--font-sans)",
      fontSize: 16,
      color: "var(--jeeb-ink)",
      padding: multiline ? "16px 0" : 0
    }
  }, rest)), trailingIcon ? /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    onClick: onTrailingClick,
    style: {
      fontSize: 24,
      color: "var(--jeeb-navy)",
      cursor: onTrailingClick ? "pointer" : "default"
    }
  }, trailingIcon) : null);
}
Object.assign(__ds_scope, { Input });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Input.jsx", error: String((e && e.message) || e) }); }

// components/jeeb/MessageBubble.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Chat message bubble. from="me" = navy bubble (right), from="them" = grey (left).
 * Shows time + a cyan double-tick read receipt on own messages.
 */
function MessageBubble({
  children,
  from = "me",
  time,
  read = true,
  style,
  ...rest
}) {
  const mine = from === "me";
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      display: "flex",
      justifyContent: mine ? "flex-end" : "flex-start",
      width: "100%",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: "78%",
      background: mine ? "var(--jeeb-navy)" : "var(--jeeb-surface-muted)",
      color: mine ? "var(--jeeb-white)" : "var(--jeeb-ink)",
      padding: "14px 18px",
      borderRadius: mine ? "var(--radius-xl) var(--radius-xl) 4px var(--radius-xl)" : "var(--radius-xl) var(--radius-xl) var(--radius-xl) 4px",
      fontFamily: "var(--font-sans)",
      fontSize: 16,
      lineHeight: "22px",
      fontWeight: 500
    }
  }, children, time ? /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "flex-end",
      gap: 4,
      marginTop: 4,
      fontSize: 12,
      fontWeight: 500,
      color: mine ? "rgba(255,255,255,0.8)" : "var(--jeeb-periwinkle)"
    }
  }, time, mine ? /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 16,
      color: read ? "var(--jeeb-cyan-check)" : "rgba(255,255,255,0.6)"
    }
  }, "done_all") : null) : null));
}
Object.assign(__ds_scope, { MessageBubble });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/jeeb/MessageBubble.jsx", error: String((e && e.message) || e) }); }

// components/jeeb/OfferCard.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Jeeber offer card in the compare-offers chat. Grey block: name (periwinkle) +
 * rating, the offer text, time, and an Accept Offer pill.
 */
function OfferCard({
  name,
  rating = 4,
  message,
  time,
  accepted = false,
  onAccept,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      background: "var(--jeeb-surface-muted)",
      borderRadius: "var(--radius-lg)",
      padding: "18px 20px",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-sans)",
      fontWeight: 600,
      fontSize: 20,
      color: "var(--jeeb-periwinkle)"
    }
  }, name), /*#__PURE__*/React.createElement(__ds_scope.RatingStars, {
    value: rating,
    size: 18
  })), /*#__PURE__*/React.createElement("p", {
    style: {
      margin: "10px 0 0",
      fontFamily: "var(--font-sans)",
      fontSize: 17,
      lineHeight: "24px",
      fontWeight: 600,
      color: "var(--jeeb-ink)"
    }
  }, message), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "flex-end",
      gap: 14,
      marginTop: 10
    }
  }, time ? /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-sans)",
      fontSize: 14,
      color: "var(--jeeb-brown-subtitle)"
    }
  }, time) : null, /*#__PURE__*/React.createElement(__ds_scope.Button, {
    variant: "primary",
    size: "md",
    disabled: accepted,
    onClick: onAccept
  }, accepted ? "Accepted" : "Accept Offer")));
}
Object.assign(__ds_scope, { OfferCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/jeeb/OfferCard.jsx", error: String((e && e.message) || e) }); }

// components/jeeb/ProgressTracker.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Linear order-status tracker: a progress bar with evenly-spaced step labels.
 * steps = ["Ordered","Picked","In Transit"]; current = active index (0-based).
 */
function ProgressTracker({
  steps = ["Ordered", "Picked", "In Transit"],
  current = 1,
  tone = "navy",
  style,
  ...rest
}) {
  const fillColor = tone === "white" ? "var(--jeeb-white)" : "var(--jeeb-navy)";
  const trackColor = tone === "white" ? "rgba(255,255,255,0.35)" : "var(--jeeb-surface-highest)";
  const labelColor = tone === "white" ? "var(--jeeb-white)" : "var(--jeeb-periwinkle)";
  const pct = steps.length > 1 ? current / (steps.length - 1) * 100 : 0;
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      width: "100%",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      height: 4,
      borderRadius: 2,
      background: trackColor
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 0,
      top: 0,
      height: 4,
      borderRadius: 2,
      width: `${pct}%`,
      background: fillColor,
      transition: "width .3s ease"
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      marginTop: 10
    }
  }, steps.map((s, i) => /*#__PURE__*/React.createElement("span", {
    key: s,
    style: {
      fontFamily: "var(--font-sans)",
      fontWeight: i <= current ? 700 : 500,
      fontSize: 13,
      color: labelColor,
      opacity: i <= current ? 1 : 0.6
    }
  }, s))));
}
Object.assign(__ds_scope, { ProgressTracker });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/jeeb/ProgressTracker.jsx", error: String((e && e.message) || e) }); }

// components/jeeb/TierBadge.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/** Tier metadata shared across Jeeb tier components. */
const JEEB_TIERS = {
  flash: {
    name: "Flash",
    emoji: "⚡",
    color: "var(--jeeb-tier-flash)",
    promise: "Delivered in less than 1 hour.",
    framing: "Highest price • Priority pickup"
  },
  express: {
    name: "Express",
    emoji: "🚀",
    color: "var(--jeeb-tier-express)",
    promise: "Arrives within 2-3 hours.",
    framing: "High price • Fast service"
  },
  standard: {
    name: "Standard",
    emoji: "🟦",
    color: "var(--jeeb-tier-standard)",
    promise: "Delivered later today at a balanced rate.",
    framing: "Mid price • Best value"
  },
  ontheway: {
    name: "On-the-Way",
    emoji: "🤝",
    color: "var(--jeeb-tier-ontheway)",
    promise: "Matched with someone already heading there.",
    framing: "Lower price • Flexible timing"
  },
  eco: {
    name: "Eco",
    emoji: "🌿",
    color: "var(--jeeb-tier-eco)",
    promise: "Delivered within 24–48 hours.",
    framing: "Lowest price • Flexible & affordable"
  }
};

/** Compact tier chip: emoji + name, color-coded. */
function TierBadge({
  tier = "standard",
  style,
  ...rest
}) {
  const t = JEEB_TIERS[tier] || JEEB_TIERS.standard;
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 6,
      fontFamily: "var(--font-sans)",
      fontWeight: 600,
      fontSize: 13,
      lineHeight: 1,
      padding: "6px 12px 6px 10px",
      borderRadius: "var(--radius-pill)",
      color: t.color,
      background: `color-mix(in srgb, ${t.color} 14%, white)`,
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 14
    }
  }, t.emoji), t.name);
}
Object.assign(__ds_scope, { JEEB_TIERS, TierBadge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/jeeb/TierBadge.jsx", error: String((e && e.message) || e) }); }

// components/jeeb/TierOption.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Selectable urgency-tier row from the Request screen.
 * Unselected = white + navy outline; selected = solid navy fill.
 * A color swatch precedes the tier name; a radio sits on the right.
 */
function TierOption({
  tier = "standard",
  selected = false,
  onSelect,
  style,
  ...rest
}) {
  const t = __ds_scope.JEEB_TIERS[tier] || __ds_scope.JEEB_TIERS.standard;
  const text = selected ? "var(--jeeb-white)" : "var(--jeeb-ink)";
  const sub = selected ? "rgba(255,255,255,0.8)" : "var(--jeeb-ink)";
  return /*#__PURE__*/React.createElement("div", _extends({
    onClick: onSelect,
    role: "radio",
    "aria-checked": selected,
    style: {
      display: "flex",
      alignItems: "center",
      gap: 16,
      width: "100%",
      boxSizing: "border-box",
      padding: "16px 18px",
      borderRadius: "var(--radius-lg)",
      cursor: "pointer",
      background: selected ? "var(--jeeb-navy)" : "var(--jeeb-white)",
      border: selected ? "1.5px solid var(--jeeb-navy)" : "1.5px solid var(--jeeb-navy)",
      boxShadow: selected ? "var(--shadow-raised)" : "none",
      transition: "background .15s ease, box-shadow .15s ease",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 8,
      marginBottom: 6
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 16,
      height: 16,
      borderRadius: 4,
      background: t.color,
      flexShrink: 0
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-sans)",
      fontWeight: 700,
      fontSize: 17,
      color: text
    }
  }, t.name)), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-sans)",
      fontSize: 14,
      lineHeight: "20px",
      color: sub
    }
  }, t.promise), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-sans)",
      fontWeight: 700,
      fontSize: 14,
      marginTop: 2,
      color: sub
    }
  }, t.framing)), /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 26,
      color: selected ? "var(--jeeb-white)" : "var(--jeeb-navy)",
      fontVariationSettings: `'FILL' ${selected ? 1 : 0}`
    }
  }, selected ? "radio_button_checked" : "radio_button_unchecked"));
}
Object.assign(__ds_scope, { TierOption });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/jeeb/TierOption.jsx", error: String((e && e.message) || e) }); }

// components/jeeb/TopAppBar.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/** Inline text fallback for the Jeeb wordmark (navy "Jee" + orange "b"). */
function WordmarkText() {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-sans)",
      fontWeight: 800,
      fontSize: 22,
      letterSpacing: "-0.5px"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--jeeb-navy)"
    }
  }, "Jee"), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--jeeb-orange)"
    }
  }, "b"));
}

/**
 * Top app bar: brand on the left, centered title, settings/action on the right.
 * Pass logoSrc for the real wordmark SVG; falls back to a text wordmark.
 */
function TopAppBar({
  title,
  logoSrc,
  action = "settings",
  onAction,
  onLogo,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("header", _extends({
    style: {
      position: "relative",
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      height: 64,
      padding: "0 20px",
      background: "var(--jeeb-white)",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    onClick: onLogo,
    style: {
      display: "flex",
      alignItems: "center",
      cursor: onLogo ? "pointer" : "default",
      zIndex: 1
    }
  }, logoSrc ? /*#__PURE__*/React.createElement("img", {
    src: logoSrc,
    alt: "Jeeb",
    style: {
      height: 26
    }
  }) : /*#__PURE__*/React.createElement(WordmarkText, null)), /*#__PURE__*/React.createElement("h1", {
    style: {
      position: "absolute",
      left: 0,
      right: 0,
      margin: 0,
      textAlign: "center",
      fontFamily: "var(--font-sans)",
      fontWeight: 800,
      fontSize: 26,
      color: "var(--jeeb-navy)",
      pointerEvents: "none"
    }
  }, title), /*#__PURE__*/React.createElement("div", {
    style: {
      zIndex: 1
    }
  }, action ? /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    icon: action,
    tone: "ghost",
    onClick: onAction
  }) : /*#__PURE__*/React.createElement("span", {
    style: {
      width: 44
    }
  })));
}
Object.assign(__ds_scope, { TopAppBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/jeeb/TopAppBar.jsx", error: String((e && e.message) || e) }); }

// ui_kits/jeeb-app/ChatOffersScreen.jsx
try { (() => {
/* global React, JeebUI */
// Jeeb mobile — Compare offers (chat with Jeebers)
function ChatOffersScreen({
  onAccept
}) {
  const {
    TopAppBar,
    MessageBubble,
    OfferCard,
    ChatInput,
    Badge
  } = JeebUI();
  const [accepted, setAccepted] = React.useState(null);
  const offers = [{
    id: "kamal",
    name: "Kamal Hajj",
    rating: 4,
    message: "Hi i can bring you your order in 2 hours for 35$",
    time: "09:41"
  }, {
    id: "rana",
    name: "Rana Ahmad",
    rating: 4,
    message: "Hi i can bring you your order in 3 hours for 50$",
    time: "09:41"
  }];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      display: "flex",
      flexDirection: "column",
      background: "#fff"
    }
  }, /*#__PURE__*/React.createElement(TopAppBar, {
    title: "ORD-23748",
    logoSrc: "../../assets/logo/jeeb-wordmark-navy.svg"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: "auto",
      padding: "12px 24px",
      display: "flex",
      flexDirection: "column",
      gap: 18
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "center"
    }
  }, /*#__PURE__*/React.createElement(Badge, {
    tone: "muted",
    soft: true
  }, "Today")), /*#__PURE__*/React.createElement(MessageBubble, {
    from: "me",
    time: "09:41"
  }, "I need 3 kilos of potatoes and a water gallon and coffee from Blend"), offers.map(o => /*#__PURE__*/React.createElement(OfferCard, {
    key: o.id,
    name: o.name,
    rating: o.rating,
    message: o.message,
    time: o.time,
    accepted: accepted === o.id,
    onAccept: () => {
      setAccepted(o.id);
      setTimeout(onAccept, 700);
    }
  })), /*#__PURE__*/React.createElement("p", {
    style: {
      textAlign: "center",
      fontFamily: "var(--font-sans)",
      fontSize: 14,
      color: "var(--jeeb-orange)",
      margin: "2px 0 8px"
    }
  }, accepted ? "Offer accepted — your Jeeber is on the way" : "Accept only one offer")), /*#__PURE__*/React.createElement(ChatInput, null));
}
window.ChatOffersScreen = ChatOffersScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/jeeb-app/ChatOffersScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/jeeb-app/RequestScreen.jsx
try { (() => {
/* global React, JeebUI */
// Jeeb mobile — Request (choose urgency tier)
function RequestScreen({
  onContinue
}) {
  const {
    TopAppBar,
    TierOption,
    Button
  } = JeebUI();
  const [tier, setTier] = React.useState("flash");
  const tiers = ["flash", "express", "standard", "ontheway", "eco"];
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      display: "flex",
      flexDirection: "column",
      background: "#fff"
    }
  }, /*#__PURE__*/React.createElement(TopAppBar, {
    title: "Request",
    logoSrc: "../../assets/logo/jeeb-wordmark-navy.svg"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: "auto",
      padding: "8px 24px 24px"
    }
  }, /*#__PURE__*/React.createElement("h2", {
    style: {
      fontFamily: "var(--font-sans)",
      fontWeight: 600,
      fontSize: 20,
      letterSpacing: "0.15px",
      color: "var(--jeeb-navy)",
      margin: "12px 0 16px"
    }
  }, "Choose your request"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 13
    }
  }, tiers.map(t => /*#__PURE__*/React.createElement(TierOption, {
    key: t,
    tier: t,
    selected: tier === t,
    onSelect: () => setTier(t)
  }))), /*#__PURE__*/React.createElement("h1", {
    style: {
      fontFamily: "var(--font-sans)",
      fontWeight: 700,
      fontSize: 24,
      color: "var(--jeeb-ink)",
      margin: "28px 0 14px"
    }
  }, "Location"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 6,
      fontFamily: "var(--font-sans)",
      fontWeight: 700,
      fontSize: 14,
      color: "var(--jeeb-navy)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 20,
      color: "var(--jeeb-orange)"
    }
  }, "my_location"), "Current Location"), /*#__PURE__*/React.createElement(Button, {
    variant: "ghost",
    size: "sm"
  }, "Change Location"))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "12px 24px 28px",
      borderTop: "1px solid var(--jeeb-surface-muted)"
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "primary",
    full: true,
    size: "lg",
    onClick: onContinue
  }, "Continue")));
}
window.RequestScreen = RequestScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/jeeb-app/RequestScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/jeeb-app/SplashScreen.jsx
try { (() => {
/* global React */
// Jeeb mobile — Splash screen
function SplashScreen({
  onStart
}) {
  return /*#__PURE__*/React.createElement("div", {
    onClick: onStart,
    style: {
      position: "absolute",
      inset: 0,
      background: "var(--jeeb-navy)",
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "center",
      cursor: "pointer"
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: "../../assets/logo/jeeb-wordmark.svg",
    alt: "Jeeb",
    style: {
      width: 188
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      bottom: 64,
      fontFamily: "var(--font-arabic)",
      fontWeight: 700,
      fontSize: 19,
      color: "var(--jeeb-white)"
    }
  }, "Delivery App"), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      bottom: 28,
      fontFamily: "var(--font-sans)",
      fontSize: 13,
      color: "rgba(255,255,255,0.5)"
    }
  }, "Tap to start"));
}
window.SplashScreen = SplashScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/jeeb-app/SplashScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/jeeb-app/TrackingScreen.jsx
try { (() => {
/* global React, JeebUI */
// Jeeb mobile — Order tracking (live map)
function TrackingScreen({
  onRestart
}) {
  const {
    TopAppBar,
    ProgressTracker,
    IconButton
  } = JeebUI();
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      display: "flex",
      flexDirection: "column",
      background: "#fff"
    }
  }, /*#__PURE__*/React.createElement(TopAppBar, {
    title: "Tracking",
    logoSrc: "../../assets/logo/jeeb-wordmark-navy.svg",
    action: "restart_alt",
    onAction: onRestart
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      position: "relative",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: "../../assets/illustrations/map-tracking.jpg",
    alt: "map",
    style: {
      position: "absolute",
      inset: 0,
      width: "100%",
      height: "100%",
      objectFit: "cover"
    }
  }), /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      position: "absolute",
      left: "62%",
      top: "30%",
      fontSize: 44,
      color: "var(--jeeb-tier-flash)",
      fontVariationSettings: "'FILL' 1",
      filter: "drop-shadow(0 3px 4px rgba(0,0,0,.3))"
    }
  }, "location_on"), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: "26%",
      top: "62%",
      width: 44,
      height: 44,
      borderRadius: "50%",
      background: "var(--jeeb-navy)",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      boxShadow: "var(--shadow-fab)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 24,
      color: "#fff"
    }
  }, "two_wheeler"))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "20px 24px 28px"
    }
  }, /*#__PURE__*/React.createElement(ProgressTracker, {
    steps: ["Ordered", "Picked", "In Transit"],
    current: 2
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 16,
      fontFamily: "var(--font-sans)",
      fontWeight: 700,
      fontSize: 13,
      color: "var(--jeeb-periwinkle)",
      lineHeight: "22px"
    }
  }, /*#__PURE__*/React.createElement("div", null, "3km away from you"), /*#__PURE__*/React.createElement("div", null, "Estimated time: 20 mins"))));
}
window.TrackingScreen = TrackingScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/jeeb-app/TrackingScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/jeeb-app/VoiceRequestScreen.jsx
try { (() => {
/* global React, JeebUI */
// Jeeb mobile — Voice request (speak your order)
function VoiceRequestScreen({
  onSend
}) {
  const {
    TopAppBar,
    MessageBubble,
    ChatInput,
    Badge
  } = JeebUI();
  const [text, setText] = React.useState("");
  const [recording, setRecording] = React.useState(false);
  const [sent, setSent] = React.useState(false);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      display: "flex",
      flexDirection: "column",
      background: "#fff"
    }
  }, /*#__PURE__*/React.createElement(TopAppBar, {
    title: "Request",
    logoSrc: "../../assets/logo/jeeb-wordmark-navy.svg"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: "auto",
      padding: "16px 24px",
      display: "flex",
      flexDirection: "column",
      gap: 18
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "center"
    }
  }, /*#__PURE__*/React.createElement(Badge, {
    tone: "muted",
    soft: true
  }, "Today")), sent ? /*#__PURE__*/React.createElement(MessageBubble, {
    from: "me",
    time: "09:41"
  }, "I need 3 kilos of potatoes and a water gallon and coffee from Blend") : /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 40,
      textAlign: "center",
      color: "var(--jeeb-periwinkle)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 96,
      height: 96,
      borderRadius: "50%",
      background: recording ? "var(--jeeb-orange)" : "var(--jeeb-surface-high)",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      margin: "0 auto 16px",
      transition: "background .2s ease",
      boxShadow: recording ? "0 0 0 10px rgba(215,59,0,0.12)" : "none"
    }
  }, /*#__PURE__*/React.createElement("span", {
    className: "material-symbols-rounded",
    style: {
      fontSize: 44,
      color: recording ? "#fff" : "var(--jeeb-navy)",
      fontVariationSettings: "'FILL' 1"
    }
  }, "mic")), /*#__PURE__*/React.createElement("p", {
    style: {
      fontFamily: "var(--font-sans)",
      fontSize: 16,
      margin: 0
    }
  }, recording ? "Listening… say what you need" : "Hold the mic and say what you need"))), /*#__PURE__*/React.createElement(ChatInput, {
    value: text,
    onChange: e => setText(e.target.value),
    onMic: () => {
      setRecording(true);
      setTimeout(() => {
        setRecording(false);
        setSent(true);
      }, 1200);
    },
    onSend: () => {
      if (sent || text) onSend();
    }
  }));
}
window.VoiceRequestScreen = VoiceRequestScreen;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/jeeb-app/VoiceRequestScreen.jsx", error: String((e && e.message) || e) }); }

__ds_ns.Avatar = __ds_scope.Avatar;

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.RatingStars = __ds_scope.RatingStars;

__ds_ns.ChatInput = __ds_scope.ChatInput;

__ds_ns.Input = __ds_scope.Input;

__ds_ns.MessageBubble = __ds_scope.MessageBubble;

__ds_ns.OfferCard = __ds_scope.OfferCard;

__ds_ns.ProgressTracker = __ds_scope.ProgressTracker;

__ds_ns.JEEB_TIERS = __ds_scope.JEEB_TIERS;

__ds_ns.TierBadge = __ds_scope.TierBadge;

__ds_ns.TierOption = __ds_scope.TierOption;

__ds_ns.TopAppBar = __ds_scope.TopAppBar;

})();
