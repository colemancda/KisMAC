/*
        
        File:			WaveHelper.m
        Program:		KisMAC
		Author:			Michael Rossberg, Michael Thole
						mick@binaervarianz.de
		Description:	KisMAC is a wireless stumbler for MacOS X.
                
        This file is part of KisMAC.

    KisMAC is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    KisMAC is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with KisMAC; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#import "WaveHelper.h"
#import <BIGeneric/BIGeneric.h>
#import "../WaveDrivers/WaveDriverAirport.h"
#import "../WaveDrivers/WaveDriverViha.h"
#import "../WaveDrivers/WaveDriver.h"

#include <openssl/md5.h>
#include <unistd.h>
#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/IOKitLib.h>
#import <Security/Security.h>
#import <CoreServices/CoreServices.h>

#import "WaveContainer.h"
#import "GPSController.h"
#import "GPSInfoController.h"
#import "ImportController.h"

/*
 * generate 104-bit key based on the supplied string
 */
inline void WirelessCryptMD5(char const *str, unsigned char *key) {
    int i, j;
    u_char md5_buf[64];
    MD5_CTX ctx;

    j = 0;
    for(i = 0; i < 64; i++) {
        if(str[j] == 0) j = 0;
        md5_buf[i] = str[j++];
    }

    MD5_Init(&ctx);
    MD5_Update(&ctx, md5_buf, 64);
    MD5_Final(md5_buf, &ctx);
    
    memcpy(key, md5_buf, 13);
}

@implementation WaveHelper

static NSDictionary *_vendors = nil;	//Dictionary
static BISpeechController *_speechController = nil;

// Global dictionary to keeps drivers
static NSMutableDictionary* _waveDrivers = Nil;

static NSWindow* aMainWindow;
static GPSController* aGPSController;
static MapView *_mapView;
static NSMutableDictionary *_probes = Nil;
static Trace *_trace;
static ImportController *_im;
static ScanController *_scanController;
static GPSInfoController *_gc;

// Converts a byte count to a human readable string
+ (NSString *) bytesToString:(float) bytes {
    if (bytes > 700000000)
        return [NSString stringWithFormat:@"%1.2fGiB",bytes/1024/1024/1024];
    else if (bytes > 700000)
        return [NSString stringWithFormat:@"%1.2fMiB",bytes/1024/1024];
    else if (bytes > 700)
        return [NSString stringWithFormat:@"%1.2fKiB",bytes/1024];
    else
        return [NSString stringWithFormat:@"%.fB",bytes];
}


//converts a string to an url encoded string
+ (NSString*) urlEncodeString:(NSString*)string {
    const char *input;
    char *output;
    int i, j, l, h;
    char x[3];
    NSString *outstring;
    
    input = [string UTF8String];
    l = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    j = 0;
    
    output = malloc(l*3);
    
    for (i=0; i<l; i++) {
        if (input[i] == ' ') output[j++] = '+';
        else if (input[i] == '.' || input[i] == '-' || input[i] == '_' || input[i] == '*') output[j++] = input[i];
        else if(input[i] >= 'a' && input[i] <= 'z') output[j++] = input[i];
        else if(input[i] >= 'A' && input[i] <= 'Z') output[j++] = input[i];
        else if(input[i] >= '0' && input[i] <= '9') output[j++] = input[i];
        else {
            h = input[i];
            sprintf(x, "%.2x", h);
            output[j++] = '%';
            output[j++] = x[0];
            output[j++] = x[1];            
        }
    }
    
    outstring = [NSString stringWithCString:output length:j];
    
    free(output);
    
    return outstring;
}

#pragma mark -
#pragma mark MAC Utilities
#pragma mark -

