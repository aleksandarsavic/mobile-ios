//
//  SyncViewController.m
//  Trovebox
//
//  Created by Patrick Santana on 18/06/12.
//  Copyright 2013 Trovebox
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "SyncViewController.h"

@interface SyncViewController (){
    BOOL hidden;
    CoreLocationController *coreLocationController;
}
-(void) switchedShowUploaded;
-(void) loadSavedPhotos;
@end

@implementation SyncViewController

@synthesize parent=_parent;
@synthesize assetGroup=_assetGroup, elcAssets=_elcAssets;
@synthesize imagesAlreadyUploaded;
@synthesize tableView=_tableView;
@synthesize buttonHidden =_buttonHidden;
@synthesize location=_location;


- (id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle
{
    self = [super initWithNibName:nibName bundle:nibBundle];
    if (self) {
        
        self.buttonHidden = [UIButton buttonWithType:UIButtonTypeCustom];
        [self.buttonHidden  addTarget:self action:@selector(switchedShowUploaded) forControlEvents:UIControlEventTouchUpInside];
        
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
        if (![standardUserDefaults valueForKey:kSyncShowUploadedPhotos]){
            // it does not exist
            // create as YES
            [standardUserDefaults setBool:YES forKey:kSyncShowUploadedPhotos];
            [standardUserDefaults synchronize];
            hidden = NO;
        }
        
        if  ([standardUserDefaults boolForKey:kSyncShowUploadedPhotos] == YES){
            // set the sync to NO
            hidden = NO;
        }else{
            hidden = YES;
        }
        
        // notification for update the table
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(eventHandler:)
                                                     name:kNotificationUpdateTableWithAllPhotosAgain
                                                   object:nil ];
    }
    return self;
}

-(void)viewDidLoad
{
    [super viewDidLoad];
	[self.tableView setAllowsSelection:NO];
    self.trackedViewName = @"Sync Screen";
    
    NSMutableArray *tempArray = [[NSMutableArray alloc] init];
    self.elcAssets = tempArray;
	
	[self.navigationItem setTitle:@"Loading..."];
    
    // button to sync
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *buttonImage = [UIImage imageNamed:@"next.png"] ;
    [button setImage:buttonImage forState:UIControlStateNormal];
    button.frame = CGRectMake(0, 0, buttonImage.size.width, buttonImage.size.height);
    [button addTarget:self action:@selector(doneAction:) forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *customBarItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    self.navigationItem.rightBarButtonItem = customBarItem;
    
    
    if (hidden){
        UIImage *buttonImage = [UIImage imageNamed:@"sync-show.png"] ;
        [self.buttonHidden setImage:buttonImage forState:UIControlStateNormal];
        self.buttonHidden.frame = CGRectMake(0, 0, buttonImage.size.width, buttonImage.size.height);
    }else{
        UIImage *buttonImage = [UIImage imageNamed:@"sync-hide.png"] ;
        [self.buttonHidden setImage:buttonImage forState:UIControlStateNormal];
        self.buttonHidden.frame = CGRectMake(0, 0, buttonImage.size.width, buttonImage.size.height);
    }
    
    customBarItem = [[UIBarButtonItem alloc] initWithCustomView:self.buttonHidden];
    self.navigationItem.leftBarButtonItem = customBarItem;
    
    self.navigationController.navigationBar.barStyle=UIBarStyleBlackOpaque;
    [self.navigationController.navigationBar setBackgroundColor:[UIColor blackColor]];
    
    UIImage *backgroundImage = [UIImage imageNamed:@"appbar_empty.png"];
    
    // image for the navigator
    if([[UINavigationBar class] respondsToSelector:@selector(appearance)]){
        //iOS >=5.0
        [self.navigationController.navigationBar setBackgroundImage:backgroundImage forBarMetrics:UIBarMetricsDefault];
    }else{
        UIImageView *imageView = (UIImageView *)[self.navigationController.navigationBar viewWithTag:6183746];
        if (imageView == nil)
        {
            imageView = [[UIImageView alloc] initWithImage:backgroundImage];
            [imageView setTag:6183746];
            [self.navigationController.navigationBar insertSubview:imageView atIndex:0];
        }
    }
    
    self.tableView.backgroundColor = [[UIColor alloc] initWithPatternImage:[UIImage imageNamed:@"Background.png"]];
    self.view.backgroundColor = [[UIColor alloc] initWithPatternImage:[UIImage imageNamed:@"Background.png"]];
    self.tableView.separatorColor = UIColorFromRGB(0xCDC9C1);
    
    // no separator
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    
    library = [[ALAssetsLibrary alloc] init];
    loaded = NO;
    
    // load all urls
    self.imagesAlreadyUploaded = [Synced getPathsInManagedObjectContext:[SharedAppDelegate managedObjectContext]];
    
    coreLocationController = [[CoreLocationController alloc] init];
    coreLocationController.delegate = self;
    
    [self loadSavedPhotos];
}

- (void) viewWillAppear:(BOOL)animated
{
    if (loaded == YES){
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.viewDeckController.view animated:YES];
        hud.labelText = @"Loading";
        // load all urls
        self.imagesAlreadyUploaded = [Synced getPathsInManagedObjectContext:[SharedAppDelegate managedObjectContext]];
        [self performSelectorInBackground:@selector(preparePhotos) withObject:nil];
        
    }else{
        loaded = YES;
    }
}

