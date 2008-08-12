/*
        
        File:			USBIntersil.mm
        Program:		KisMAC
		Author:			Michael Rossberg
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
	
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>

#include "USBJack.h"
#include "IntersilJack.h"
#include "RalinkJack.h"
#include "RT73Jack.h"
#include "RTL8187.h"

#define wlcDeviceGone   (int)0xe000404f
#define align64(a)      (((a)+63)&~63)

bool    _matchingDone;   //this is static so all instances of this class can see it!

//struct identStruct {
//    UInt16 vendor;
//    UInt16 device;
//};
//
//static struct identStruct devices[] = {
//    { 0x04bb, 0x0922}, //1 IOData AirPort WN-B11/USBS
//    { 0x07aa, 0x0012}, //2 Corega Wireless LAN USB Stick-11
//    { 0x09aa, 0x3642}, //3 Prism2.x 11Mbps WLAN USB Adapter
//    { 0x1668, 0x0408}, //4 Actiontec Prism2.5 11Mbps WLAN USB Adapter
//    { 0x1668, 0x0421}, //5 Actiontec Prism2.5 11Mbps WLAN USB Adapter
//    { 0x066b, 0x2212}, //6 Linksys WUSB11v2.5 11Mbps WLAN USB Adapter
//    { 0x066b, 0x2213}, //7 Linksys WUSB12v1.1 11Mbps WLAN USB Adapter
//    { 0x067c, 0x1022}, //8 Siemens SpeedStream 1022 11Mbps WLAN USB Adapter
//    { 0x049f, 0x0033}, //9 Compaq/Intel W100 PRO/Wireless 11Mbps multiport WLAN Adapter
//    { 0x0411, 0x0016}, //10 Melco WLI-USB-S11 11Mbps WLAN Adapter
//    { 0x08de, 0x7a01}, //11 PRISM25 IEEE 802.11 Mini USB Adapter
//    { 0x8086, 0x1111}, //12 Intel PRO/Wireless 2011B LAN USB Adapter
//    { 0x0d8e, 0x7a01}, //13 PRISM25 IEEE 802.11 Mini USB Adapter
//    { 0x045e, 0x006e}, //14 Microsoft MN510 Wireless USB Adapter
//    { 0x0967, 0x0204}, //15 Acer Warplink USB Adapter
//    { 0x0cde, 0x0002}, //16 Z-Com 725/726 Prism2.5 USB/USB Integrated
//    { 0x413c, 0x8100}, //17 Dell TrueMobile 1180 Wireless USB Adapter
//    { 0x0b3b, 0x1601}, //18 ALLNET 0193 11Mbps WLAN USB Adapter
//    { 0x0b3b, 0x1602}, //19 ZyXEL ZyAIR B200 Wireless USB Adapter
//    { 0x0baf, 0x00eb}, //20 USRobotics USR1120 Wireless USB Adapter
//    { 0x0411, 0x0027}, //21 Melco WLI-USB-KS11G 11Mbps WLAN Adapter
//    { 0x04f1, 0x3009}, //22 JVC MP-XP7250 Builtin USB WLAN Adapter
//    { 0x03f3, 0x0020}, //23 Adaptec AWN-8020 USB WLAN Adapter
//    { 0x0ace, 0x1201}, //24 ZyDAS ZD1201 Wireless USB Adapter
//    { 0x2821, 0x3300}, //25 ASUS-WL140 Wireless USB Adapter
//    { 0x2001, 0x3700}, //26 DWL-122 Wireless USB Adapter
//    { 0x0846, 0x4110}, //27 NetGear MA111
//    { 0x0772, 0x5731}, //28 MacSense WUA-700
//    { 0x124a, 0x4017}, //29 AirVast WN-220?
//    { 0x9016, 0x182d}, //30 Sitecom WL-022 - new version
//	{ 0x0707, 0xee04}, //31 SMC WUSB32
//	{ 0x1915, 0x2236}, //32 WUSB11 version 3.0
//    { 0x0cde, 0x0005}, //33 SAGEM F@st 1400W
//    //zydas
//    {0x0586, 0x3401}, //1 Zyxel duh
//    //ralink -- taken from the linux driver
//    {0x0411, 0x0066},	/* Melco */	
//    {0x0411, 0x0067},	/* Melco */		
//    {0x050d, 0x7050},	/* Belkin */		
//    {0x050d, 0x7051},	/* Belkin */		
//    {0x06f8, 0xe000},   /* GUILLEMOT */		
//    {0x0707, 0xee13},	/* SMC */		
//    {0x0b05, 0x1706},	/* ASUS */		
//    {0x0b05, 0x1707},	/* ASUS */		
//    {0x0db0, 0x6861},	/* MSI */		
//    {0x0db0, 0x6865},	/* MSI */		
//    {0x0db0, 0x6869},	/* MSI */		
//    {0x1044, 0x8001},	/* Gigabyte */		
//    {0x1044, 0x8007},	/* Gigabyte */		
//    {0x114b, 0x0110},	/* Spairon */		
//    {0x13b1, 0x000d},	/* Cisco Systems */	
//    {0x13b1, 0x0011},	/* Cisco Systems */	
//    {0x13b1, 0x001a},   /* Cisco Systems */	
//    {0x148f, 0x1706},	/* Ralink */		
//    {0x148f, 0x2570},	/* Ralink */		
//    {0x148f, 0x9020},	/* Ralink */		
//    {0x14b2, 0x3c02},	/* Conceptronic */	
//    {0x14f8, 0x2570},	/* Eminent */		
//    {0x2001, 0x3c00},	/* D-LINK */
//    {0x0411, 0x008b},	/* Nintendo */		
//    {0x5a57, 0x0260},   /* Zinwell */		
//    {0x0eb0, 0x9020},   /* Novatech */		
//	// ralink RT73
//    {0x13b1, 0x0020},   /* 1 WUSB54GC */
//    {0x07d1, 0x3c03},	/* 2 D-LINK */
//    {0x07d1, 0x3c04},	/* 3 D-LINK */
//    {0x050d, 0x705a},   /* 4 Belkin */
//    {0x148f, 0x2573},	/* 5 CNET CWD-854 */	
//    {0x14b2, 0x3c22},	/* 6 Conceptronic */
//	{0x0b05, 0x1723},   /* 7 ASUS WL-167G RALINK RT2500 */
//    {0x0df6, 0x90ac},   /* 8 Sitecom WL-172 */
//    {0x0df6, 0x9712},   /* 9 Sitecom WL-113 v.1.002*/
//    // RTL8187
//    {0x0bda, 0x8187},   /* 1 Realtek */
//    {0x0846, 0x6100},	/* 2 Netgear */
//    {0x0846, 0x6a00},	/* 3 Netgear */
//    {0x03f0, 0xca02},   /* 4 HP */
//    {0x0df6, 0x000d},	/* 5 Sitecom WL-168 */	
//    
//};

