/**
   Copyright 2011 Atlassian Software

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
**/
#import "JMC.h"
#import "JMCMacros.h"
#import "JMCViewController.h"
#import "UIImage+Resize.h"
#import "Core/UIView+Additions.h"
#import "JMCAttachmentItem.h"
#import "Core/JMCSketchViewController.h"
#import "Core/JMCIssueStore.h"
#import "JSON.h"
#import <QuartzCore/QuartzCore.h>

@interface JMCViewController ()
- (void)internalRelease;

- (UIBarButtonItem *)barButtonFor:(NSString *)iconNamed action:(SEL)action;

- (void)addAttachmentItem:(JMCAttachmentItem *)attachment withIcon:(UIImage *)icon action:(SEL)action;

- (BOOL)shouldTrackLocation;

@property(nonatomic, retain) CLLocation *currentLocation;
@property(nonatomic, retain) CRVActivityView *activityView;
@end

@implementation JMCViewController

NSArray* toolbarItems; // holds the first 3 system toolbar items.

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _issueTransport = [[[JMCIssueTransport alloc] init] retain];
        _replyTransport = [[[JMCReplyTransport alloc] init] retain];
        _recorder = [[[JMCRecorder alloc] init] retain];
    }
    return self;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
        // Observe keyboard hide and show notifications to resize the text view appropriately.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    sendLocationData = NO;
    if ([self.payloadDataSource respondsToSelector:@selector(locationEnabled)]) {
        sendLocationData = [[self payloadDataSource] locationEnabled];
    }

    if ([self shouldTrackLocation]) {
        _locationManager = [[[CLLocationManager alloc] init] retain];
        _locationManager.delegate = self;
        [_locationManager startUpdatingLocation];

        //TODO: remove this. just for testing location in the simulator.
#if TARGET_IPHONE_SIMULATOR
        // -33.871088, 151.203665
        CLLocation *fixed = [[CLLocation alloc] initWithLatitude:-33.871088 longitude:151.203665];
        [self setCurrentLocation: fixed];
        [fixed release];
#endif
    }

    // layout views
    self.recorder.recorder.delegate = self;
    self.countdownView.layer.cornerRadius = 7.0;
    
    self.navigationItem.leftBarButtonItem =
            [[[UIBarButtonItem alloc] initWithTitle:JMCLocalizedString(@"Close", @"Close navigation item")
                                              style:UIBarButtonItemStyleBordered
                                             target:self
                                             action:@selector(dismiss)] autorelease];
    
    self.navigationItem.title = JMCLocalizedString(@"Feedback", "Title of the feedback controller");


    self.navigationItem.rightBarButtonItem =
            [[[UIBarButtonItem alloc] initWithTitle:JMCLocalizedString(@"Send", @"Close navigation item")
                                              style:UIBarButtonItemStyleDone
                                             target:self
                                             action:@selector(sendFeedback)] autorelease];

    self.attachments = [NSMutableArray arrayWithCapacity:1];
    self.toolbar.clipsToBounds = YES;
    self.toolbar.items = nil;
    self.toolbar.autoresizesSubviews = YES;

    float descriptionFieldInset = 15;
    self.descriptionField.top = 44 + descriptionFieldInset;
    self.descriptionField.width = self.view.width - (descriptionFieldInset * 2.0);
    descriptionFrame = self.descriptionField.frame;

    self.toolbar = [[[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 44)] autorelease];
    [self.toolbar setBarStyle:UIBarStyleBlackOpaque];

    UIBarButtonItem *screenshotButton = [self barButtonFor:@"icon_capture" action:@selector(addScreenshot)];
    UIBarButtonItem *recordButton = [self barButtonFor:@"icon_record" action:@selector(addVoice)];
    UIBarButtonItem *spaceButton = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                            target:nil action:nil] autorelease];
    NSMutableArray* items = [NSMutableArray arrayWithCapacity:3];
    if ([[JMC instance] isPhotosEnabled]) {
        [items addObject:screenshotButton];
    }
    if ([[JMC instance] isVoiceEnabled]) {
        [items addObject:recordButton];
    }

    [items addObject:spaceButton];

    systemToolbarItems = [[NSArray arrayWithArray:items] retain];
    self.voiceButton = recordButton;
    self.toolbar.items = systemToolbarItems;
    self.descriptionField.inputAccessoryView = self.toolbar;

}