-(void)preparePhotos {
    if (loaded == YES){
        // in the case we had already loaded, let's clean the assets
        // to not have duplicate
        [self.elcAssets removeAllObjects];
    }
    
    @autoreleasepool {
#ifdef DEVELOPMENT_ENABLED
        NSLog(@"enumerating photos");
        NSLog("Assets Number %i", assetsNumber);
        NSLog("numberOfAssets %i", [self.assetGroup numberOfAssets]);
#endif
        
        if ([self.assetGroup numberOfAssets] != assetsNumber){
            // we need to load again
            [self loadSavedPhotos];
        }else{
            NSMutableArray *startArray = [NSMutableArray array];
            [self.assetGroup enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop)
             {
                 if(result == nil)
                 {
                     return;
                 }
                 
                 // check if user already uploaded
                 NSString *asset =  [AssetsLibraryUtilities getAssetsUrlId:result.defaultRepresentation.url] ;
                 
                 BOOL alreadyUploaded = [self.imagesAlreadyUploaded containsObject:asset];
                 if (!hidden || (hidden && !alreadyUploaded)){
                     ELCAsset *elcAsset = [[ELCAsset alloc] initWithAsset:result alreadyUploaded:alreadyUploaded];
                     [elcAsset setParent:self];
                     [startArray addObject:elcAsset];
                 }
             }];
            
            // add the camera icon
            ELCCamera *camera = [[ELCCamera alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
            [camera setParent:self];
            [startArray addObject:camera];
            
            //revert the order
            [self.elcAssets addObjectsFromArray:[[startArray reverseObjectEnumerator] allObjects]];
            
            
#ifdef DEVELOPMENT_ENABLED
            NSLog(@"done enumerating photos");
#endif
            [self.tableView reloadData];
            [self.navigationItem setTitle:@"Pick Photos"];
        }
    }
    
    [MBProgressHUD hideHUDForView:self.viewDeckController.view animated:YES];
}

- (void) doneAction:(id)sender {
	@try {
        NSMutableArray *selectedAssetsImages = [[NSMutableArray alloc] init];
        
        for(ELCAsset *elcAsset in self.elcAssets)
        {
            if([elcAsset selected]) {
                [selectedAssetsImages addObject:[elcAsset asset]];
            }
        }
        
        [(ELCAlbumPickerController*)self.parent selectedAssets:selectedAssetsImages];
    }@catch (NSException *exception) {
        PhotoAlertView *alert = [[PhotoAlertView alloc] initWithMessage:@"Error to select your photos" duration:3000];
        [alert showAlert];
        
        NSLog(@"A problem occured when NEXT is clicked on SyncController: %@", [exception description]);
        [self loadSavedPhotos];
    }
}

#pragma mark UITableViewDataSource Delegate Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return ceil([self.elcAssets count] / 4.0);
}

- (NSArray*)assetsForIndexPath:(NSIndexPath*)_indexPath {
    
	int index = (_indexPath.row*4);
	int maxIndex = (_indexPath.row*4+3);
    
	if(maxIndex < [self.elcAssets count]) {
        
		return [NSArray arrayWithObjects:[self.elcAssets objectAtIndex:index],
				[self.elcAssets objectAtIndex:index+1],
				[self.elcAssets objectAtIndex:index+2],
				[self.elcAssets objectAtIndex:index+3],
				nil];
	}
    
	else if(maxIndex-1 < [self.elcAssets count]) {
        
		return [NSArray arrayWithObjects:[self.elcAssets objectAtIndex:index],
				[self.elcAssets objectAtIndex:index+1],
				[self.elcAssets objectAtIndex:index+2],
				nil];
	}
    
	else if(maxIndex-2 < [self.elcAssets count]) {
        
		return [NSArray arrayWithObjects:[self.elcAssets objectAtIndex:index],
				[self.elcAssets objectAtIndex:index+1],
				nil];
	}
    
	else if(maxIndex-3 < [self.elcAssets count]) {
        
		return [NSArray arrayWithObject:[self.elcAssets objectAtIndex:index]];
	}
    
	return nil;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    ELCAssetCell *cell = (ELCAssetCell*)[self.tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil)
    {
        cell = [[ELCAssetCell alloc] initWithAssets:[self assetsForIndexPath:indexPath] reuseIdentifier:CellIdentifier];
    }
	else
    {
		[cell setAssets:[self assetsForIndexPath:indexPath]];
	}
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
	return 79;
}