// Encode a binary string into form XX:XX:XX.....
+ (NSString*) hexEncode:(UInt8*)data length:(int)len {
    NSParameterAssert(len > 0);
	NSParameterAssert(data);
	int i, j;
	
	NSMutableString *ms = [NSMutableString stringWithFormat:@"%.2X", data[0]];
    
	for (i = 1; i < len; i++) {
        j = data[i];
        [ms appendFormat:@":%.2X", j];
    }
	return ms;
}

+ (NSString*) macToString:(UInt8*)m {
    if (!m)
        return nil;
    return [NSString stringWithFormat:@"%.2X:%.2X:%.2X:%.2X:%.2X:%.2X", m[0], m[1], m[2], m[3], m[4], m[5], m[6]];
}

// Returns the vendor for a specific MAC-Address
+ (NSString *)vendorForMAC:(NSString*)MAC {
    NSString *aVendor;
    
    // The dictionary is cached for speed, but it needs to be loaded the first time
    if (_vendors == Nil) { 
        _vendors = [[NSDictionary dictionaryWithContentsOfFile:[[[NSBundle bundleForClass:[WaveHelper class]] resourcePath] stringByAppendingString:@"/vendor.db"]] retain];
		if (!_vendors) {
			NSLog(@"No vendors Database found!");
			return @"error";
		}
    }
	
    // Do we have a valid MAC?
    if ((MAC == nil) || ([MAC length] < 11))
        return @"";
    
    // See if we can find a most matching dictionary entry
    aVendor = [_vendors objectForKey:MAC];
    if (aVendor == nil) {
        aVendor = [_vendors objectForKey:[MAC substringToIndex:11]];
        if (aVendor == nil) {
            aVendor = [_vendors objectForKey:[MAC substringToIndex:8]];
            if (aVendor == nil) {
                aVendor = [_vendors objectForKey:[MAC substringToIndex:5]];
                if (aVendor == nil) {
                    return @"unknown";                    
                } 
            }
        }
    }
    return aVendor;
}

#pragma mark -

//tries to speak something. if it does not work => put it to the queue
+ (void)speakSentence:(const char*)cSentence withVoice:(int)voice {
    if (!_speechController) _speechController = [[BISpeechController alloc] init];
    [_speechController speakSentence:cSentence withVoice:voice];
}

#pragma mark -
#pragma mark Channel utility functions
#pragma mark -

+ (int)chan2freq:(int)channel {
    if (channel == 14)
        return 2484;
    if (channel >= 1 && channel <= 13)
        return 2407 + channel * 5;
	if (channel < 200)
        return 5000 + channel * 5;
    return 0;
}
+ (int)freq2chan:(int)frequency {
    if (frequency == 2484)
        return 14;
    if (frequency < 2484 && frequency > 2411 && ((frequency - 2407) % 5 == 0))
        return (frequency - 2407) / 5;
	if (frequency >= 5000 && frequency < 5900 && (frequency % 5) == 0)
        return (frequency - 5000) / 5;
    return 0;
}

#pragma mark -
#pragma mark Driver handling
#pragma mark -

+ (bool)isServiceAvailable:(char*)service {
    mach_port_t masterPort;
    io_iterator_t iterator;
    io_object_t sdev;
 
    if (IOMasterPort(MACH_PORT_NULL, &masterPort) != KERN_SUCCESS) {
        return NO; // REV/FIX: throw.
    }
        
    if (IORegistryCreateIterator(masterPort, kIOServicePlane, kIORegistryIterateRecursively, &iterator) == KERN_SUCCESS) {
        while ((sdev = IOIteratorNext(iterator)))
            if (IOObjectConformsTo(sdev, service)) {
                IOObjectRelease (iterator);
                return YES;
            }
        IOObjectRelease(iterator);
    }
    
    return NO;
}