- (void) viewWillAppear:(BOOL)animated {
    [self.descriptionField becomeFirstResponder];
    [_locationManager startUpdatingLocation];
}

- (void) viewDidDisappear:(BOOL)animated {
    [_locationManager stopUpdatingLocation];
}


#pragma mark UITextViewDelegate

- (void)keyboardWillShow:(NSNotification*)notification
{
   /*
     Reduce the size of the text view so that it's not obscured by the keyboard.
     Animate the resize so that it's in sync with the appearance of the keyboard.
     */

    NSDictionary *userInfo = [notification userInfo];

    // Get the origin of the keyboard when it's displayed.
    NSValue* aValue = [userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];

    // Get the top of the keyboard as the y coordinate of its origin in self's view's coordinate system. The bottom of the text view's frame should align with the top of the keyboard's final position.
    CGRect keyboardRect = [aValue CGRectValue];
    keyboardRect = [self.view convertRect:keyboardRect fromView:nil];

    CGFloat keyboardTop = keyboardRect.origin.y;
    CGRect newTextViewFrame = self.view.bounds;
    newTextViewFrame.size.height = keyboardTop - self.view.bounds.origin.y - 40;
    newTextViewFrame.origin.y = 44; // TODO: un-hardcode this

    // Get the duration of the animation.
    NSValue *animationDurationValue = [userInfo objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    NSTimeInterval animationDuration;
    [animationDurationValue getValue:&animationDuration];

    // Animate the resize of the text view's frame in sync with the keyboard's appearance.
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:animationDuration];

    self.descriptionField.frame = newTextViewFrame;

    [UIView commitAnimations];

}

- (void)keyboardWillHide:(NSNotification*)notification
{

}

- (UIBarButtonItem *)barButtonFor:(NSString *)iconNamed action:(SEL)action
{
    UIButton *customView = [UIButton buttonWithType:UIButtonTypeCustom];
    [customView addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [customView setBackgroundImage:[UIImage imageNamed:@"button_base"] forState:UIControlStateNormal];
    UIImage *icon = [UIImage imageNamed:iconNamed];
    CGRect frame = CGRectMake(0, 0, 41, 31);
    [customView setImage:icon forState:UIControlStateNormal];
    customView.frame = frame;
    UIBarButtonItem *barItem = [[[UIBarButtonItem alloc] initWithCustomView:customView] autorelease];

    return barItem;
}

- (BOOL)textViewShouldBeginEditing:(UITextView *)aTextView {
    
    return YES;
}

#pragma mark end

- (IBAction)dismiss
{
    [self dismissModalViewControllerAnimated:YES];
}

- (IBAction)dismissKeyboard
{
    [self.descriptionField resignFirstResponder];
}

- (IBAction)addScreenshot
{
    [self presentModalViewController:imagePicker animated:YES];
}

- (void)updateProgress:(NSTimer *)theTimer
{
    float currentDuration = [_recorder currentDuration];
    float progress = (currentDuration / _recorder.recordTime);
    self.progressView.progress = progress;
}

- (void)hideAudioProgress
{
    self.countdownView.hidden = YES;
    self.progressView.progress = 0;
    UIButton *voiceButton = (UIButton *) self.voiceButton.customView;
    [voiceButton.imageView stopAnimating];
    voiceButton.imageView.animationImages = nil;
    [_timer invalidate];
}

- (IBAction)addVoice
{

    if (_recorder.recorder.recording) {
        [_recorder stop];

    } else {
        [_recorder start];
        _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(updateProgress:) userInfo:nil repeats:YES];
        self.progressView.progress = 0;

        self.countdownView.hidden = NO;

        // start animating the voice button...
        NSMutableArray *sprites = [NSMutableArray arrayWithCapacity:8];
        for (int i = 1; i < 9; i++) {
            NSString *sprintName = [@"icon_record_" stringByAppendingFormat:@"%d", i];
            UIImage *img = [UIImage imageNamed:sprintName];
            [sprites addObject:img];
        }
        UIButton * customView = (UIButton *)self.voiceButton.customView;
        customView.imageView.animationImages = sprites;
        customView.imageView.animationDuration = 0.85f;
        [customView.imageView startAnimating];

    }
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)success
{

    [self hideAudioProgress];

    JMCAttachmentItem *attachment = [[JMCAttachmentItem alloc] initWithName:@"recording"
                                                                       data:[_recorder audioData]
                                                                       type:JMCAttachmentTypeRecording
                                                                contentType:@"audio/aac"
                                                             filenameFormat:@"recording-%d.aac"];


    UIImage *newImage = [UIImage imageNamed:@"icon_record_2"];
    [self addAttachmentItem:attachment withIcon:newImage action:@selector(voiceAttachmentTapped:)];
    [attachment release];
}

