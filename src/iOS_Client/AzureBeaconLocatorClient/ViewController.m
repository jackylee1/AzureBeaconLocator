//
//  ViewController.m
//  TechReadyIoTRetail
//
//  Created by Kevin Stubbs on 1/19/15.
//  Copyright (c) 2015 Microsoft. All rights reserved.
//

#import "ViewController.h"
#import "ESTBeacon.h"
#import "ESTBeaconManager.h"
#import "ESTBeaconRegion.h"

@interface ViewController () <ESTBeaconManagerDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) ESTBeacon         *beacon;
@property (nonatomic, strong) ESTBeaconManager  *beaconManager;
@property (nonatomic, strong) ESTBeaconRegion   *beaconRegion;

-(void)processBeaconSignal:(ESTBeacon*)beacon;

@end

@implementation ViewController

UITableView *tableView;
UILabel *deviceInfo;
UILabel *internetConnectionErrorInfo;
NSInteger numberOfInternetConnectionErrors = 0;

NSMutableArray *beaconsDiscovered;
NSString *currentDeviceId = @"NO DEVICE ID AVAILABLE";

- (void)viewDidLoad
{
  [super viewDidLoad];

  // We keep a collection of the beacons recently found
  // to show in a table on our client-side UI.
  // It's mostly for debugging.
  beaconsDiscovered = [[NSMutableArray alloc] init];

  // Create the table containing all beacons in sight and their estimated distances,
  // a label showing this device's unique ID,
  // and another label to indicate if any internet errors have occurred during runtime.
  [self initializeUIElements];
}

-(void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  
  // Create our beacon manager.
  self.beaconManager = [[ESTBeaconManager alloc] init];
  self.beaconManager.delegate = self;
  self.beaconManager.avoidUnknownStateBeacons = YES;

  // iOS 8 requires us to request location authorization before we'll be
  // given access to beacons.
  [self.beaconManager requestAlwaysAuthorization];

  // Create our region using our beacons' predetermined shared proximity unique ID.
  self.beaconRegion = [[ESTBeaconRegion alloc] initWithProximityUUID:[[NSUUID alloc] initWithUUIDString:@"B9407F30-F5F8-466E-AFF9-25556B57FE6D"] identifier:@"TechReady 20 Stage"];

  // Begin looking for Estimote beacons.
  // Everytime beacons are pinged, beaconManager:didRangeBeacons:inRange: method will be invoked.
  [self.beaconManager startMonitoringForRegion:self.beaconRegion];
  [self.beaconManager startRangingBeaconsInRegion:self.beaconRegion];
}

-(void)beaconManager:(ESTBeaconManager *)manager
     didRangeBeacons:(NSArray *)beacons
            inRegion:(ESTBeaconRegion *)region
{
  [beaconsDiscovered removeAllObjects];

  for(ESTBeacon* beacon in beacons)
  {
      [beaconsDiscovered addObject:beacon];

      [self processBeaconSignal:beacon];
  }

  [self sortBeaconsList];
  [tableView reloadData];
}

-(void)processBeaconSignal:(ESTBeacon*)beacon
{
    if(beacon.distance.intValue == -1)
    {
       // NSLog(@"Beacon with major #%@ has invalid distance of %@ (probably because no RSSI, of %ld", beacon.major, beacon.distance, (long)beacon.rssi);
    
        return;
    }

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    // iospublisher is the name for this (iOS app) as a publisher. It can be anything you want.
    [request setURL:[NSURL URLWithString:@"https://YOUR-EVENTHUB-NAMESPACE.servicebus.windows.net/CONSUMER_GROUP_NAME/publishers/iospublisher/messages"]];
    [request setValue:@"application/atom+xml;type=entry;charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"SharedAccessSignature sr=YOUR SAS TOKEN" forHTTPHeaderField:@"Authorization"];
    [request setHTTPMethod:@"POST"];
    
    NSMutableData *data = [NSMutableData data];
    [data appendData:[[NSString stringWithFormat:@"{\"DeviceId\": \"%@\", \"Distance\": \"%f\", \"RSSI\": \"%ld\", \"Major\": \"%@\", \"Minor\": \"%@\", \"UUID\":\"%@\"}", currentDeviceId, beacon.distance.floatValue * 3.28084f, (long)beacon.rssi, beacon.major, beacon.minor, [beacon.proximityUUID UUIDString]] dataUsingEncoding:NSUTF8StringEncoding]];
    [request setHTTPBody:data]; // 1 meter = 3.28084 feet.
  
    NSURLResponse *requestResponse;
    NSError *err;
    [NSURLConnection sendSynchronousRequest:request returningResponse:&requestResponse error:&err];
    
    if (err)
    {
        // An error here is almost always caused by losing internet connection.
        numberOfInternetConnectionErrors++;
        internetConnectionErrorInfo.text = [NSString stringWithFormat:@"# Internet Connection Errors: %ld", (long)numberOfInternetConnectionErrors];
        NSLog(@"sendSynchronousRequest error: %@", err);
    }
}

-(void)sortBeaconsList
{
  beaconsDiscovered = [NSMutableArray arrayWithArray:[beaconsDiscovered sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
      NSNumber *first = [(ESTBeacon*)a minor];
      NSNumber *second = [(ESTBeacon*)b minor];
      return [first compare:second];
  }]];
}