#define dbgOutPutBuf(a) NSLog( @"0x%.4x 0x%.4x 0x%.4x 0x%.4x%.4x", NSSwapLittleShortToHost(*((UInt16*)&(a) )), NSSwapLittleShortToHost(*((UInt16*)&(a)+1)), NSSwapLittleShortToHost(*((UInt16*)&(a)+2)), NSSwapLittleShortToHost(*((UInt16*)&(a)+3)), NSSwapLittleShortToHost(*((UInt16*)&(a)+4)) );              

#import <mach/mach_types.h>
#import <mach/mach_error.h>

#pragma mark -

USBJack::USBJack() {
    _isEnabled = false;
    _deviceInit = false;
    _devicePresent = false;
    _deviceMatched = false;

    _interface = NULL;
    _runLoopSource = NULL;
    _runLoop = NULL;
    _channel = 3;
    _notifyPort = NULL;
    
    _numDevices = -1;
    // Initialize internal frame queue
    initFrameQueue();
    
    pthread_mutex_init(&_wait_mutex, NULL);
    pthread_cond_init (&_wait_cond, NULL);

    // Start loop
    run();
    
    while (_runLoop==NULL)
        usleep(100);
}

USBJack::~USBJack() {
    // Stop
    stopRun();
    
    _interface = NULL;

    // Destroy frame queue
    destroyFrameQueue();
    
    pthread_mutex_destroy(&_wait_mutex);
    pthread_cond_destroy(&_wait_cond);
}