- (void)addAttachmentItem:(JMCAttachmentItem *)attachment withIcon:(UIImage *)icon action:(SEL)action
{
    CGRect buttonFrame = CGRectMake(0, 0, 30, 30);
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = buttonFrame;
    
    [button setBackgroundImage:[UIImage imageNamed:@"button_base"] forState:UIControlStateNormal];

    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    button.imageView.layer.cornerRadius = 5.0;

    [button setImage:icon forState:UIControlStateNormal];
    
    UIBarButtonItem *buttonItem = [[[UIBarButtonItem alloc] initWithCustomView:button] autorelease];
    button.tag = [self.toolbar.items count];

    NSMutableArray *buttonItems = [NSMutableArray arrayWithArray:self.toolbar.items];
    [buttonItems addObject:buttonItem];
    [self.toolbar setItems:buttonItems];
    [self.attachments addObject:attachment];
}

- (void)addImageAttachmentItem:(UIImage *)origImg
{
    JMCAttachmentItem *attachment = [[JMCAttachmentItem alloc] initWithName:@"screenshot"
                                                                       data:UIImagePNGRepresentation(origImg)
                                                                       type:JMCAttachmentTypeImage
                                                                contentType:@"image/png"
                                                             filenameFormat:@"screenshot-%d.png"];

    
    UIImage * iconImg =
            [origImg thumbnailImage:30 transparentBorder:0 cornerRadius:0.0 interpolationQuality:kCGInterpolationDefault];
    [self addAttachmentItem:attachment withIcon:iconImg action:@selector(imageAttachmentTapped:)];
    [attachment release];
}

- (void)removeAttachmentItemAtIndex:(NSUInteger)attachmentIndex
{

    [self.attachments removeObjectAtIndex:attachmentIndex];
    NSMutableArray *buttonItems = [NSMutableArray arrayWithArray:self.toolbar.items];
    [buttonItems removeObjectAtIndex:attachmentIndex + [systemToolbarItems count]]; // TODO: fix this pullava
    // re-tag all buttons... with their new index. indexed from 2, due to icons...
    for (int i = 0; i < [buttonItems count]; i++) {
        UIBarButtonItem *buttonItem = (UIBarButtonItem *) [buttonItems objectAtIndex:(NSUInteger) i];
        buttonItem.customView.tag = i;
    }

    [self.toolbar setItems:buttonItems animated:YES];
}

- (void)imageAttachmentTapped:(UIButton *)touch
{
    // delete that button, both from the bar, and the images array
    NSUInteger touchIndex = (u_int) touch.tag;
    NSUInteger attachmentIndex = touchIndex - [systemToolbarItems count];
    JMCAttachmentItem *attachment = [self.attachments objectAtIndex:attachmentIndex];
    JMCSketchViewController *sketchViewController = [[[JMCSketchViewController alloc] initWithNibName:@"JMCSketchViewController" bundle:nil] autorelease];
    // get the original image, wire it up to the sketch controller
    sketchViewController.image = [[[UIImage alloc] initWithData:attachment.data] autorelease];
    sketchViewController.imageId = [NSNumber numberWithUnsignedInteger:attachmentIndex]; // set this image's id. just the index in the array
    sketchViewController.delegate = self;
    [self presentModalViewController:sketchViewController animated:YES];
    currentAttachmentItemIndex = touchIndex;
}

