#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef void (^DoomFrameHandler)(NSData *rgbaFrame);

void DoomPlatformSetFrameHandler(DoomFrameHandler _Nullable handler);
void DoomPlatformStart(NSString *wadPath);
void DoomPlatformTick(void);
void DoomPlatformKey(BOOL pressed, unsigned char key);
BOOL DoomPlatformIsRunning(void);

NS_ASSUME_NONNULL_END

