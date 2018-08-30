#include <CSPreferences/CSPreferencesProvider.h>

@interface CSCProvider : NSObject

+ (CSPreferencesProvider *)sharedProvider;
+ (BOOL)tweakWithDylibNameInstalledAndEnabled:(NSString *)dylib plistName:(NSString *)plist enabledKey:(NSString *)key;

@end