- (int)totalSelectedAssets {
    
    int count = 0;
    
    for(ELCAsset *asset in self.elcAssets)
    {
		if([asset selected])
        {
            count++;
		}
	}
    
    return count;
}

- (void) switchedShowUploaded
{
    // change the boolean
    hidden = !hidden;
    
    NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
    
    // set details of the button
    UIImage *buttonImage;
    NSString *message;
    if (!hidden){
        buttonImage = [UIImage imageNamed:@"sync-hide.png"] ;
        message = @"Showing all of your photos";
        [standardUserDefaults setBool:YES forKey:kSyncShowUploadedPhotos];
    }else{
        buttonImage = [UIImage imageNamed:@"sync-show.png"] ;
        message = @"Hiding photos you've already uploaded";
        [standardUserDefaults setBool:NO forKey:kSyncShowUploadedPhotos];
    }
    [standardUserDefaults synchronize];
    
    [self.buttonHidden setImage:buttonImage forState:UIControlStateNormal];
    
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.viewDeckController.view animated:YES];
    hud.labelText = @"Loading";
    
    // load all urls
    self.imagesAlreadyUploaded = [Synced getPathsInManagedObjectContext:[SharedAppDelegate managedObjectContext]];
    [self performSelectorInBackground:@selector(preparePhotos) withObject:nil];
    
    
    // show explanations
    PhotoAlertView *alert = [[PhotoAlertView alloc] initWithMessage:message duration:3000];
    [alert showAlert];
}

- (void) loadSavedPhotos
{
    // the Saved Photos Album
    dispatch_async(dispatch_get_main_queue(), ^
                   {
                       // Group enumerator Block
                       void (^assetGroupEnumerator)(ALAssetsGroup *, BOOL *) = ^(ALAssetsGroup *group, BOOL *stop)
                       {
                           if (group == nil)
                           {
                               return;
                           }
                           
                           if ( [[group valueForProperty:ALAssetsGroupPropertyType] intValue] == ALAssetsGroupSavedPhotos) {
                               self.assetGroup = group;
                               [self.assetGroup setAssetsFilter:[ALAssetsFilter allPhotos]];
                               MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.viewDeckController.view animated:YES];
                               hud.labelText = @"Loading";
                               assetsNumber = [self.assetGroup numberOfAssets];
                               
                               // with the local group, we can load the images
                               [self performSelectorInBackground:@selector(preparePhotos) withObject:nil];
                           }
                       };
                       
                       // Group Enumerator Failure Block
                       void (^assetGroupEnumberatorFailure)(NSError *) = ^(NSError *error) {
                           
                           UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Album Error: %@ - %@", [error localizedDescription], [error localizedRecoverySuggestion]] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
                           [alert show];
                           
                           NSLog(@"A problem occured %@", [error description]);
                       };
                       
                       // Show only the Saved Photos
                       [library enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos
                                              usingBlock:assetGroupEnumerator
                                            failureBlock:assetGroupEnumberatorFailure];
                       
                   });
    
}

- (void) eventHandler: (NSNotification *) notification{
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"###### Event triggered: %@", notification);
#endif
    
    if ([notification.name isEqualToString:kNotificationUpdateTableWithAllPhotosAgain]){
        // just reset the number of photos
        assetsNumber = -1;
        [self loadSavedPhotos];
    }
}


// Sync
#pragma mark ELCImagePickerControllerDelegate Methods

- (void)elcImagePickerController:(ELCImagePickerController *)picker didFinishPickingMediaWithInfo:(NSArray *)info {
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"Selected some images");
#endif
    
    if (info != nil && [info count]>0 ){
        // convert to nsarray
        NSMutableArray *urls = [NSMutableArray array];
        for(NSDictionary *dict in info) {
            [urls addObject:[dict objectForKey:UIImagePickerControllerReferenceURL]];
        }
        
        PhotoViewController* controller = [[PhotoViewController alloc]initWithNibName:[DisplayUtilities getCorrectNibName:@"PhotoViewController"] bundle:nil images:urls];
        [picker pushViewController:controller animated:YES];
    }else{
        // no photo select
        PhotoAlertView *alert = [[PhotoAlertView alloc] initWithMessage:@"Please select at least 1 photo!" duration:5000];
        [alert showAlert];
        
        // go to the home
        // close the sync
    }
    
}

- (void)elcImagePickerControllerDidCancel:(ELCImagePickerController *)picker {
    // this one is not used.
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"Cancel Sync");
#endif
}


