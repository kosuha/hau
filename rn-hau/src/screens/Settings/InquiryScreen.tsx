import { View, ViewStyle } from 'react-native';
import Header from '../../components/Header';
import { useNavigation } from '@react-navigation/native';
import { SettingsStackParamList } from '../../navigation/SettingsStackNavigator';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';

type SettingsNavigationProp = NativeStackNavigationProp<SettingsStackParamList, 'CallTimeSetting'>;

const InquiryScreen = () => {
  const settingsNavigation = useNavigation<SettingsNavigationProp>();

  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.container}>
        <Header onPress={() => settingsNavigation.goBack()} title="문의하기" />
      </SafeAreaView>
    </SafeAreaProvider>
  );
};

interface Style {
  container: ViewStyle;
}

const styles: Style = {
  container: {
    flex: 1,
    flexDirection: 'column',
    gap: 16,
    justifyContent: 'flex-start',
    alignItems: 'flex-start',
  },
};

export default InquiryScreen;

