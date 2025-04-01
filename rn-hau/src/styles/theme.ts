// src/styles/theme.ts

export const colors = {
  primary: '#2C3930',
  secondary: '#3F4F44',
  tertiary: '#A27B5C',
  quaternary: '#DCD7C9',
  accent: '#26BF00',
  background: '#ffffff',
  text: '#191F28',
  disabled: '#8B95A1',
  placeholder: '#B0B8C1',
  light: '#ffffff',
  dark: '#191F28',
  lightTransparent: 'rgba(255, 255, 255, 0.6)',
};

export const gradients = {
  // 그라데이션 색상 배열 (시작 색상, 종료 색상)
  primary: [colors.secondary, colors.primary] as [string, string],
};

export const fonts = {
  regular: 'System',
  bold: 'System',
};

export const sizes = {
  base: 8,
  font: 14,
  padding: 16,
  // 기타 사이즈 정의
};

const theme = { colors, fonts, sizes };

export default theme;
