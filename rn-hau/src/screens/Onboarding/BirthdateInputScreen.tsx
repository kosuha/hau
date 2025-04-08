import { View, Text, ViewStyle, TextStyle, TouchableOpacity, Platform } from 'react-native';
import Header from '../../components/Header';
import { useNavigation } from '@react-navigation/native';
import { NativeStackNavigationProp } from '@react-navigation/native-stack';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { OnboardingStackParamList } from '../../navigation/OnboardingNavigator';
import { colors } from '../../styles/theme';
import { useState } from 'react';
import DateTimePicker from '@react-native-community/datetimepicker';

type OnboardingNavigationProp = NativeStackNavigationProp<OnboardingStackParamList, 'BirthdateInput'>;

const BirthdateInputScreen = () => {
  const onboardingNavigation = useNavigation<OnboardingNavigationProp>();
  const [selectedDate, setSelectedDate] = useState(new Date());

  const onChange = (event: any, selectedDate?: Date) => {
    const currentDate = selectedDate || new Date();
    setSelectedDate(currentDate);
  };

  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.container}>
        <Header onPress={() => onboardingNavigation.goBack()} />
        <View style={styles.content}>
          <View>
            <View style={styles.bar}>
              <View style={styles.barInner} />
            </View>
            <View>
              <View style={styles.titleContainer}>
                <Text style={styles.title}>생년월일을 알려주세요.</Text>
              </View>
              <Text style={styles.description}>더 진솔한 대화를 위해 필요해요.</Text>
            </View>
            <View style={{
              marginTop: 20,
            }}>
              <DateTimePicker
                value={selectedDate}
                mode="date"
                display={Platform.OS === 'ios' ? 'spinner' : 'default'}
                onChange={onChange}
                locale="ko-KR"
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
              onPress={() => onboardingNavigation.navigate('SelfStory')}
            >
              <Text style={{
                color: colors.light,
                fontSize: 16,
                fontWeight: 'bold',
              }}>다음</Text>
            </TouchableOpacity>
          </View>
        </View>
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
    width: '66.66%',
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
    flexDirection: 'row',
    gap: 16,
    alignItems: 'center',
    justifyContent: 'flex-start',
    borderWidth: 1,
    borderColor: colors.secondary,
    borderRadius: 16,
    padding: 16,
    marginTop: 16,
  },
  input: {
    flex: 1,
    paddingHorizontal: 16,
    fontSize: 16,
    color: colors.dark,
  },
};

export default BirthdateInputScreen;