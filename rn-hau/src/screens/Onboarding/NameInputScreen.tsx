import { View, Text, ViewStyle, TextStyle, TextInput, TouchableOpacity, KeyboardAvoidingView, ScrollView, Platform } from 'react-native';
import Header from '../../components/Header';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { OnboardingStackParamList } from '../../navigation/OnboardingNavigator';
import { colors } from '../../styles/theme';

type OnboardingNavigationProp = NativeStackNavigationProp<OnboardingStackParamList, 'BirthdateInput'>;

const NameInputScreen = () => {
  const onboardingNavigation = useNavigation<OnboardingNavigationProp>();

  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.container}>
        <Header onPress={() => onboardingNavigation.goBack()} />
        <KeyboardAvoidingView 
          behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
          style={{ flex: 1, width: '100%' }}
        >
          <ScrollView 
            contentContainerStyle={{ flexGrow: 1 }}
            keyboardShouldPersistTaps="handled"
          >
            <View style={styles.content}>
              <View>
                <View style={styles.bar}>
                  <View style={styles.barInner} />
                </View>
                <View>
                  <View style={styles.titleContainer}>
                    <Text style={styles.title}>만나서 반가워요.</Text>
                    <Text style={styles.title}>이름이 어떻게 되나요?</Text>
                  </View>
                  <Text style={styles.description}>적어주신 이름으로 불러드려요.</Text>
                </View>
                <View style={styles.inputContainer}>
                  <TextInput
                    style={styles.input}
                    placeholder="이름 입력 (최대 12자)"
                    maxLength={12} 
                  />
                </View>
              </View>
              <View>
                <TouchableOpacity 
                  style={{
                    backgroundColor: colors.primary,
                    padding: 16,
                    borderRadius: 999,
                    borderWidth: 1,
                    justifyContent: 'center',
                    alignItems: 'center',
                    flexDirection: 'row',
                    gap: 6,
                    height: 56,
                    marginBottom: 37,
                  }} 
                  onPress={() => onboardingNavigation.navigate('BirthdateInput')}
                >
                  <Text style={{
                    color: colors.light,
                    fontSize: 16,
                    fontWeight: 'bold',
                  }}>다음</Text>
                </TouchableOpacity>
              </View>
            </View>
          </ScrollView>
        </KeyboardAvoidingView>
      </SafeAreaView>
    </SafeAreaProvider>
  );
};

interface Style {
  container: ViewStyle;
  bar: ViewStyle;
  barInner: ViewStyle;
  content: ViewStyle;
  title: TextStyle;
  description: TextStyle;
  titleContainer: ViewStyle;
  inputContainer: ViewStyle;
  input: TextStyle;
}

const styles: Style = {
  container: {
    flex: 1,
    flexDirection: 'column',
    gap: 16,
    justifyContent: 'flex-start',
    alignItems: 'flex-start',
  },
  content: {
    flex: 1,
    width: '100%',
    flexDirection: 'column',
    justifyContent: 'space-between',
    gap: 16,
    paddingHorizontal: 20,
  },
  bar: {
    width: '100%',
    height: 6,
    backgroundColor: colors.secondaryLight,
    borderRadius: 999
  },
  barInner: {
    width: '33.33%',
    height: '100%',
    backgroundColor: colors.secondary,
    borderRadius: 999,
  },
  title: {
    fontSize: 26,
    fontWeight: 'bold',
    color: colors.dark,
  },
  description: {
    fontSize: 16,
    color: colors.secondary,
  },
  titleContainer: {
    flexDirection: 'column',
    gap: 4,
    marginBottom: 8,
    marginTop: 36,
  },
  inputContainer: {
    width: '100%',
    height: 59,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: colors.primary,
    marginTop: 40,
  },
  input: {
    flex: 1,
    paddingHorizontal: 16,
    fontSize: 16,
    color: colors.dark,
  },
};

export default NameInputScreen;