//tells us whether a driver is in the RAM
+ (bool)isDriverLoaded:(int)driverID {
    switch(driverID) {
    case 1:
        if (![self isServiceAvailable:"WLanDriver"]) return NO;
        else return YES;
    case 2:
        if (![self isServiceAvailable:"MACJackDriver"]) return NO;
        else return YES;
    case 3:
        if (![self isServiceAvailable:"AiroJackDriver"]) return NO;
        else return YES;
    case 4:
        if ([self isServiceAvailable:"AirPortDriver"] || [self isServiceAvailable:"AirPortPCI"] ||
            [self isServiceAvailable:"AirPortPCI_MM"] || [self isServiceAvailable:"AirPort_Brcm43xx"]  ||
            [WaveHelper isServiceAvailable:"AirPort_Athr5424"] || [self isServiceAvailable:"AirPort_Athr5424ab"]) return YES;
        else return NO;
    default:
        return NO;
    }
}

+ (bool)unloadAllDrivers {
    id key;
    WaveDriver *w;
    NSEnumerator *e;
    
    if (!_waveDrivers) return YES;
    
    e = [_waveDrivers keyEnumerator];
    
    while ((key = [e nextObject])) {
        w = [_waveDrivers objectForKey:key];
        [_waveDrivers removeObjectForKey:key];
        [w unloadBackend];
        [w release];
        w = Nil;
    }
    
    return YES;
}

//placeholder for later
+ (bool)loadDrivers {
    NSUserDefaults *d;
    WaveDriver *w;
    NSArray *a;
    NSDictionary *driverProps;
    NSString *name;
    NSString *interfaceName;
    Class driver;
    unsigned int i, j;
    NSString *airportName;
    
    //if our dictionary does not exist then create it.
    if (!_waveDrivers) {
        _waveDrivers = [NSMutableDictionary dictionary];
        [_waveDrivers retain];
    }
    
    d = [NSUserDefaults standardUserDefaults];
    a = [d objectForKey:@"ActiveDrivers"];
    
    //see if all of the drivers mentioned in our prefs are loaded
    for (i = 0; i < [a count]; i++) {
        driverProps = [a objectAtIndex:i];
        name = [driverProps objectForKey:@"deviceName"];
        
        //the driver does not exist. go for it
        if (![_waveDrivers objectForKey:name]) {
        
            //ugly hack but it works, this makes sure that the airport card is used only once
            //prefers the viha driver
            interfaceName = [driverProps objectForKey:@"driverID"];
            if ([interfaceName isEqualToString:@"WaveDriverAirport"]) {
                if ([_waveDrivers objectForKey:[WaveDriverViha deviceName]]) continue;
            }
            if ([interfaceName isEqualToString:@"WaveDriverViha"]) {
                airportName = [WaveDriverAirport deviceName];
                if ([_waveDrivers objectForKey:airportName]) {
                    w = [_waveDrivers objectForKey:airportName];
                    [_waveDrivers removeObjectForKey:airportName];
                    [w unloadBackend];
                    [w release];
                    w = Nil;
                }
            }
            
            // Get the class for driver
            driver = NSClassFromString(interfaceName);
            
            // Call driver Class method "loadBackend"
            if (![driver loadBackend]) {
                return NO;
            }
            
            //create an interface
            for (j = 0; j < 10; j++) {
                w = [[driver alloc] init];
                if (w) {
                    break;
                }
                [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.4]];
            }
            
            if (w) {
                [w setConfiguration: driverProps];
                [_waveDrivers setObject:w forKey:name];
            } else {
                NSRunCriticalAlertPanel(NSLocalizedString(@"Could not instantiate Driver.", "Driver init failed"),
                [NSString stringWithFormat: NSLocalizedString (@"Instantiation Failure Description", @"LONG description of what might have gone wrong"),
                name],
                OK, Nil, Nil);
            
                NSLog(@"Error could not instantiate driver %@", interfaceName);
                return NO;
            }
        }
    }
    
    //now make sure any drivers that have been removed from the list are gone
    NSEnumerator *e = [_waveDrivers objectEnumerator];
   
    while((w = [e nextObject]))
    {
        if(![a containsObject: [w configuration]])
        {
            [_waveDrivers removeObjectForKey: [w deviceName]];
            
        }           
    }//end 

    return YES;
}