bool USBJack::loadPropertyList() {
    CFDataRef data;
    CFStringRef ref;
    CFStringRef plistFile = CFStringCreateWithCString(kCFAllocatorDefault, getPlistFile(), kCFStringEncodingASCII);
    CFURLRef url = CFBundleCopyResourceURL(CFBundleGetMainBundle(), plistFile, CFSTR("plist"), NULL);
    CFShow(url);
    CFURLCreateDataAndPropertiesFromResource(kCFAllocatorDefault, url, &data, nil, nil, nil);
    _vendorsPlist = CFPropertyListCreateFromXMLData(kCFAllocatorDefault, data, kCFPropertyListImmutable, &ref);
    if (CFDictionaryGetTypeID() != CFGetTypeID(_vendorsPlist))
        NSLog(@"Not a dict");
    CFRelease(data);    
    return false;
}
IOReturn USBJack::_init() {
    return kIOReturnError;  //this method MUST be overridden
}

bool USBJack::getChannel(UInt16* channel) {
    *channel = _channel;
    return true;   //this method MUST be overridden
}
bool USBJack::setChannel(UInt16 channel) {
    return false;   //this method MUST be overridden
}

bool USBJack::startCapture(UInt16 channel) {
    return false;   //this method MUST be overridden
}
bool USBJack::stopCapture() {
    return false;   //this method MUST be overridden
}

void USBJack::startMatching() {
    mach_port_t 		masterPort;
    CFMutableDictionaryRef 	matchingDict;
    kern_return_t		kr;
    
    // Checks if we already have matched
    if (_runLoopSource || _matchingDone)
        return;

    // Load property list
    loadPropertyList();
    
    _matchingDone = true;
    _deviceMatched = false;
    _numDevices = -1;
    
    // first create a master_port for my task
    kr = IOMasterPort(MACH_PORT_NULL, &masterPort);
    if (kr || !masterPort) {
        NSLog(@"ERR: Couldn't create a master IOKit Port(%08x)\n", kr);
    }
    
    // Set up the matching criteria for the devices we're interested in
    matchingDict = IOServiceMatching(kIOUSBDeviceClassName);	// Interested in instances of class IOUSBDevice and its subclasses
    if (!matchingDict) {
        NSLog(@"Can't create a USB matching dictionary\n");
        //mach_port_deallocate(mach_task_self(), masterPort);
        return;
    }
    
    // Create a notification port and add its run loop event source to our run loop
    // This is how async notifications get set up.
    _notifyPort = IONotificationPortCreate(masterPort);
    _runLoopSource = IONotificationPortGetRunLoopSource(_notifyPort);
    
    CFRunLoopAddSource(_runLoop, _runLoopSource, kCFRunLoopDefaultMode);
    
    // Retain additional references because we use this same dictionary with four calls to 
    // IOServiceAddMatchingNotification, each of which consumes one reference.
    matchingDict = (CFMutableDictionaryRef) CFRetain(matchingDict); 
    
    // Now set up two more notifications, one to be called when a bulk test device is first matched by I/O Kit, and the other to be
    // called when the device is terminated.
    kr = IOServiceAddMatchingNotification(_notifyPort,
                                          kIOFirstMatchNotification,
                                          matchingDict,
                                          _addDevice,
                                          this,
                                          &_deviceAddedIter);
    
    _addDevice(this, _deviceAddedIter);	// Iterate once to get already-present devices and
    // arm the notification
    
    kr = IOServiceAddMatchingNotification(  _notifyPort,
                                          kIOTerminatedNotification,
                                          matchingDict,
                                          _handleDeviceRemoval,
                                          this,
                                          &_deviceRemovedIter );
    
    _handleDeviceRemoval(this, _deviceRemovedIter); 	// Iterate once to arm the notification
    
    
    // Now done with the master_port
    masterPort = 0;
}

