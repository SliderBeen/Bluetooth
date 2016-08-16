//
//  BraceletTool.m
//  手环
//
//  Created by wist on 16/7/26.
//  Copyright © 2016年 rg. All rights reserved.
//

#import "BraceletTool.h"
#import <CoreBluetooth/CoreBluetooth.h>

NSString *const sUUID = @"687BB71E-D6FF-3CC1-4EE8-BD336E724F34";

@interface BraceletTool ()<CBCentralManagerDelegate, CBPeripheralDelegate>

@property (strong, nonatomic ) NSMutableArray *nDevices;
@property (strong, nonatomic) NSMutableArray *nServices;
@property (strong, nonatomic) NSMutableArray *nCharacteristics;
@property (strong, nonatomic) CBCharacteristic *writeCharacteristic;
@property (strong, nonatomic) CBCentralManager *manager;
@property (strong, nonatomic) CBPeripheral *peripheral;
@property (assign, nonatomic) BOOL isConnected;
@property (assign, nonatomic) BOOL isLocked;

@end

@implementation BraceletTool

#pragma mark - 懒加载
- (NSMutableArray *)nDevices
{
    if (!_nDevices) {
        _nDevices = [NSMutableArray array];
    }
    return _nDevices;
}

- (NSMutableArray *)nServices
{
    if (!_nServices) {
        _nServices = [NSMutableArray array];
    }
    return _nServices;
}

#pragma mark - CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBCentralManagerStatePoweredOn:
        {
            NSLog(@"蓝牙已打开,请扫描外设");
            [_manager scanForPeripheralsWithServices:nil  options:@{CBCentralManagerScanOptionAllowDuplicatesKey : [NSNumber numberWithBool:YES]}];
        }
            break;
        case CBCentralManagerStatePoweredOff:
            NSLog(@"蓝牙没有打开,请先打开蓝牙");
            break;
        default:
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI
{
    [self updateLog:[NSString stringWithFormat:@"已发现 peripheral: %@ rssi: %@, UUID: %@ advertisementData: %@ ", peripheral, RSSI, peripheral.identifier, advertisementData]];
    _peripheral = peripheral;
    BOOL replace = NO;
    // Match if we have this device from before
    for (int i = 0; i < self.nDevices.count; i++) {
        CBPeripheral *p = [self.nDevices objectAtIndex:i];
        if ([p isEqual:peripheral]) {
            [self.nDevices replaceObjectAtIndex:i withObject:peripheral];
            replace = YES;
        }
    }
    if (!replace) {
        [self.nDevices addObject:peripheral];
    }
}

//连接外设成功，开始发现服务
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"%@", [NSString stringWithFormat:@"成功连接 peripheral: %@ with UUID: %@",peripheral,peripheral.identifier]);
    
    [_peripheral setDelegate:self];
    [_peripheral discoverServices:nil];
    NSLog(@"扫描服务");
    _isConnected = YES;
}
//连接外设失败
-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"%@",error);
    _isConnected = NO;
}

-(void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"%s,%@",__PRETTY_FUNCTION__,peripheral);
    int rssi = abs([peripheral.RSSI intValue]);
    CGFloat ci = (rssi - 49) / (10 * 4.);
    NSString *length = [NSString stringWithFormat:@"发现BLT4.0热点:%@,距离:%.1fm",_peripheral,pow(10,ci)];
    NSLog(@"%@", [NSString stringWithFormat:@"距离：%@", length]);
}

//已发现服务
-(void) peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error{
    
    NSLog(@"发现服务.");
    int i=0;
    for (CBService *s in peripheral.services) {
        [self.nServices addObject:s];
    }
    for (CBService *s in peripheral.services) {
        NSLog(@"%@", [NSString stringWithFormat:@"%d :服务 UUID: %@(%@)",i,s.UUID.data,s.UUID]);
        i++;
        [peripheral discoverCharacteristics:nil forService:s];
        
        if ([s.UUID isEqual:[CBUUID UUIDWithString:sUUID]]) {
            BOOL replace = NO;
            // Match if we have this device from before
            for (int i=0; i < self.nDevices.count; i++) {
                CBPeripheral *p = [_nDevices objectAtIndex:i];
                if ([p isEqual:peripheral]) {
                    [self.nDevices replaceObjectAtIndex:i withObject:peripheral];
                    replace = YES;
                }
            }
            if (!replace) {
                [self.nDevices addObject:peripheral];
                
            }
        }
    }
}

