import React from 'react';
import { Text, StyleSheet, View, ViewStyle, TextStyle, TouchableOpacity } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { gradients, colors } from '../../styles/theme';
import { Ionicons } from '@expo/vector-icons';
import { SafeAreaView, SafeAreaProvider } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import { RootStackParamList } from '../../navigation/AppNavigator';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { SettingsStackParamList } from '../../navigation/SettingsStackNavigator';

type AppNavigationProp = NativeStackNavigationProp<RootStackParamList, 'Main'>;
type SettingsNavigationProp = NativeStackNavigationProp<SettingsStackParamList, 'Settings'>;

const SettingsButton: React.FC<{ onPress: () => void }> = ({ onPress }) => {
  return (
    <TouchableOpacity onPress={onPress}>
      <Ionicons name="settings-sharp" size={24} color="white" />
    </TouchableOpacity>
  );
};

const CallButton: React.FC<{ onPress: () => void }> = ({ onPress }) => {
  return (
    <TouchableOpacity onPress={onPress} style={{
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'center',
      borderWidth: 1,
      borderColor: colors.light,
      paddingHorizontal: 70,
      paddingVertical: 16,
      gap: 10,
      borderRadius: 999,
      backgroundColor: colors.light,
    }}>
      <Ionicons name="call" size={24} color={colors.accent} />
      <Text style={{
        color: colors.dark,
        fontSize: 18,
        fontWeight: 'bold',
      }}>지금 통화하기</Text>
    </TouchableOpacity>
  );
};

const AlertBox: React.FC<{ onPress: () => void }> = ({ onPress }) => {
  return (
    <TouchableOpacity onPress={onPress} style={{
      flexDirection: 'row',
      alignItems: 'center',
      justifyContent: 'flex-start',
      gap: 14,
      width: '100%',
      backgroundColor: colors.lightTransparent,
      borderRadius: 16,
      paddingHorizontal: 22,
      paddingVertical: 17,
    }}>
      <View style={{
        flexDirection: 'row',
        alignItems: 'center',
        justifyContent: 'flex-start',
        gap: 10,
        backgroundColor: colors.light,
        paddingHorizontal: 10,
        paddingVertical: 10,
        borderRadius: 10,
      }}>
        <Ionicons name="person" size={24} color={colors.tertiary} />
      </View>
      <View style={{
        flexDirection: 'column',
        alignItems: 'flex-start',
        justifyContent: 'flex-start',
        gap: 1,
      }}>
        <Text style={{
          fontSize: 16,
          fontWeight: 'bold',
          color: colors.dark,
        }}>오늘 오후 10시</Text>
        <Text style={{
          fontSize: 16,
          fontWeight: 'normal',
        }}>통화하기로 한거 잊지 않으셨죠?</Text>
      </View>
    </TouchableOpacity>
  );
};

const MainScreen: React.FC = () => {
  const appNavigation = useNavigation<AppNavigationProp>();
  const settingsNavigation = useNavigation<SettingsNavigationProp>();

  return (
    <LinearGradient
      style={{ flex: 1 }}
      colors={gradients.primary as [string, string]}
      start={{ x: 0.5, y: 0 }}
      end={{ x: 0.5, y: 0.6 }} 
    >
      <SafeAreaProvider>
        <SafeAreaView style={styles.container}>
          <View style={styles.header}>
            <SettingsButton onPress={() => appNavigation.navigate('SettingsStack')} />
          </View>
          <View style={styles.content}>
            <View style={styles.titleContainer}>
              <View style={{
                flexDirection: 'column',
                alignItems: 'flex-start',
                justifyContent: 'flex-start',
                gap: 10,
                marginBottom: 43,
              }}>
                <Text style={styles.titleText}>주야님,</Text>
                <Text style={styles.titleText}>좋은 아침이에요!</Text>
              </View>
              <View style={{
                flexDirection: 'row',
                alignItems: 'center',
                justifyContent: 'center',
                gap: 10,
              }}>
                <AlertBox onPress={() => {
                  appNavigation.navigate('SettingsStack', { screen: 'CallTimeSetting' });
                }} />
              </View>
            </View>
            <View style={styles.buttonContainer}>
              <CallButton onPress={() => {}} />
            </View>
          </View>
        </SafeAreaView>
      </SafeAreaProvider>
    </LinearGradient>
  );
};

interface Style {
  container: ViewStyle;
  text: TextStyle;
  header: ViewStyle;
  content: ViewStyle;
  titleContainer: ViewStyle;
  buttonContainer: ViewStyle;
  titleText: TextStyle;
}

const styles = StyleSheet.create<Style>({
  container: {
    flex: 1,
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    width: '100%',
    height: '100%',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    alignItems: 'center',
    paddingHorizontal: 20,
    width: '100%',
    height: '10%',
  },
  content: {
    flex: 1,
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    paddingHorizontal: 20,
    width: '100%',
    height: '100%',
  },
  titleContainer: {
    flexDirection: 'column',
    alignItems: 'flex-start',
    justifyContent: 'flex-start',
    width: '100%',
  },
  buttonContainer: {
    flexDirection: 'column',
    alignItems: 'center',
    justifyContent: 'center',
    width: '100%',
    marginBottom: 57,
  },
  text: {
    fontSize: 24,
    color: '#fff'
  },
  titleText: {
    fontSize: 26,
    fontWeight: 'bold',
    color: colors.light,
  }
});

export default MainScreen;