+ (NSArray*) getWaveDrivers {
    if (!_waveDrivers) {
        _waveDrivers = [NSMutableDictionary dictionary];
        [_waveDrivers retain];
    }
    
    return [_waveDrivers allValues];
}

+ (WaveDriver*) injectionDriver {
    NSEnumerator *e;
    NSString *k;
    NSDictionary *d;
    
    e = [_waveDrivers keyEnumerator];
    while ((k = [e nextObject])) {
        d = [[_waveDrivers objectForKey:k] configuration];
        if ([[d objectForKey:@"injectionDevice"] intValue]) return [_waveDrivers objectForKey:k];
    }
    
    return nil;
}

+ (WaveDriver*) driverWithName:(NSString*) s {
    return [_waveDrivers objectForKey:s];
}

#pragma mark -

+ (NSWindow*) mainWindow {
    return aMainWindow;
}
+ (void) setMainWindow:(NSWindow*)mw {
    aMainWindow = mw;
}

+ (ScanController*) scanController {
    return _scanController;
}
+ (void) setScanController:(ScanController*)scanController {
    _scanController=scanController;
}

+ (GPSInfoController*) GPSInfoController {
	return _gc;
}
+ (void) setGPSInfoController:(GPSInfoController*)GPSController {
    _gc=GPSController;
}

+ (GPSController*) gpsController {
    return aGPSController;
}

+ (void) initGPSControllerWithDevice:(NSString*)device {
    if (!aGPSController) 
        aGPSController = [[GPSController alloc] init];
    [aGPSController startForDevice:device];
}

+ (MapView*) mapView {
    return _mapView;
}
+ (void) setMapView:(MapView*)mv {
    _mapView = mv;
}

+ (Trace*) trace {
    return _trace;
}
+ (void) setTrace:(Trace*)trace {
    _trace = trace;
}

+ (NSColor*)intToColor:(NSNumber*)c {
    float r, g, b, a;    
    int i = [c intValue];

    a =  (i >> 24) & 0xFF;
    r =  (i >> 16) & 0xFF;
    g =  (i >> 8 ) & 0xFF;
    b =  (i      ) & 0xFF;
    
    return [NSColor colorWithCalibratedRed:r/255 green:g/255 blue:b/255 alpha:a/255];
}
+ (NSNumber*)colorToInt:(NSColor*)c {
    unsigned int i;
    float a, r,g, b;
    
    a = [c alphaComponent] * 255;
    r = [c redComponent]   * 255;
    g = [c greenComponent] * 255;
    b = [c blueComponent]  * 255;
    
    i = ((unsigned int)floor(a) << 24) | ((unsigned int)floor(r)<< 16) | ((unsigned int)floor(g) << 8) | (unsigned int)(b);
    return [NSNumber numberWithInt:i];
}

+ (ImportController*) importController {
    return _im;
}
+ (void) setImportController:(ImportController*)im {
    _im = im;
}

+ (NSMutableArray*) getProbeArrayForID:(char*)ident {
    NSMutableArray *ar;
    NSString *idstr;
    if (!_probes) _probes = [[NSMutableDictionary dictionary] retain];
    idstr = [NSString stringWithFormat:@"%.2X:%.2X:%.2X:%.2X:%.2X:%.2X", ident[0], ident[1], ident[2], ident[3], ident[4], ident[5]];
    ar = [_probes objectForKey:idstr];
    if (!ar) {
        ar = [NSMutableArray array];
        [ar addObject:[NSDate date]];
        [ar addObject:[NSNumber numberWithInt:0]];
        [_probes setObject:ar forKey:idstr];
    }
    return ar;
}

