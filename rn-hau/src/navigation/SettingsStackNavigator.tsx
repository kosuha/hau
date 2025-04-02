// src/navigation/SettingsStackNavigator.tsx
import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import SettingsScreen from '../screens/Settings/SettingsScreen';
import ProfileScreen from '../screens/Settings/ProfileScreen';
import CallTimeSettingScreen from '../screens/Settings/CallTimeSettingScreen';
import VoiceSettingScreen from '../screens/Settings/VoiceSettingScreen';
import OpenSourceScreen from '../screens/Settings/OpenSourceScreen';
import InquiryScreen from '../screens/Settings/InquiryScreen';
import TermsOfServiceScreen from '../screens/Settings/TermsOfServiceScreen';
import PrivacyPolicyScreen from '../screens/Settings/PrivacyPolicyScreen';

export type SettingsStackParamList = {
  Settings: undefined;
  Profile: undefined;
  CallTimeSetting: undefined;
  VoiceSetting: undefined;
  OpenSource: undefined;
  Inquiry: undefined;
  TermsOfService: undefined;
  PrivacyPolicy: undefined;
};

const Stack = createNativeStackNavigator<SettingsStackParamList>();

const SettingsStackNavigator: React.FC = () => {
  return (
    <Stack.Navigator initialRouteName="Settings">
      <Stack.Screen
        name="Settings"
        component={SettingsScreen}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="Profile"
        component={ProfileScreen}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="CallTimeSetting"
        component={CallTimeSettingScreen}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="VoiceSetting" // 목소리 설정
        component={VoiceSettingScreen}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="OpenSource"
        component={OpenSourceScreen}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="Inquiry"
        component={InquiryScreen}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="TermsOfService"
        component={TermsOfServiceScreen}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="PrivacyPolicy"
        component={PrivacyPolicyScreen}
        options={{ headerShown: false }}
      />
    </Stack.Navigator>
  );
};

export default SettingsStackNavigator;