//已搜索到Characteristics
-(void) peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error{
    NSLog(@"%@", [NSString stringWithFormat:@"发现特征的服务:%@ (%@)",service.UUID.data ,service.UUID]);
    
    for (CBCharacteristic *c in service.characteristics) {
        NSLog(@"%@", [NSString stringWithFormat:@"特征 UUID: %@ (%@)",c.UUID.data,c.UUID]);
        
        if ([c.UUID isEqual:[CBUUID UUIDWithString:@"0xfff2"]]) {
            _writeCharacteristic = c;
        }
        
        if ([c.UUID isEqual:[CBUUID UUIDWithString:@"0xfff1"]]) {
            [_peripheral readValueForCharacteristic:c];
            NSLog(@"特性值：%@", c.value);
            [_peripheral setNotifyValue:YES forCharacteristic:c];
        }
        
        [_nCharacteristics addObject:c];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"%@", [NSString stringWithFormat:@"已断开与设备:[%@]的连接", peripheral.name]);
    _isConnected = NO;
}

//获取外设发来的数据，不论是read和notify,获取数据都是从这个方法中读取。
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"0xfff1"]]) {
        NSData * data = characteristic.value;
        Byte * resultByte = (Byte *)[data bytes];
        if (resultByte == NULL) {
            return;
        }
        for(int i=0;i<[data length];i++)
            //            printf("testByteFFF1[%d] = %x\n",i,resultByte[i]);
            
            if (resultByte[1] == 0xA1) {
                
            }else if (resultByte[1] == 0xA3) {
                
                [self updateLog:@"上传监测的睡眠数据"];
                
            }else if (resultByte[1] == 0x86 && resultByte[4] != 0xee) {
                NSLog(@"瞬时心率%@", [NSString stringWithFormat:@"心率%zi", resultByte[4]]);
                return;
                
            }else if (resultByte[1] == 0x87) {
                NSLog(@"手环版本");
            }else if (resultByte[1] == 0x83) {
                NSLog(@"手环电量 %zi%%", resultByte[4]);
            }else if (resultByte[1] == 0x90) {
                //NSLog(@"手环电量 %zi%%", resultByte[4]);
            }
    }
}

//中心读取外设实时数据
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error changing notification state: %@", error.localizedDescription);
    }
    
    // Notification has started
    if (characteristic.isNotifying) {
        [peripheral readValueForCharacteristic:characteristic];
        
    } else { // Notification has stopped
        // so disconnect from the peripheral
        NSLog(@"Notification stopped on %@.  Disconnecting", characteristic);
        [self updateLog:[NSString stringWithFormat:@"Notification stopped on %@.  Disconnecting", characteristic]];
        [self.manager cancelPeripheralConnection:self.peripheral];
    }
}
//用于检测中心向外设写数据是否成功
-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"=======%@",error.userInfo);
        //[self updateLog:[error.userInfo JSONString]];
    }else{
        NSLog(@"发送数据成功");
    }
    
    /* When a write occurs, need to set off a re-read of the local CBCharacteristic to update its value */
    [peripheral readValueForCharacteristic:characteristic];
}



- (void)updateLog:(NSString *)log
{
    NSLog(@"%@", log);
}

#pragma mark - 其它方法
-(NSData *)hexToBytes:(NSString *)hexString {
    NSMutableData* data = [NSMutableData data];
    int idx;
    for (idx = 0; idx < hexString.length; idx++) {
        NSRange range = NSMakeRange(idx, 1);
        NSString* hexStr = [hexString substringWithRange:range];
        NSScanner* scanner = [NSScanner scannerWithString:hexStr];
        unsigned int intValue;
        [scanner scanHexInt:&intValue];
        [data appendBytes:&intValue length:1];
    }
    
    return data;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        _nServices = [NSMutableArray array];
    }
    return self;
}

+ (instancetype)sharedTool {
    static id tool = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        tool = [[self alloc] init];
    });
    return tool;
}

@end