+ (bool)runScript:(NSString*)script {
    return [self runScript:script withArguments:Nil];
}
+ (bool)runScript:(NSString*)script withArguments:(NSArray*)args {
    //int perm;
    bool ret;
    //NSTask *t;
    NSString* s = [NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], script];
    /*
    perm = [[[[NSFileManager defaultManager] fileAttributesAtPath:s traverseLink:NO] objectForKey:NSFilePosixPermissions] intValue];
    if (perm & 04000) {
        t = [NSTask launchedTaskWithLaunchPath:s arguments:args ? args : [NSArray array]];
        if (!t) {
            NSLog(@"WARNING!!! User is not a member of admin group for: %@", s);
            NSRunCriticalAlertPanel(NSLocalizedString(@"Execution failure.", "Execution failure title"),
                NSLocalizedString(@"Execution failure description", "LONG Description of execution failure. No root privileges?!"),
                //@"KisMAC could not execute an internal shell script. This is most likely since you have no root privileges."
                OK ,Nil ,Nil);
            return NO;
        }
        return YES;
    } else { */
        ret = [[BLAuthentication sharedInstance] executeCommand:s withArgs:args];
        if (!ret) NSLog(@"WARNING!!! User canceled password dialog for: %@", s);
        return ret;
    //}
}

+ (void)secureRelease:(id*)object {
    id rel = *object;
    *object = Nil;
    [rel release];
}
+ (void)secureReplace:(id*)oldObject withObject:(id)newObject {
    id rel = *oldObject;
    *oldObject = [newObject retain];
    [rel release];
}

+ (void)addDictionary:(NSDictionary*)s toDictionary:(NSMutableDictionary*)d {
    NSEnumerator* e = [s keyEnumerator];
    id key;
    
    while ((key = [e nextObject]) != nil) {
        [d setObject:[s objectForKey:key] forKey:key];
    }
}

+ (int)showCouldNotInstaniciateDialog:(NSString*)driverName {
    NSString *warning = [NSString stringWithFormat: NSLocalizedString(@"Could not instanciate Driver description", "LONG description"), driverName];
    /*@"KisMAC has been able to load the driver (%@). Reasons for this failure could be:\n\n"
        "\t1. You selecteted the wrong driver.\n"
        "\t2. You did not insert your PCMCIA card (only if you selected such a driver).\n"
        "\t3. Your kernel extensions screwed up. In this case simply reboot.\n"
        "\t4. You are using a 3rd party card and you are having another driver for the card installed, which could not be unloaded by KisMAC."
        "If you have the sourceforge wireless driver, please install the patch, provided with KisMAC.\n"*/
        
    return NSRunCriticalAlertPanel(
        NSLocalizedString(@"Could not instaniciate Driver.", "Error title"), 
        warning, 
        NSLocalizedString(@"Retry", "Retry button"),
        NSLocalizedString(@"Abort", "Abort button"),
        Nil);
}

#pragma mark -
#pragma mark KEYCHAIN FUNCTIONS
#pragma mark -
	
//Call SecKeychainAddGenericPassword to add a new password to the keychain:
+ (bool) storePassword:(NSString*)password forAccount:(NSString*)account {
    OSStatus status;
    
    if (![self changePasswordForAccount:account toPassword:password]) {    
        status = SecKeychainAddGenericPassword (
            NULL,                   // default keychain
            16,                     // length of service name
            "KisMACWebService",     // service name
            [account lengthOfBytesUsingEncoding:NSUTF8StringEncoding],// length of account name
            [account UTF8String],      // account name
            [password lengthOfBytesUsingEncoding:NSUTF8StringEncoding],// length of password
            [password UTF8String],     // pointer to password data
            NULL                    // the item reference
        );

        return (status == noErr);
    } 
    
    return YES;
}

	
//Call SecKeychainFindGenericPassword to get a password from the keychain:
+ (NSString*) getPasswordForAccount:(NSString*)account {
    OSStatus status ;
    SecKeychainItemRef itemRef;
    UInt32 myPasswordLength = 0;
    void *passwordData = nil;
    NSString *pwd;
    
    status = SecKeychainFindGenericPassword (
        NULL,                       // default keychain
        16,                         // length of service name
        "KisMACWebService",         // service name
        [account lengthOfBytesUsingEncoding:NSUTF8StringEncoding],    // length of account name
        [account UTF8String],          // account name
        &myPasswordLength,          // length of password
        &passwordData,              // pointer to password data
        &itemRef                    // the item reference
    );


    if (status != noErr) return nil;
    
    pwd = [NSString stringWithCString:passwordData length:myPasswordLength];
    
    status = SecKeychainItemFreeContent (
         NULL,           //No attribute data to release
         passwordData    //Release data buffer allocated by SecKeychainFindGenericPassword
    );
    
    if (itemRef) CFRelease(itemRef);

    return pwd;
 }

