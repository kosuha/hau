// src/navigation/AppNavigator.tsx

import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import MainScreen from '../screens/Main/MainScreen';
import SettingsStackNavigator, { SettingsStackParamList } from './SettingsStackNavigator';
import OnboardingNavigator, { OnboardingStackParamList } from './OnboardingNavigator';
import PermissionScreen from '../screens/Permissions/PermissionScreen';
import LoginScreen from '../screens/Login/LoginScreen';

export type RootStackParamList = {
  Main: undefined;
  SettingsStack: { screen?: keyof SettingsStackParamList; params?: object } | undefined;
  OnboardingStack: { screen?: keyof OnboardingStackParamList; params?: object } | undefined;
  Permission: undefined;
  Login: undefined;
};

const Stack = createNativeStackNavigator<RootStackParamList>();

const AppNavigator: React.FC = () => {
  return (
    <NavigationContainer>
      <Stack.Navigator initialRouteName="Main">
        <Stack.Screen 
          name="Main" 
          component={MainScreen} 
          options={{ headerShown: false }} 
        />
        <Stack.Screen 
          name="SettingsStack" 
          component={SettingsStackNavigator} 
          options={{ headerShown: false }} 
        />
        <Stack.Screen 
          name="OnboardingStack" 
          component={OnboardingNavigator} 
          options={{ headerShown: false }} 
        />
        <Stack.Screen 
          name="Login" 
          component={LoginScreen} 
          options={{ headerShown: false }} 
        />
        <Stack.Screen 
          name="Permission" 
          component={PermissionScreen} 
          options={{ headerShown: false }} 
        />  
      </Stack.Navigator>
    </NavigationContainer>
  );
};

export default AppNavigator;
