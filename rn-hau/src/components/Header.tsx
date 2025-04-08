import { View, Text, TouchableOpacity } from 'react-native';
import { Ionicons } from '@expo/vector-icons';

const Header = ({ onPress, title, isClose }: { onPress?: () => void, title?: string, isClose?: boolean }) => {
  return (
    <View style={{
      flexDirection: 'row',
      justifyContent: 'center',
      alignItems: 'center',
      paddingHorizontal: 20,
      height: 60,
      width: '100%',
    }}>
      {
        onPress && (
          <TouchableOpacity onPress={onPress} style={{ position: 'absolute', left: 20 }}>
            <Ionicons name={isClose ? "close" : "chevron-back"} size={24} color="black" />
          </TouchableOpacity>
        )
      }
      {title && (
        <Text style={{ alignSelf: 'center', fontSize: 18, fontWeight: 'bold' }}>{title}</Text>
      )}
    </View>
  );
};

export default Header;