+ (bool)deletePasswordForAccount:(NSString*)account {
    OSStatus status;
    SecKeychainItemRef itemRef;

    status = SecKeychainFindGenericPassword (
        NULL,                       // default keychain
        16,                         // length of service name
        "KisMACWebService",         // service name
        [account lengthOfBytesUsingEncoding:NSUTF8StringEncoding],    // length of account name
        [account UTF8String],          // account name
        NULL,                       // length of password
        NULL,                       // pointer to password data
        &itemRef                    // the item reference
    );

    if (status != noErr) return NO;

    status = SecKeychainItemDelete(itemRef);

    if (itemRef) CFRelease(itemRef);

    return (status == noErr);
}
	
//Call SecKeychainItemModifyAttributesAndData to change the password for // an item already in the keychain:
+ (bool)changePasswordForAccount:(NSString*)account toPassword:(NSString*)password {
    OSStatus status;
    SecKeychainItemRef itemRef;

    status = SecKeychainFindGenericPassword (
        NULL,                       // default keychain
        16,                         // length of service name
        "KisMACWebService",         // service name
        [account lengthOfBytesUsingEncoding:NSUTF8StringEncoding],    // length of account name
        [account UTF8String],          // account name
        NULL,                       // length of password
        NULL,                       // pointer to password data
        &itemRef                    // the item reference
    );

    if (status != noErr) return NO;

    status = SecKeychainItemModifyAttributesAndData (
        itemRef,                    // the item reference
        NULL,                       // no change to attributes
        [password lengthOfBytesUsingEncoding:NSUTF8StringEncoding],   // length of password
        (void*)[password UTF8String]   // pointer to password data
    );

    if (itemRef) CFRelease(itemRef);

    return (status == noErr);
}

#pragma mark -
#pragma mark Altivec detection
#pragma mark -

+ (BOOL)isAltiVecAvailable {
    long cpuAttributes;
    BOOL hasAltiVec = NO;
    
    OSErr err = Gestalt( gestaltPowerPCProcessorFeatures, &cpuAttributes );

    if (noErr == err)
        hasAltiVec = ( 1 << gestaltPowerPCHasVectorInstructions) & cpuAttributes;

    return hasAltiVec;
}

#pragma mark -