KFrame *USBJack::receiveFrame() {
    UInt16 len, channel;
    KFrame *ret = (KFrame *)&_frameBuffer;
    void *receivedFrame;
    
    if (!_devicePresent)
        return NULL;
    
    while (1) {
        receivedFrame = getFrameFromQueue(&len, &channel);
        if (receivedFrame) {
            if(!_massagePacket(receivedFrame, (void *)&_frameBuffer, len))
                continue;
            ret->ctrl.channel = channel;
            return ret;
        } else {
            return NULL;
        }
    }
}
bool USBJack::sendFrame(UInt8* data, int size) {
    // Override in subclasses
    return NO;
}

bool USBJack::getAllowedChannels(UInt16* channels) {
    return false;   //this method MUST be overridden
}


bool USBJack::devicePresent() {
    return _devicePresent;
}
bool USBJack::deviceMatched() {
    return _deviceMatched;
}

#pragma mark -

#pragma mark -

IOReturn USBJack::_reset() {
    return kIOReturnError;  //this method MUST be overridden
}

#pragma mark -

IOReturn USBJack::_sendFrame(UInt8* data, IOByteCount size) {
    UInt32      numBytes;
    IOReturn    kr;
    
    NSLog(@"_sendFrame");
    
    if (!_devicePresent) return kIOReturnError;
    
    if (_interface == NULL) {
        NSLog(@"USBJack::_sendFrame called with NULL interface this is prohibited!\n");
        return kIOReturnError;
    }
    
    _lockDevice();

    memcpy(&_outputBuffer, data, size);
    
    //not sure about this
    _outputBuffer.type =   NSSwapHostShortToLittle(_USB_TXFRM);
    
    numBytes =  align64(size);

    kr = (*_interface)->WritePipe(_interface, kOutPipe, &_outputBuffer, numBytes);
    
    _unlockDevice();
        
    return kr;
}

#pragma mark -

void  USBJack::_lockDevice() {
    pthread_mutex_lock(&_wait_mutex);
}
void  USBJack::_unlockDevice() {
    pthread_mutex_unlock(&_wait_mutex);
}
void USBJack::_interruptReceived(void *refCon, IOReturn result, int len) {
    USBJack             *me = (USBJack*) refCon;
    IOReturn                    kr;
    UInt32                      type;

//    NSLog(@"Interrupt Received %d", len);
    KFrame *frame;
    if (kIOReturnSuccess != result) {
        if (result == (IOReturn)0xe00002ed) {
            me->_devicePresent = false;
            //tell the receive function that we are gone
            me->insertFrameIntoQueue(NULL, 0, 0);
            return;
        } else {
            NSLog(@"error from async interruptReceived (%08x)\n", result);
            if (me->_devicePresent) goto readon;
        }
    }
    
    type = NSSwapLittleShortToHost(me->_receiveBuffer.type);
    if (_USB_ISRXFRM(type)) {
        // Specific driver method to convert driver packet data to KFrame
        // Return false if this is a bad packet
        
        frame = (KFrame*)&(me->_receiveBuffer.rxfrm);
//        NSLog(@"dataReceived %d", len);
        // Why do we needs to convert ?
//        frameDescriptor->status = NSSwapLittleShortToHost(frameDescriptor->status);
//        frameDescriptor->len = NSSwapLittleShortToHost(frameDescriptor->dataLen);

        // Set channel
//        frame->ctrl.channel = me->_channel;

        // TODO: And for other channels?
//        if (me->_channel > 14) 
//            return;

        /*
            * If the frame has an FCS error, is received on a MAC port other
            * than the monitor mode port, or is a message type other than
            * normal, we don't want it.
            */
/*        if (frameDescriptor->status & 0x1 ||
            (frameDescriptor->status & 0x700) != 0x700 ||
            frameDescriptor->status & 0xe000) {
            goto readon;
        }
  */      
        
        /*
            * Read in the packet data.  Read 8 extra bytes for IV + ICV if
            * applicable.
        */

        // Lock for copying frame
        me->insertFrameIntoQueue(frame, len, me->_channel);

    } else {
        switch (type) {
        case _USB_INFOFRM:
            /*if (action == ABORT)
                    goto exit;
            if (action == HANDLE)
                    _usbin_info(wlandev, usbin);*/
            break;
        case _USB_CMDRESP:
        case _USB_WRIDRESP:
        case _USB_RRIDRESP:
        case _USB_WMEMRESP:
        case _USB_RMEMRESP:
                pthread_mutex_lock(&me->_wait_mutex);
                memcpy(&me->_inputBuffer, &me->_receiveBuffer, len);
                pthread_cond_signal(&me->_wait_cond);
                pthread_mutex_unlock(&me->_wait_mutex);
                break;
        case _USB_BUFAVAIL:
                NSLog(@"Received BUFAVAIL packet, frmlen=%d\n", me->_receiveBuffer.bufavail.frmlen);
                break;
        case _USB_ERROR:
                NSLog(@"Received USB_ERROR packet, errortype=%d\n", me->_receiveBuffer.usberror.errortype);
                break;
    
        default:
                break;
        }
    }
    
readon:
    bzero(&me->_receiveBuffer, sizeof(me->_receiveBuffer));
    kr = (*me->_interface)->ReadPipeAsync((me->_interface), (me->kInPipe), &me->_receiveBuffer, sizeof(me->_receiveBuffer), (IOAsyncCallback1)_interruptReceived, refCon);
    if (kIOReturnSuccess != kr) {
        NSLog(@"unable to do async interrupt read (%08x). this means the card is stopped!\n", kr);
		// I haven't been able to reproduce the error that caused it to hit this point in the code again since adding the following lines
		// however, when it hit this point previously, the only solution was to kill and relaunch KisMAC, so at least this won't make anything worse
		NSLog(@"Attempting to re-initialise adapter...");
		if (me->_init() != kIOReturnSuccess) NSLog(@"USBJack::_interruptReceived: _init() failed\n");
    }
        
}
bool USBJack::_massagePacket(void *inBuf, void *outBuf, UInt16 len){
    return true;         //override if needed
}

