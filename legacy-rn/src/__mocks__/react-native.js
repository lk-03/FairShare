module.exports = {
  Platform: {
    OS: 'android',
    select: (obj) => obj.android || obj.default,
  },
  Linking: {
    canOpenURL: jest.fn().mockResolvedValue(true),
    openURL: jest.fn().mockResolvedValue(true),
  },
  StyleSheet: {
    create: (styles) => styles,
  },
};