- (void)voiceAttachmentTapped:(UIButton *)touch
{
    // delete that button, both from the bar, and the images array
    NSUInteger tapIndex = (u_int) touch.tag;
    NSUInteger attachmentIndex = tapIndex - [systemToolbarItems count]; // TODO: refactor this, and the image method too, into a rebase method..
    UIAlertView *view =
            [[UIAlertView alloc] initWithTitle:JMCLocalizedString(@"RemoveRecording", @"Remove recording title")
                                 message:JMCLocalizedString(@"AlertBeforeDeletingRecording", @"Warning message before deleting a recording.")
                                 delegate:self
                             cancelButtonTitle:JMCLocalizedString(@"No", @"")
                             otherButtonTitles:JMCLocalizedString(@"Yes", @""), nil];
    currentAttachmentItemIndex = attachmentIndex;
    [view show];
    [view release];


}

#pragma mark UIAlertViewDelelgate
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    // dismiss modal dialog.
    if (buttonIndex == 1) {
        [self removeAttachmentItemAtIndex:currentAttachmentItemIndex];
    }
    currentAttachmentItemIndex = 0;
}


#pragma end

#pragma mark UIImagePickerControllerDelegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{

    [self dismissModalViewControllerAnimated:YES];

    UIImage *origImg = (UIImage *) [info objectForKey:UIImagePickerControllerOriginalImage];

      if (origImg.size.height > self.view.height) {
        // resize image... its too huge! (only meant to be screenshots, not photos..)
        CGSize size = origImg.size;
        float ratio = self.view.height / size.height;
        CGSize smallerSize = CGSizeMake(ratio * size.width, ratio * size.height);
        origImg = [origImg resizedImage:smallerSize interpolationQuality:kCGInterpolationMedium];
    }

    [self addImageAttachmentItem:origImg];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissModalViewControllerAnimated:YES];
}
#pragma mark end

#pragma mark JMCSketchViewControllerDelegate

- (void)sketchController:(UIViewController *)controller didFinishSketchingImage:(UIImage *)image withId:(NSNumber *)imageId
{
    [self dismissModalViewControllerAnimated:YES];
    NSUInteger imgIndex = [imageId unsignedIntegerValue];
    JMCAttachmentItem *attachment = [self.attachments objectAtIndex:imgIndex];
    attachment.data = UIImagePNGRepresentation(image);

    // also update the icon in the toolbar
    UIImage * iconImg =
            [image thumbnailImage:30 transparentBorder:0 cornerRadius:0.0 interpolationQuality:kCGInterpolationDefault];

    UIBarButtonItem *item = [self.toolbar.items objectAtIndex:imgIndex + [systemToolbarItems count]];
    ((UIButton *) item.customView).imageView.image = iconImg;
}

- (void)sketchControllerDidCancel:(UIViewController *)controller
{
    [self dismissModalViewControllerAnimated:YES];
}

- (void)sketchController:(UIViewController *)controller didDeleteImageWithId:(NSNumber *)imageId
{
    [self dismissModalViewControllerAnimated:YES];
    [self removeAttachmentItemAtIndex:[imageId unsignedIntegerValue]];
}


#pragma mark end

#pragma mark UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}
#pragma mark end