# pragma mark -
# pragma mark Internal Packet Queue
# pragma mark -

int USBJack::initFrameQueue(void) {
    _frameRing = (struct __frameRing *)calloc(1, sizeof(struct __frameRing));
    return 0;
}
int USBJack::destroyFrameQueue(void) {
    free(_frameRing);
    return 0;
}
int USBJack::insertFrameIntoQueue(KFrame *f, UInt16 len, UInt16 channel) {
    struct __frameRingSlot *slot = &(_frameRing->slots[_frameRing->writeIdx]);
    _frameRing->received++;
    if (_frameRing->received % 1000 == 0)
        NSLog(@"Received %d", _frameRing->received);
    if (slot->state == FRAME_SLOT_USED) {
//        NSLog(@"Dropped packet, ring full");
        _frameRing->dropped++;
        if (_frameRing->dropped % 100 == 0)
            NSLog(@"Dropped %d", _frameRing->dropped);
        return 0;
    }
    memcpy(&(slot->frame), f, sizeof(KFrame));
    slot->len = len;
    slot->channel = channel;
    slot->state = FRAME_SLOT_USED;
    _frameRing->writeIdx = (_frameRing->writeIdx + 1) % RING_SLOT_NUM;
    return 0;
}
KFrame *USBJack::getFrameFromQueue(UInt16 *len, UInt16 *channel) {
    static KFrame f;
    struct __frameRingSlot *slot = &(_frameRing->slots[_frameRing->readIdx]);
    
//    NSLog(@"Slot %p readIdx %d", slot, _frameRing->readIdx);

    while (slot->state == FRAME_SLOT_FREE)
        usleep(100);
    
    memcpy(&f, &(slot->frame), sizeof(KFrame));
    (*len) = slot->len;
    (*channel) = slot->channel;
    slot->state = FRAME_SLOT_FREE;
    _frameRing->readIdx = (_frameRing->readIdx + 1) % RING_SLOT_NUM;
    return &f;
}

#pragma mark -

