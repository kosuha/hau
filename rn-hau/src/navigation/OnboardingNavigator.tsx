// src/navigation/OnboardingNavigator.tsx
import React from 'react';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import NameInputScreen from '../screens/Onboarding/NameInputScreen';
import BirthdateInputScreen from '../screens/Onboarding/BirthdateInputScreen';
import SelfStoryScreen from '../screens/Onboarding/SelfStoryScreen';

export type OnboardingStackParamList = {
  NameInput: undefined;
  BirthdateInput: undefined;
  SelfStory: undefined;
};

const OnboardingStack = createNativeStackNavigator<OnboardingStackParamList>();

const OnboardingNavigator: React.FC = () => {
  return (
    <OnboardingStack.Navigator screenOptions={{ headerShown: false }}>
      <OnboardingStack.Screen name="NameInput" component={NameInputScreen} />
      <OnboardingStack.Screen name="BirthdateInput" component={BirthdateInputScreen} />
      <OnboardingStack.Screen name="SelfStory" component={SelfStoryScreen} />
    </OnboardingStack.Navigator>
  );
};

export default OnboardingNavigator;
