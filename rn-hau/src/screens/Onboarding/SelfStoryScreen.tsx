import { View, Text, ViewStyle, TextStyle, TextInput, TouchableOpacity, KeyboardAvoidingView, Platform, ScrollView } from 'react-native';
import Header from '../../components/Header';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { OnboardingStackParamList } from '../../navigation/OnboardingNavigator';
import { colors } from '../../styles/theme';
import { RootStackParamList } from '../../navigation/AppNavigator';
import { useState } from 'react';

type AppNavigationProp = NativeStackNavigationProp<RootStackParamList, 'Main'>;
type OnboardingNavigationProp = NativeStackNavigationProp<OnboardingStackParamList, 'SelfStory'>;

const SelfStoryScreen = () => {
  const onboardingNavigation = useNavigation<OnboardingNavigationProp>();
  const appNavigation = useNavigation<AppNavigationProp>();
  const [text, setText] = useState('');
  const maxLength = 2000;

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
              <View style={{
                flex: 1,
                width: '100%',
              }}>
                <View style={styles.bar}>
                  <View style={styles.barInner} />
                </View>
                <View>
                  <View style={styles.titleContainer}>
                    <Text style={styles.title}>함께 나누고싶은</Text>
                    <Text style={styles.title}>나의 이야기를 적어주세요.</Text>
                  </View>
                  <Text style={styles.description}>함께 더 많은 이야기를 할 수 있어요.</Text>
                </View>
                <View style={styles.inputContainer}>
                  <TextInput
                    style={styles.input}
                    placeholder="이야기를 적어주세요."
                    multiline={true}
                    numberOfLines={8}
                    maxLength={maxLength}
                    textAlignVertical="top"
                    value={text}
                    onChangeText={setText}
                  />
                  <View style={styles.characterCount}>
                    <Text style={styles.characterCountText}>
                      {text.length}/{maxLength}
                    </Text>
                  </View>
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
                  onPress={() => appNavigation.navigate('Permission')}
                >
                  <Text style={{
                    color: colors.light,
                    fontSize: 16,
                    fontWeight: 'bold',
                  }}>시작하기</Text>
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
  characterCount: ViewStyle;
  characterCountText: TextStyle;
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
    width: '100%',
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
    flex: 1,
    width: '100%',
    borderRadius: 28,
    borderWidth: 1,
    borderColor: colors.primary,
    padding: 20,
    marginTop: 24,
    marginBottom: 24,
    position: 'relative',
  },
  input: {
    flex: 1,
    height: '100%',
    fontSize: 16,
    color: colors.dark,
    paddingBottom: 24,
  },
  characterCount: {
    position: 'absolute',
    bottom: 20,
    right: 20
  },
  characterCountText: {
    fontSize: 12,
    color: colors.secondary,
  },
};

export default SelfStoryScreen;