IOReturn USBJack::_configureAnchorDevice(IOUSBDeviceInterface197 **dev) {
    UInt8				numConf;
    IOReturn				kr;
    IOUSBConfigurationDescriptorPtr	confDesc;
    kr = (*dev)->GetNumberOfConfigurations(dev, &numConf);
    NSLog(@"Number of configs found: %d\n", numConf);
    if (!numConf)
        return kIOReturnError;
    
    // get the configuration descriptor for index 0
    kr = (*dev)->GetConfigurationDescriptorPtr(dev, 0, &confDesc);
    if (kr) {
        NSLog(@"\tunable to get config descriptor for index %d (err = %08x)\n", 0, kr);
        return kIOReturnError;
    }
    kr = (*dev)->SetConfiguration(dev, confDesc->bConfigurationValue);
    if (kr) {
        NSLog(@"\tunable to set configuration to value %d (err=%08x)\n", 0, kr);
            return kIOReturnError;
    }
    return kIOReturnSuccess;
}
IOReturn USBJack::_findInterfaces(IOUSBDeviceInterface197 **dev) {
    IOReturn			kr;
    IOUSBFindInterfaceRequest	request;
    io_iterator_t		iterator;
    io_service_t		usbInterface;
    IOCFPlugInInterface 	**plugInInterface = NULL;
    IOUSBInterfaceInterface220 	**intf = NULL;
    HRESULT 			res;
    SInt32 			score;
    UInt8			intfClass;
    UInt8			intfSubClass;
    UInt8			intfNumEndpoints;
    int				pipeRef;
    CFRunLoopSourceRef		runLoopSource;
    BOOL                        error;
    
    
    request.bInterfaceClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
    request.bAlternateSetting = kIOUSBFindInterfaceDontCare;
   
    kr = (*dev)->CreateInterfaceIterator(dev, &request, &iterator);
    
    while ((usbInterface = IOIteratorNext(iterator))) {
        NSLog(@"Interface found.\n");
       
        kr = IOCreatePlugInInterfaceForService(usbInterface, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);
        kr = IOObjectRelease(usbInterface);				// done with the usbInterface object now that I have the plugin
        if ((kIOReturnSuccess != kr) || !plugInInterface) {
            NSLog(@"unable to create a plugin (%08x)\n", kr);
            break;
        }
            
        // I have the interface plugin. I need the interface interface
        res = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID220), (void**) &intf);
        (*plugInInterface)->Release(plugInInterface);			// done with this
        if (res || !intf) {
            NSLog(@"couldn't create an IOUSBInterfaceInterface (%08x)\n", (int) res);
            break;
        }
        
        kr = (*intf)->GetInterfaceClass(intf, &intfClass);
        kr = (*intf)->GetInterfaceSubClass(intf, &intfSubClass);
        
        //NSLog(@"Interface class %d, subclass %d\n", intfClass, intfSubClass);
        
        // Now open the interface. This will cause the pipes to be instantiated that are 
        // associated with the endpoints defined in the interface descriptor.
        kr = (*intf)->USBInterfaceOpen(intf);
        if (kIOReturnSuccess != kr) {
            NSLog(@"unable to open interface (%08x)\n", kr);
            (void) (*intf)->Release(intf);
            break;
        }
        
    	kr = (*intf)->GetNumEndpoints(intf, &intfNumEndpoints);
        if (kIOReturnSuccess != kr) {
            NSLog(@"unable to get number of endpoints (%08x)\n", kr);
            (void) (*intf)->USBInterfaceClose(intf);
            (void) (*intf)->Release(intf);
            break;
        }
        
        if (intfNumEndpoints < 1) {
            NSLog(@"Error: Interface has %d endpoints. Needs at least one!!\n", intfNumEndpoints);
            (void) (*intf)->USBInterfaceClose(intf);
            (void) (*intf)->Release(intf);
            break;
        }
        
        for (pipeRef = 1; pipeRef <= intfNumEndpoints; pipeRef++)
        {
            IOReturn	kr2;
            UInt8	direction;
            UInt8	number;
            UInt8	transferType;
            UInt16	maxPacketSize;
            UInt8	interval;
            
            kr2 = (*intf)->GetPipeProperties(intf, pipeRef, &direction, &number, &transferType, &maxPacketSize, &interval);
            if (kIOReturnSuccess != kr) {
                NSLog(@"unable to get properties of pipe %d (%08x)\n", pipeRef, kr2);
                (void) (*intf)->USBInterfaceClose(intf);
                (void) (*intf)->Release(intf);
                break;
            } else {
                NSLog(@"%d %d", pipeRef, direction);
                error = false;
                if (direction == kUSBIn && transferType == kUSBBulk) kInPipe = pipeRef;
                else if (direction == kUSBOut && transferType == kUSBBulk) kOutPipe = pipeRef;
                else if (direction == kUSBIn && transferType  == kUSBInterrupt) kInterruptPipe = pipeRef;
                else NSLog(@"Found unknown interface, ignoring");
            
                if (error) {
                    NSLog(@"unable to properties of pipe %d are not as expected!\n", pipeRef);
                    (void) (*intf)->USBInterfaceClose(intf);
                    (void) (*intf)->Release(intf);
                    break;
                }
            }
        }
        
        // Just like with service matching notifications, we need to create an event source and add it 
        //  to our run loop in order to receive async completion notifications.
        kr = (*intf)->CreateInterfaceAsyncEventSource(intf, &runLoopSource);
        if (kIOReturnSuccess != kr) {
            NSLog(@"unable to create async event source (%08x)\n", kr);
            (void) (*intf)->USBInterfaceClose(intf);
            (void) (*intf)->Release(intf);
            break;
        }
        CFRunLoopAddSource(_runLoop, runLoopSource, kCFRunLoopDefaultMode);
        
        _interface = intf;
        
        NSLog(@"USBJack is now ready to start working.\n");
        
        //startUp Interrupt handling
        UInt32 numBytesRead = sizeof(_receiveBuffer); // leave one byte at the end for NUL termination
        bzero(&_receiveBuffer, numBytesRead);
        kr = (*intf)->ReadPipeAsync(intf, kInPipe, &_receiveBuffer, numBytesRead, (IOAsyncCallback1)_interruptReceived, this);
        
        if (kIOReturnSuccess != kr) {
            NSLog(@"unable to do async interrupt read (%08x)\n", kr);
            (void) (*intf)->USBInterfaceClose(intf);
            (void) (*intf)->Release(intf);
            break;
        }
        
        _devicePresent = true;
        
        if (_channel) {
            startCapture(_channel);
        }
        
        break;
    }
    
    return kr;
}
bool USBJack::_attachDevice() {
    kern_return_t		kr;
    IOUSBDeviceInterface197    **dev;
    
    if ((dev = _foundDevices[_numDevices--])) {
        
        // need to open the device in order to change its state
        kr = (*dev)->USBDeviceOpen(dev);
        if (kIOReturnSuccess != kr) {
            if (kr == kIOReturnExclusiveAccess) {
                NSLog(@"Device already in use.");
            }
            else {
                NSLog(@"unable to open device: %08x\n", kr);
            }
            (*dev)->Release(dev);
            return false;
        }
        
        kr = _configureAnchorDevice(dev);
        if (kIOReturnSuccess != kr) {
            NSLog(@"unable to configure device: %08x\n", kr);
            (*dev)->USBDeviceClose(dev);
            (*dev)->Release(dev);
            return false;
        }
        
        kr = _findInterfaces(dev);
        if (kIOReturnSuccess != kr) {
            NSLog(@"unable to find interfaces on device: %08x\n", kr);
            (*dev)->USBDeviceClose(dev);
            (*dev)->Release(dev);
            return false;
        }
        
        kr = (*dev)->USBDeviceClose(dev);
        kr = (*dev)->Release(dev);
    
    }
    return true;
}
void USBJack::_addDevice(void *refCon, io_iterator_t iterator) {
    kern_return_t		kr;
    io_service_t		usbDevice;
    IOCFPlugInInterface 	**plugInInterface=NULL;
    IOUSBDeviceInterface197    **dev=NULL;
    HRESULT 			res;
    SInt32 			score;
    
    UInt16			vendor;
    UInt16			product;
    UInt16			release;
    USBJack     *me = (USBJack*)refCon;

    
    while ((usbDevice = IOIteratorNext(iterator))) {
        //NSLog(@"USB Device added.\n");
       
        kr = IOCreatePlugInInterfaceForService(usbDevice, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);
        if ((kIOReturnSuccess != kr) || !plugInInterface) {
            kr = IOObjectRelease(usbDevice);				// done with the device object now that I have the plugin
            NSLog(@"unable to create a plugin (%08x)\n", kr);
            continue;
        }
        kr = IOObjectRelease(usbDevice);				// done with the device object now that I have the plugin
            
        // I have the device plugin, I need the device interface
        res = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID197), (void**)&dev);
        (*plugInInterface)->Release(plugInInterface);			// done with this
        if (res || !dev) {
            NSLog(@"couldn't create a device interface (%08x)\n", (int) res);
            continue;
        }
        // technically should check these kr values
        kr = (*dev)->GetDeviceVendor(dev, &vendor);
        kr = (*dev)->GetDeviceProduct(dev, &product);
        kr = (*dev)->GetDeviceReleaseNumber(dev, &release);
        
        CFTypeRef *keys, *values, n;
        CFIndex count, i;
        UInt16 productId, vendorId;
        CFIndex length;
        char *modelStr;
        
        count = CFDictionaryGetCount( (CFDictionaryRef) (me->_vendorsPlist) );
        keys = (const void **) malloc(count * sizeof(CFTypeRef));
        values = (const void **) malloc(count * sizeof(CFTypeRef));
        
        CFDictionaryGetKeysAndValues( (CFDictionaryRef) (me->_vendorsPlist) , keys, values);
        NSLog(@"---");
        for (i=0;i<count;i++) {
            n = CFDictionaryGetValue((CFDictionaryRef)values[i], CFSTR("idProduct"));
            CFNumberGetValue((CFNumberRef)n, kCFNumberSInt16Type, &productId);
            n = CFDictionaryGetValue((CFDictionaryRef)values[i], CFSTR("idVendor"));
            CFNumberGetValue((CFNumberRef)n, kCFNumberSInt16Type, &vendorId);
            NSLog(@"vendor %d vendorId %d product %d productId %d", vendor, vendorId, product, productId);
            if ((vendor == vendorId) && (product == productId)) {
                length = CFStringGetMaximumSizeForEncoding(CFStringGetLength((CFStringRef)keys[i]), kCFStringEncodingASCII) + 1;
                modelStr = (char *)malloc(length);
                CFStringGetCString((CFStringRef)keys[i], modelStr, length, kCFStringEncodingASCII);
                NSLog(@"USB Device found (%s)", modelStr);
                free(modelStr);
                me->_foundDevices[++me->_numDevices] = dev;
                me->_deviceMatched = true;
                break;
            }
        }
        
        free(keys);
        free(values);
        
        if (!me->_deviceMatched)
            (*dev)->Release(dev);
    }
}
void USBJack::_handleDeviceRemoval(void *refCon, io_iterator_t iterator) {
    kern_return_t	kr;
    io_service_t	obj;
    int                 count = 0;
    USBJack     *me = (USBJack*)refCon;
    
    while ((obj = IOIteratorNext(iterator)) != nil) {
        //count++;
        //we need to not release devices that don't belong to us!?
        //NSLog(@"Device removed.\n");
        kr = IOObjectRelease(obj);
    }
    
    if (count) {
        me->_interface = NULL;
        me->stopRun();
    }
}

