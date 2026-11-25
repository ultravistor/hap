#import <AppKit/AppKit.h>
#include <dlfcn.h>
#include <stdint.h>
#include <string.h>
#include <IOKit/hid/IOHIDManager.h>
#include <IOKit/hid/IOHIDDevice.h>

typedef void* (*MTDeviceCreateDefaultRef)(void);
typedef void* (*MTActuatorCreateFromDeviceIDRef)(uint64_t);
typedef int (*MTActuatorOpenRef)(void*);
typedef int (*MTActuatorActuateRef)(void*, int, int, float, float);
typedef int (*MTActuatorCloseRef)(void*);

// Helper function to extract a number property from an IOHIDDeviceRef
int32_t getHIDIntProperty(IOHIDDeviceRef device, CFStringRef key) {
    CFTypeRef ref = IOHIDDeviceGetProperty(device, key);
    int32_t value = 0;
    if (ref && CFGetTypeID(ref) == CFNumberGetTypeID()) {
        CFNumberGetValue((CFNumberRef)ref, kCFNumberSInt32Type, &value);
    }
    return value;
}

@interface HapticAppDelegate : NSObject <NSApplicationDelegate>
@property (strong) NSWindow *window;
@property (strong) NSTimer *timer;
@end

@implementation HapticAppDelegate {
    void *multitouchHandle;
    MTActuatorCreateFromDeviceIDRef actuatorCreate;
    MTActuatorOpenRef actuatorOpen;
    MTActuatorActuateRef actuatorActuate;
    MTActuatorCloseRef actuatorClose;
    uint64_t targetDeviceID;
    
    double userInterval;
    int userPattern;
    float userIntensity;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    
    // Corrected Array lookups: extract string first, then request specific type values
    userInterval  = (args.count > 1) ? [[args objectAtIndex:1] doubleValue] : 0.1;
    userPattern   = (args.count > 2) ? [[args objectAtIndex:2] intValue]    : 1;
    userIntensity = (args.count > 3) ? [[args objectAtIndex:3] floatValue]  : 1.0f;

    if (userInterval < 0.01) userInterval = 0.01;
    if (userIntensity > 1.0f) userIntensity = 1.0f;

    multitouchHandle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW);
    if (multitouchHandle) {
        MTDeviceCreateDefaultRef deviceCreate = (MTDeviceCreateDefaultRef)dlsym(multitouchHandle, "MTDeviceCreateDefault");
        actuatorCreate = (MTActuatorCreateFromDeviceIDRef)dlsym(multitouchHandle, "MTActuatorCreateFromDeviceID");
        actuatorOpen = (MTActuatorOpenRef)dlsym(multitouchHandle, "MTActuatorOpen");
        actuatorActuate = (MTActuatorActuateRef)dlsym(multitouchHandle, "MTActuatorActuate");
        actuatorClose = (MTActuatorCloseRef)dlsym(multitouchHandle, "MTActuatorClose");
        
        if (deviceCreate) {
            void* dev = deviceCreate();
            if (dev) {
                memcpy(&targetDeviceID, (char*)dev + 64, sizeof(uint64_t));
            }
        }
    }

    NSRect frame = NSMakeRect(0, 0, 360, 140);
    self.window = [[NSWindow alloc] initWithContentRect:frame
                                              styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window setTitle:@"Trackpad Haptic Generator"];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    
    NSTextField *label = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 20, 320, 80)];
    NSString *statusText = [NSString stringWithFormat:
                            @"🔄 Parameters Live Action:\n"
                            @"• Loop Speed: %.3f sec\n"
                            @"• Waveform Pattern ID: %d\n"
                            @"• Magnet Amp Intensity: %.1f", 
                            userInterval, userPattern, userIntensity];
    [label setStringValue:statusText];
    [label setEditable:NO];
    [label setBordered:NO];
    [label setDrawsBackground:NO];
    [[self.window contentView] addSubview:label];

    self.timer = [NSTimer scheduledTimerWithTimeInterval:userInterval
                                                  target:self
                                                selector:@selector(pulseActuator)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)pulseActuator {
    if (actuatorCreate && actuatorOpen && actuatorActuate && actuatorClose && targetDeviceID != 0) {
        void* act = actuatorCreate(targetDeviceID);
        if (act) {
            if (actuatorOpen(act) == 0) {
                actuatorActuate(act, userPattern, 0, userIntensity, 0.0f);
                actuatorClose(act);
            }
        }
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "--info") == 0 || strcmp(argv[i], "-info") == 0) {
                IOHIDManagerRef hidManager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDManagerOptionNone);
                if (hidManager) {
                    CFMutableDictionaryRef matchDict = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
                    int page = 0x01;  int usage = 0x02;
                    CFNumberRef pRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &page);
                    CFNumberRef uRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &usage);
                    CFDictionarySetValue(matchDict, CFSTR(kIOHIDDeviceUsagePageKey), pRef);
                    CFDictionarySetValue(matchDict, CFSTR(kIOHIDDeviceUsageKey), uRef);
                    IOHIDManagerSetDeviceMatching(hidManager, matchDict);
                    IOHIDManagerOpen(hidManager, kIOHIDManagerOptionNone);
                    
                    CFSetRef deviceSet = IOHIDManagerCopyDevices(hidManager);
                    if (deviceSet) {
                        CFIndex count = CFSetGetCount(deviceSet);
                        IOHIDDeviceRef *devices = malloc(sizeof(IOHIDDeviceRef) * count);
                        CFSetGetValues(deviceSet, (const void **)devices);
                        
                        printf("\n🌐 WebHID Parameter Identification Mapping:\n");
                        printf("==================================================\n");
                        for (CFIndex j = 0; j < count; j++) {
                            int32_t vID = getHIDIntProperty(devices[j], CFSTR(kIOHIDVendorIDKey));
                            int32_t pID = getHIDIntProperty(devices[j], CFSTR(kIOHIDProductIDKey));
                            int32_t uPage = getHIDIntProperty(devices[j], CFSTR(kIOHIDDeviceUsagePageKey));
                            int32_t uID = getHIDIntProperty(devices[j], CFSTR(kIOHIDDeviceUsageKey));
                            
                            printf("📋 Device [%ld]:\n", j + 1);
                            printf("  • vendorId  : 0x%04X  (%d)\n", vID, vID);
                            printf("  • productId : 0x%04X  (%d)\n", pID, pID);
                            printf("  • usagePage : 0x%04X  (%d)\n", uPage, uPage);
                            printf("  • usage     : 0x%04X  (%d)\n", uID, uID);
                            printf("--------------------------------------------------\n");
                            printf("💡 JavaScript WebHID Filtering Snippet:\n");
                            printf("   const devices = await navigator.hid.requestDevice({\n");
                            printf("     filters: [{ vendorId: 0x%04X, productId: 0x%04X }]\n", vID, pID);
                            // Corrected format structure below (removed extra args on closing lines)
                            printf("   });\n\n");
                        }
                        free(devices);
                        CFRelease(deviceSet);
                    }
                    CFRelease(pRef); CFRelease(uRef); CFRelease(matchDict); CFRelease(hidManager);
                }
                return 0;
            }
        }

        NSApplication *app = [NSApplication sharedApplication];
        HapticAppDelegate *delegate = [[HapticAppDelegate alloc] init];
        [app setDelegate:delegate];
        [app run];
    }
    return 0;
}
