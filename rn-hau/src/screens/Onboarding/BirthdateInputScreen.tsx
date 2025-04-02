import { View, Text, ViewStyle } from 'react-native';
import Header from '../../components/Header';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { OnboardingStackParamList } from '../../navigation/OnboardingNavigator';

type OnboardingNavigationProp = NativeStackNavigationProp<OnboardingStackParamList, 'BirthdateInput'>;

const BirthdateInputScreen = () => {
  const onboardingNavigation = useNavigation<OnboardingNavigationProp>();

  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.container}>
        <Header onPress={() => onboardingNavigation.goBack()} />
        <View>
          <Text>생년월일</Text>
        </View>
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

export default BirthdateInputScreen;