#pragma mark -
#pragma mark Loop Functions
#pragma mark -

bool USBJack::stopRun() {
    // No loop running
    if (_runLoop == NULL)
        return false;

    // Disable keeping
    _stayUp = false;
    
    // If we have to notify, do that
    if (_notifyPort) {
        IONotificationPortDestroy(_notifyPort);
        _notifyPort = NULL;
    }
    
    // Stop loop
    if (_runLoop)
        CFRunLoopStop(_runLoop);
    _runLoop = NULL;
    
    return true;
}
void USBJack::_runCFRunLoop(USBJack* me) {
    me->_runLoop = CFRunLoopGetCurrent();
    
    // Check if we need to keep loop running
    while(me->_stayUp) {
        CFRunLoopRun();
    };
    
    // Stop
    if (me->_runLoop) {
        if (me->_runLoopSource)
            CFRunLoopRemoveSource(me->_runLoop, me->_runLoopSource, kCFRunLoopDefaultMode);
        CFRunLoopStop(me->_runLoop);
        me->_runLoop = NULL;
    }
} 
bool USBJack::run() {
    pthread_t pt;
    
    _stayUp = true;
    
    if (_runLoop==NULL) {
        pthread_create(&pt, NULL, (void*(*)(void*))_runCFRunLoop, this);
    }
    
    return true;
}