- (IBAction)sendFeedback
{

	CGPoint center = CGPointMake(self.descriptionField.width/2.0, self.descriptionField.height/2.0 + 50);

    CRVActivityView *av = [CRVActivityView newDefaultViewForParentView:[self view] center:center];
    [av setText:JMCLocalizedString(@"Sending...", @"")];
    [av startAnimating];
    [av setDelegate:self];
    [self setActivityView:av];
    [av release];

    self.issueTransport.delegate = self;
    NSDictionary *payloadData = nil;
    NSMutableDictionary *customFields = [[NSMutableDictionary alloc] init];

    if ([self.payloadDataSource respondsToSelector:@selector(payload)]) {
        payloadData = [[self.payloadDataSource payload] retain];
    }
    if ([self.payloadDataSource respondsToSelector:@selector(customFields)]) {
        [customFields addEntriesFromDictionary:[self.payloadDataSource customFields]];
    }


    if ([self shouldTrackLocation] && [self currentLocation]) {
        NSMutableArray *objects = [NSMutableArray arrayWithCapacity:3];
        NSMutableArray *keys =    [NSMutableArray arrayWithCapacity:3];
        @synchronized (self) {
            NSNumber *lat = [NSNumber numberWithDouble:currentLocation.coordinate.latitude];
            NSNumber *lng = [NSNumber numberWithDouble:currentLocation.coordinate.longitude];
            NSString *locationString = [NSString stringWithFormat:@"%f,%f", lat.doubleValue, lng.doubleValue];
            [keys addObject:@"lat"];      [objects addObject:lat];
            [keys addObject:@"lng"];      [objects addObject:lng];
            [keys addObject:@"location"]; [objects addObject:locationString];
        }

        // Merge the location into the existing customFields.
        NSDictionary *dict = [[NSDictionary alloc] initWithObjects:objects forKeys:keys];
        [customFields addEntriesFromDictionary:dict];
        [dict release];
    }

    if (self.replyToIssue) {
        [self.replyTransport sendReply:self.replyToIssue
                           description:self.descriptionField.text
                                images:self.attachments
                               payload:payloadData
                                fields:customFields];
    } else {
        // use the first 80 chars of the description as the issue title
        NSString *description = self.descriptionField.text;
        u_int length = 80;
        u_int toIndex = [description length] > length ? length : [description length];
        NSString *truncationMarker = [description length] > length ? @"..." : @"";
        [self.issueTransport send:[[description substringToIndex:toIndex] stringByAppendingString:truncationMarker]
                      description:self.descriptionField.text
                           images:self.attachments
                          payload:payloadData
                           fields:customFields];
    }

    [payloadData release];
    [customFields release];
}

-(void) dismissActivity
{
    [[self activityView] stopAnimating];
}

- (void)transportDidFinish:(NSString *)response
{
    [self dismissActivity];
    [self dismissModalViewControllerAnimated:YES];

    self.descriptionField.text = @"";
    [self.attachments removeAllObjects];
    [self.toolbar setItems:systemToolbarItems];

    // response needs to be an Issue.json... so we can insert one here.
    NSDictionary *responseDict = [response JSONValue];
    JMCIssue *issue = [[JMCIssue alloc] initWithDictionary:responseDict];
    [[JMCIssueStore instance] insertOrUpdateIssue:issue]; // newly created issues have no comments
    // anounce that an issue was added, so the JMCIssuesView can redraw

    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kJMCNewIssueCreated object:nil]];
    [issue release];
}

- (void)transportDidFinishWithError:(NSError *)error
{
    [self dismissActivity];
}

#pragma mark end

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
//    return YES;
}

#pragma mark -
#pragma mark CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    @synchronized (self) {
        [self setCurrentLocation:newLocation];
    }
}

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
//    NSLog(@"Location failed with error: %@", [error localizedDescription]);
}

#pragma mark -
#pragma mark CRVActivityViewDelegate
- (void)userDidCancelActivity
{
    [[self issueTransport] cancel];
}

#pragma mark -
#pragma mark Private Methods
- (BOOL)shouldTrackLocation {
    return sendLocationData && [CLLocationManager locationServicesEnabled];
}

#pragma mark -
#pragma mark Memory Managment

@synthesize descriptionField, countdownView, progressView, imagePicker, currentLocation, activityView;

@synthesize issueTransport = _issueTransport, replyTransport = _replyTransport, payloadDataSource = _payloadDataSource, attachments = _attachments, recorder = _recorder, replyToIssue = _replyToIssue;
@synthesize toolbar;
@synthesize voiceButton = _voiceButton;


- (void)dealloc
{
    // Release any retained subviews of the main view.
    [self internalRelease];
    // these ivars are retained in init
    self.issueTransport = nil;
    self.replyTransport = nil;
    self.recorder = nil;
    [super dealloc];
}

- (void)viewDidUnload
{
    // Release any retained subviews of the main view.
    [self internalRelease];
    [super viewDidUnload];
}

- (void)internalRelease
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if(_locationManager) {
      [_locationManager release];
    }
    [systemToolbarItems release];
    self.voiceButton = nil;
    self.toolbar = nil;
    self.imagePicker = nil;
    self.attachments = nil;
    self.progressView = nil;
    self.replyToIssue = nil;
    self.countdownView = nil;
    self.descriptionField = nil;
    self.payloadDataSource = nil;
    self.currentLocation = nil;
    self.activityView = nil;
}

@end