-(void)initializeUIElements
{
  tableView= [[UITableView alloc]init];
  tableView.frame = CGRectMake(10,30,920,900);
  tableView.dataSource=self;
  tableView.delegate=self;
  tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
  [tableView reloadData];
  [self.view addSubview:tableView];

  UIDevice *device = [UIDevice currentDevice];
  currentDeviceId = [[device identifierForVendor]UUIDString];

  deviceInfo = [[UILabel alloc] initWithFrame:CGRectMake(10, 10, 500, 20)];

  [deviceInfo setTextColor:[UIColor blackColor]];
  [deviceInfo setBackgroundColor:[UIColor clearColor]];
  [deviceInfo setFont:[UIFont fontWithName: @"Trebuchet MS" size: 14.0f]];
  deviceInfo.text = [NSString stringWithFormat:@"Device ID: %@", currentDeviceId];
  [self.view addSubview:deviceInfo];

  internetConnectionErrorInfo = [[UILabel alloc] initWithFrame:CGRectMake(10, 35, 500, 40)];

  [internetConnectionErrorInfo setTextColor:[UIColor blackColor]];
  [internetConnectionErrorInfo setBackgroundColor:[UIColor clearColor]];
  [internetConnectionErrorInfo setFont:[UIFont fontWithName: @"Trebuchet MS" size: 14.0f]];
  internetConnectionErrorInfo.text = [NSString stringWithFormat:@"# Internet Connection Errors: %ld", (long)numberOfInternetConnectionErrors];
  [self.view addSubview:internetConnectionErrorInfo];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
   return beaconsDiscovered.count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
   return 50;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
   // Your custom operation
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
   static NSString *simpleTableIdentifier = @"TableItem";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];

    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }
    
    cell.textLabel.font = [UIFont systemFontOfSize:12.0];
    cell.textLabel.numberOfLines = 0;
    [cell.textLabel setLineBreakMode:NSLineBreakByWordWrapping];
   
   ESTBeacon *beacon = (ESTBeacon*)[beaconsDiscovered objectAtIndex:indexPath.row];
   
   NSString *identifier = [NSString stringWithFormat:@"%@:%@", beacon.major, beacon.minor];
   
   if(beacon.major.intValue == 55465 && beacon.minor.intValue == 28092)
   {
        identifier = @"Kevin's mint iBeacon";
   }
   else if(beacon.major.intValue == 56826 && beacon.minor.intValue == 48614)
   {
        identifier = @"Kevin's ice iBeacon";
   }
   else if(beacon.major.intValue == 28850 && beacon.minor.intValue == 49118)
   {
        identifier = @"Kevin's blueberry iBeacon";
   }
   else if(beacon.major.intValue == 51728 && beacon.minor.intValue == 3)
   {
        identifier = @"Paul's mint iBeacon";
   }
   else if(beacon.major.intValue == 13052 && beacon.minor.intValue == 2)
   {
        identifier = @"Paul's ice iBeacon";
   }
   else if(beacon.major.intValue == 19162 && beacon.minor.intValue == 1)
   {
        identifier = @"Paul's blueberry iBeacon";
   }
   
   if(beacon.distance.intValue == -1)
   {
        cell.textLabel.text = [NSString stringWithFormat:@"%@ distance N/A", identifier];
   }
   else
   {
        cell.textLabel.text = [NSString stringWithFormat:@"%@ distance of %f ft", identifier, beacon.distance.floatValue * 3.28084f]; // 1 meter = 3.28084 feet.
   }
   
   return cell;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [self.beaconManager stopRangingBeaconsInRegion:self.beaconRegion];

    [super viewDidDisappear:animated];
}

@end