- (void) handleCamera
{
    // check if user has camera
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]){
        PhotoAlertView *alert = [[PhotoAlertView alloc] initWithMessage:@"Your device hasn't a camera" duration:5000];
        [alert showAlert];
    }else{
        // start localtion
        [coreLocationController.locMgr startUpdatingLocation];
        
        UIImagePickerController *pickerController = [[UIImagePickerController
                                                      alloc]
                                                     init];
        pickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
        pickerController.delegate = self;
        [self  presentModalViewController:pickerController animated:YES];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    // the image itself to save in the library
    UIImage *pickedImage = [info
                            objectForKey:UIImagePickerControllerOriginalImage];
    
    // User come from Snapshot. We will temporary save in the Library.
    // If in the Settings is configure to not save in the library, we will delete
    NSMutableDictionary *exif = nil;
    
    // check if metadata is available
    if ([info objectForKey:UIImagePickerControllerMediaMetadata] != nil) {
        exif = [NSMutableDictionary dictionaryWithDictionary:[info objectForKey:UIImagePickerControllerMediaMetadata]];
        
        
        NSDictionary *gpsDict  = [self currentLocation];
        if ([gpsDict count] > 0) {
#ifdef DEVELOPMENT_ENABLED
            NSLog(@"There is location");
#endif
            [exif setObject:gpsDict forKey:(NSString*) kCGImagePropertyGPSDictionary];
        }else{
#ifdef DEVELOPMENT_ENABLED
            NSLog(@"No location found");
#endif
        }
        
    }
    
    [library writeImageToSavedPhotosAlbum:[pickedImage CGImage] metadata:exif completionBlock:^(NSURL *newUrl, NSError *error) {
        if (error) {
            NSLog(@"The photo took by the user could not be saved = %@", [error description]);
        } else {
            PhotoViewController* controller = [[PhotoViewController alloc]initWithNibName:[DisplayUtilities getCorrectNibName:@"PhotoViewController"] bundle:nil url:newUrl image:pickedImage];
            [picker pushViewController:controller animated:YES];
        }
    }];
    
    
    // stop location
    [coreLocationController.locMgr stopUpdatingLocation];
    
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [picker dismissModalViewControllerAnimated:YES];
    [coreLocationController.locMgr stopUpdatingLocation];
}


//Creates an EXIF field for the current geo location.
- (NSMutableDictionary*)currentLocation {
    NSMutableDictionary *locDict = [[NSMutableDictionary alloc] init];
	
	if (self.location != nil) {
		CLLocationDegrees exifLatitude = self.location.coordinate.latitude;
		CLLocationDegrees exifLongitude = self.location.coordinate.longitude;
        
		[locDict setObject:self.location.timestamp forKey:(NSString*) kCGImagePropertyGPSTimeStamp];
		
		if (exifLatitude < 0.0) {
			exifLatitude = exifLatitude*(-1);
			[locDict setObject:@"S" forKey:(NSString*)kCGImagePropertyGPSLatitudeRef];
		} else {
			[locDict setObject:@"N" forKey:(NSString*)kCGImagePropertyGPSLatitudeRef];
		}
		[locDict setObject:[NSNumber numberWithFloat:exifLatitude] forKey:(NSString*)kCGImagePropertyGPSLatitude];
        
		if (exifLongitude < 0.0) {
			exifLongitude=exifLongitude*(-1);
			[locDict setObject:@"W" forKey:(NSString*)kCGImagePropertyGPSLongitudeRef];
		} else {
			[locDict setObject:@"E" forKey:(NSString*)kCGImagePropertyGPSLongitudeRef];
		}
		[locDict setObject:[NSNumber numberWithFloat:exifLongitude] forKey:(NSString*) kCGImagePropertyGPSLongitude];
	}
	
    return locDict;
    
}

- (void)locationUpdate:(CLLocation *)position{
    self.location = position;
#ifdef DEVELOPMENT_ENABLED
    NSLog(@"Position %@", position);
#endif
}

- (void)locationError:(NSError *)error {
    NSLog(@"Location error %@", [error description]);
    
    if ([error code] == kCLErrorDenied){
        // validate if we had checked once if user allowed location
        NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
        if (standardUserDefaults) {
            
            if (![[NSUserDefaults standardUserDefaults] boolForKey:kValidateNotAllowedLocation] ||
                [[NSUserDefaults standardUserDefaults] boolForKey:kValidateNotAllowedLocation] == NO){
                // validated
                [standardUserDefaults setBool:YES forKey:kValidateNotAllowedLocation];
                
                // synchronize the keys
                [standardUserDefaults synchronize];
            }
        }
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidUnload {
    [self setTableView:nil];
    [super viewDidUnload];
}
@end