+ (NSString*)frameControlToString:(UInt16)fc {
    NSString *typeStr;
    NSString *subtypeStr;
    UInt16 type =    (fc & IEEE80211_TYPE_MASK);
    UInt16 subtype = (fc & IEEE80211_SUBTYPE_MASK);
	typeStr = @"UNKNOWN";
	subtypeStr = @"UNKNOWN";
    switch (type) {
        case IEEE80211_TYPE_MGT:
            typeStr = @"Management";
            switch (subtype) {
                case IEEE80211_SUBTYPE_ASSOC_REQ:
                    subtypeStr = @"Association Request";
                    break;
                case IEEE80211_SUBTYPE_ASSOC_RESP:
                    subtypeStr = @"Association Response";
                    break;
                case IEEE80211_SUBTYPE_REASSOC_REQ:
                    subtypeStr = @"Reassociation Request";
                    break;
                case IEEE80211_SUBTYPE_REASSOC_RESP:
                    subtypeStr = @"Reassociation Response";
                    break;
                case IEEE80211_SUBTYPE_PROBE_REQ:
                    subtypeStr = @"Probe Request";
                    break;
                case IEEE80211_SUBTYPE_PROBE_RESP:
                    subtypeStr = @"Probe Response";
                    break;
                case IEEE80211_SUBTYPE_BEACON:
                    subtypeStr = @"Beacon";
                    break;
                case IEEE80211_SUBTYPE_ATIM:
                    subtypeStr = @"Atim";
                    break;
                case IEEE80211_SUBTYPE_DISASSOC:
                    subtypeStr = @"Dissassociation";
                    break;
                case IEEE80211_SUBTYPE_AUTH:
                    subtypeStr = @"Authentication";
                    break;
                case IEEE80211_SUBTYPE_DEAUTH:
                    subtypeStr = @"Deauthentication";
                    break;
                case IEEE80211_SUBTYPE_ACTION:
                    subtypeStr = @"Action";
                    break;                    
            }
            break;
        case IEEE80211_TYPE_CTL:
            typeStr = @"Control";
            switch (subtype) {
                case IEEE80211_SUBTYPE_PS_POLL:
                    subtypeStr = @"PS Poll";
                    break;
                case IEEE80211_SUBTYPE_RTS:
                    subtypeStr = @"RTS";
                    break;
                case IEEE80211_SUBTYPE_CTS:
                    subtypeStr = @"CTS";
                    break;
                case IEEE80211_SUBTYPE_ACK:
                    subtypeStr = @"ACK";
                    break;
                case IEEE80211_SUBTYPE_CF_END:
                    subtypeStr = @"CF END";
                    break;
                case IEEE80211_SUBTYPE_CF_END_ACK:
                    subtypeStr = @"CF END ACK";
                    break;                    
            }
            break;
        case IEEE80211_TYPE_DATA:
            typeStr = @"Data";
            switch (subtype) {
                case IEEE80211_SUBTYPE_DATA:
                    subtypeStr = @"Data";
                    break;
                case IEEE80211_SUBTYPE_DATA_CFACK:
                    subtypeStr = @"Data CF ACK";
                    break;
                case IEEE80211_SUBTYPE_DATA_CFPOLL:
                    subtypeStr = @"Data CF Poll";
                    break;
                case IEEE80211_SUBTYPE_DATA_CFACKPOLL:
                    subtypeStr = @"Data CF ACK Poll";
                    break;
                case IEEE80211_SUBTYPE_NULLFUNC:
                    subtypeStr = @"Null Function";
                    break;
                case IEEE80211_SUBTYPE_CFACK:
                    subtypeStr = @"CF ACK";
                    break;
                case IEEE80211_SUBTYPE_CFPOLL:
                    subtypeStr = @"CF POLL";
                    break;
                case IEEE80211_SUBTYPE_CFACKPOLL:
                    subtypeStr = @"CF ACK POLL";
                    break;
                case IEEE80211_SUBTYPE_QOS_DATA:
                    subtypeStr = @"QOS Data";
                    break;                    
            }
            break;
    }
    return [NSString stringWithFormat:@"%@ %@", typeStr, subtypeStr];
}
+ (void)dumpKFrame:(KFrame *)f {
    UInt32 size = f->ctrl.len;
    UInt8 *data = f->data;
    NSLog(@"--FRAME LENGTH %d--", size);
    int idx = 0;
    int i,j;
	for (i=0;i<size;i=i+8) {
        fprintf(stderr, "0x%.4x ", i);
        for (j=0;j<8;j++) {
            if (idx < size)
                fprintf(stderr, "%.2x ", data[idx]);
            else
                fprintf(stderr, "   ");
            idx += 1;
        }
        fprintf(stderr, "\n");
    }
}
@end
