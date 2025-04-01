// src/styles/global.js

import { StyleSheet } from 'react-native';
import theme from './theme';

export default StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: theme.colors.background,
    padding: theme.sizes.padding,
  },
  text: {
    color: theme.colors.text,
    fontSize: theme.sizes.font,
  },
  // 추가 공통 스타일 정의
});
