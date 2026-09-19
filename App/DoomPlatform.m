#import "DoomPlatform.h"
#include "doomgeneric.h"
#include <mach/mach_time.h>
#include <pthread.h>
#include <unistd.h>

#define KEYQUEUE_SIZE 64

static unsigned short keyQueue[KEYQUEUE_SIZE];
static unsigned int keyRead = 0;
static unsigned int keyWrite = 0;
static pthread_mutex_t keyLock = PTHREAD_MUTEX_INITIALIZER;
static DoomFrameHandler frameHandler = nil;
static BOOL running = NO;
static uint64_t startTicks = 0;
static char executableName[] = "doom-ios";
static char iwadFlag[] = "-iwad";
static char noSoundFlag[] = "-nosound";
static char noMusicFlag[] = "-nomusic";
static char *persistentWADPath = NULL;
static char *engineArgv[6] = { executableName, iwadFlag, NULL, noSoundFlag, noMusicFlag, NULL };

void DoomPlatformSetFrameHandler(DoomFrameHandler handler) {
    frameHandler = [handler copy];
}

void DoomPlatformKey(BOOL pressed, unsigned char key) {
    pthread_mutex_lock(&keyLock);
    unsigned int next = (keyWrite + 1) % KEYQUEUE_SIZE;
    if (next != keyRead) {
        keyQueue[keyWrite] = ((pressed ? 1 : 0) << 8) | key;
        keyWrite = next;
    }
    pthread_mutex_unlock(&keyLock);
}

BOOL DoomPlatformIsRunning(void) { return running; }

void DoomPlatformStart(NSString *wadPath) {
    if (running) return;
    running = YES;
    chdir(wadPath.stringByDeletingLastPathComponent.fileSystemRepresentation);
    persistentWADPath = strdup(wadPath.fileSystemRepresentation);
    engineArgv[2] = persistentWADPath;
    doomgeneric_Create(5, engineArgv);
}

void DoomPlatformTick(void) {
    if (running) doomgeneric_Tick();
}

void DG_Init(void) {
    memset(keyQueue, 0, sizeof(keyQueue));
    startTicks = mach_absolute_time();
}

void DG_DrawFrame(void) {
    DoomFrameHandler handler = frameHandler;
    if (!handler || !DG_ScreenBuffer) return;
    NSData *frame = [NSData dataWithBytes:DG_ScreenBuffer length:DOOMGENERIC_RESX * DOOMGENERIC_RESY * 4];
    dispatch_async(dispatch_get_main_queue(), ^{ handler(frame); });
}

void DG_SleepMs(uint32_t ms) { usleep(ms * 1000); }

uint32_t DG_GetTicksMs(void) {
    mach_timebase_info_data_t info;
    mach_timebase_info(&info);
    uint64_t elapsed = mach_absolute_time() - startTicks;
    return (uint32_t)((elapsed * info.numer / info.denom) / 1000000ULL);
}

int DG_GetKey(int *pressed, unsigned char *key) {
    pthread_mutex_lock(&keyLock);
    if (keyRead == keyWrite) {
        pthread_mutex_unlock(&keyLock);
        return 0;
    }
    unsigned short data = keyQueue[keyRead];
    keyRead = (keyRead + 1) % KEYQUEUE_SIZE;
    pthread_mutex_unlock(&keyLock);
    *pressed = data >> 8;
    *key = data & 0xff;
    return 1;
}

void DG_SetWindowTitle(const char *title) { (void)title; }
