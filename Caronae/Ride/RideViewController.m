#import <AFNetworking/AFNetworking.h>
#import <CoreData/CoreData.h>
#import <SVProgressHUD/SVProgressHUD.h>
#import "CaronaeAlertController.h"
#import "ChatViewController.h"
#import "JoinRequestCell.h"
#import "Notification.h"
#import "NotificationStore.h"
#import "ProfileViewController.h"
#import "Ride.h"
#import "RideViewController.h"
#import "RiderCell.h"
#import "RideRequestsStore.h"
#import "SHSPhoneNumberFormatter+UserConfig.h"
#import "UIImageView+crn_setImageWithURL.h"
#import "Caronae-Swift.h"

@interface RideViewController ()
<
    JoinRequestDelegate,
    UITableViewDelegate,
    UITableViewDataSource,
    UICollectionViewDelegate,
    UICollectionViewDataSource,
    UIGestureRecognizerDelegate
>

@property (nonatomic) NSArray<User *> *joinRequests;
@property (nonatomic) NSArray<User *> *mutualFriends;
@property (nonatomic) User *selectedUser;
@property (nonatomic) UIColor *color;

@end

@implementation RideViewController

static NSString *CaronaeRequestButtonStateNew              = @"PEGAR CARONA";
static NSString *CaronaeRequestButtonStateAlreadyRequested = @"    SOLICITAÇÃO ENVIADA    ";
static NSString *CaronaeFinishButtonStateAlreadyFinished   = @"  Carona concluída";

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Carona";
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"HH:mm | E | dd/MM";
    NSString *dateString = [dateFormatter stringFromDate:_ride.date].capitalizedString;
    
    _titleLabel.text = [_ride.title uppercaseString];
    if (_ride.going) {
        _dateLabel.text = [NSString stringWithFormat:@"Chegando às %@", dateString];
    }
    else {
        _dateLabel.text = [NSString stringWithFormat:@"Saindo às %@", dateString];
    }
    
    if ([_ride.place isKindOfClass:[NSString class]] && [_ride.place isEqualToString:@""]) {
        _referenceLabel.text = @"---";
    }
    else {
        _referenceLabel.text = _ride.place;
    }

    _driverNameLabel.text = _ride.driver.name;
    _driverCourseLabel.text = _ride.driver.course.length > 0 ? [NSString stringWithFormat:@"%@ | %@", _ride.driver.profile, _ride.driver.course] : _ride.driver.profile;
    
    if ([_ride.route isKindOfClass:[NSString class]] && [_ride.route isEqualToString:@""]) {
        _routeLabel.text = @"---";
    }
    else {
        _routeLabel.text = [[_ride.route stringByReplacingOccurrencesOfString:@", " withString:@"\n"] stringByReplacingOccurrencesOfString:@"," withString:@"\n"];
    }
    
    if ([_ride.notes isKindOfClass:NSString.class] && [_ride.notes isEqualToString:@""]) {
        _driverMessageLabel.text = @"---";
    }
    else {
        _driverMessageLabel.text = _ride.notes;
    }
    
    if (_ride.driver.profilePictureURL.length > 0) {
        [_driverPhoto crn_setImageWithURL:[NSURL URLWithString:_ride.driver.profilePictureURL]];
    }
    
    self.color = [CaronaeConstants colorForZone:_ride.zone];
    
    UINib *cellNib = [UINib nibWithNibName:NSStringFromClass(JoinRequestCell.class) bundle:nil];
    [self.requestsTable registerNib:cellNib forCellReuseIdentifier:@"Request Cell"];
    self.requestsTable.dataSource = self;
    self.requestsTable.delegate = self;
    self.requestsTable.rowHeight = 95.0f;
    self.requestsTableHeight.constant = 0;
    
    // If the user is the driver of the ride, load pending join requests and hide 'join' button
    if ([self userIsDriver]) {
        [self loadJoinRequests];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.requestRideButton removeFromSuperview];
            [self.mutualFriendsView removeFromSuperview];
            [self.phoneView removeFromSuperview];
            
            if (!_ride.active) {
                [self.finishRideView removeFromSuperview];
            }
        });
        
        // Car details
        User *user = [UserController sharedInstance].user;
        _carPlateLabel.text = user.carPlate.uppercaseString;
        _carModelLabel.text = user.carModel;
        _carColorLabel.text = user.carColor;
        
        // If the riders aren't provided then hide the riders view
        if (!_ride.users) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.ridersView removeFromSuperview];
            });
        }
    }
    // If the user is already a rider, hide 'join' button
    else if ([self userIsRider]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.requestRideButton removeFromSuperview];
            [self.finishRideView removeFromSuperview];
        });
        
        [self.cancelButton setTitle:@"DESISTIR" forState:UIControlStateNormal];
        SHSPhoneNumberFormatter *phoneFormatter = [[SHSPhoneNumberFormatter alloc] init];
        [phoneFormatter setDefaultOutputPattern:Caronae8PhoneNumberPattern];
        [phoneFormatter addOutputPattern:Caronae9PhoneNumberPattern forRegExp:@"[0-9]{12}\\d*$"];
        NSDictionary *result = [phoneFormatter valuesForString:_ride.driver.phoneNumber];
        NSString *formattedPhoneNumber = result[@"text"];
        [_phoneButton setTitle:formattedPhoneNumber forState:UIControlStateNormal];
        
        // Car details
        _carPlateLabel.text = _ride.driver.carPlate.uppercaseString;
        _carModelLabel.text = _ride.driver.carModel;
        _carColorLabel.text = _ride.driver.carColor;
        
        [self updateMutualFriends];
    }
    // If the user is not related to the ride, hide 'cancel' button, car details view, riders view, chat button
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.cancelButton removeFromSuperview];
            [self.phoneView removeFromSuperview];
            [self.carDetailsView removeFromSuperview];
            [self.finishRideView removeFromSuperview];
            [self.ridersView removeFromSuperview];
        });
        
        // Hide driver's phone number
        _ride.driver.phoneNumber = nil;
        
        // Hide chat button
        self.navigationItem.rightBarButtonItem = nil;
        
        // Update the state of the join request button if the user has already requested to join
        if ([RideRequestsStore hasRequestedToJoinRide:_ride]) {
            _requestRideButton.enabled = NO;
            [_requestRideButton setTitle:CaronaeRequestButtonStateAlreadyRequested forState:UIControlStateNormal];
        }
        else {
            _requestRideButton.enabled = YES;
            [_requestRideButton setTitle:CaronaeRequestButtonStateNew forState:UIControlStateNormal];
        }
        
        [self updateMutualFriends];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.shouldOpenChatWindow) {
        [self openChatWindow];
        self.shouldOpenChatWindow = NO;
    }
}

- (void)setColor:(UIColor *)color {
    _color = color;
    _headerView.backgroundColor = color;
    _clockIcon.tintColor = color;
    _dateLabel.textColor = color;
    _driverPhoto.layer.borderColor = color.CGColor;
    _carIconPlate.tintColor = color;
    _carIconModel.tintColor = color;
    _carIconColor.tintColor = color;
    _finishRideButton.layer.borderColor = color.CGColor;
    _finishRideButton.tintColor = color;
    _requestRideButton.backgroundColor = color;
    [_finishRideButton setTitleColor:color forState:UIControlStateNormal];
}

- (BOOL)userIsDriver {
    return [[UserController sharedInstance].user.userID isEqualToNumber:_ride.driver.userID];
}

- (BOOL)userIsRider {
    for (User *user in _ride.users) {
        if ([user.userID isEqualToNumber:[UserController sharedInstance].user.userID]) {
            return YES;
        }
    }
    return NO;
}

- (void)updateMutualFriends {
    // Abort if the Facebook accounts are not connected.
    if (![UserController sharedInstance].userFBToken || _ride.driver.facebookID.length == 0) {
        return;
    }
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:[UserController sharedInstance].userToken forHTTPHeaderField:@"token"];
    [manager.requestSerializer setValue:[UserController sharedInstance].userFBToken forHTTPHeaderField:@"Facebook-Token"];
    
    [manager GET:[CaronaeAPIBaseURL stringByAppendingString:[NSString stringWithFormat:@"/user/%@/mutualFriends", _ride.driver.facebookID]] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSArray *mutualFriendsJSON = responseObject[@"mutual_friends"];
        int totalMutualFriends = [responseObject[@"total_count"] intValue];
        NSError *error;
        NSArray<User *> *mutualFriends = [MTLJSONAdapter modelsOfClass:User.class fromJSONArray:mutualFriendsJSON error:&error];
        
        if (error) {
            NSLog(@"Error parsing mutual friends. %@", error.localizedDescription);
        }
        
        if (mutualFriends.count > 0) {
            _mutualFriends = mutualFriends;
            _mutualFriendsCollectionHeight.constant = 40.0f;
            [_mutualFriendsView layoutIfNeeded];
            [_mutualFriendsCollectionView reloadData];
        }
        
        if (totalMutualFriends > 0) {
            _mutualFriendsLabel.text = [NSString stringWithFormat:@"Amigos em comum: %d no total e %d no Caronaê", totalMutualFriends, (int)mutualFriends.count];
        }
        else {
            _mutualFriendsLabel.text = @"Amigos em comum: 0";
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error loading mutual friends for user: %@", error.localizedDescription);
    }];
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ViewProfile"]) {
        ProfileViewController *vc = segue.destinationViewController;
        vc.user = self.selectedUser;
    }
}

- (void)openChatWindow {
    Chat *chat = [[ChatService sharedInstance] chatForRide:_ride];
    if (chat) {
        ChatViewController *chatVC = [[ChatViewController alloc] initWithChat:chat andColor:_color];
        [self.navigationController pushViewController:chatVC animated:YES];
    }
}

#pragma mark - IBActions

- (IBAction)didTapPhoneButton:(id)sender {
    NSString *phoneNumber = _ride.driver.phoneNumber;
    NSString *phoneNumberURLString = [NSString stringWithFormat:@"telprompt://%@", phoneNumber];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:phoneNumberURLString]];
}

- (IBAction)didTapRequestRide:(UIButton *)sender {
    CaronaeAlertController *alert = [CaronaeAlertController alertControllerWithTitle:@"Deseja mesmo solicitar a carona?"
                                                                             message:@"Ao confirmar, você estará ocupando uma vaga nesta carona."
                                                                      preferredStyle:SDCAlertControllerStyleAlert];
    [alert addAction:[SDCAlertAction actionWithTitle:@"Cancelar" style:SDCAlertActionStyleCancel handler:nil]];
    [alert addAction:[SDCAlertAction actionWithTitle:@"Solicitar" style:SDCAlertActionStyleRecommended handler:^(SDCAlertAction *action){
        [self requestJoinRide];
    }]];
    [alert presentWithCompletion:nil];
}

- (IBAction)viewUserProfile:(id)sender {
    self.selectedUser = _ride.driver;
    [self performSegueWithIdentifier:@"ViewProfile" sender:self];
}

- (IBAction)didTapCancelRide:(id)sender {
    CaronaeAlertController *alert = [CaronaeAlertController alertControllerWithTitle:@"Deseja mesmo desistir da carona?"
                                                                             message:@"Você é livre para cancelar caronas caso não possa participar, mas é importante fazer isso com responsabilidade. Caso haja outros usuários na carona, eles serão notificados."
                                                                      preferredStyle:SDCAlertControllerStyleAlert];
    [alert addAction:[SDCAlertAction actionWithTitle:@"Voltar" style:SDCAlertActionStyleCancel handler:nil]];
    [alert addAction:[SDCAlertAction actionWithTitle:@"Desistir" style:SDCAlertActionStyleDestructive handler:^(SDCAlertAction *action){
        [self cancelRide];
    }]];
    [alert presentWithCompletion:nil];
}

- (IBAction)didTapFinishRide:(id)sender {
    CaronaeAlertController *alert = [CaronaeAlertController alertControllerWithTitle:@"E aí? Correu tudo bem?"
                                                                             message:@"Caso você tenha tido algum problema com a carona, use o Falaê para entrar em contato conosco."
                                                                      preferredStyle:SDCAlertControllerStyleAlert];
    [alert addAction:[SDCAlertAction actionWithTitle:@"Cancelar" style:SDCAlertActionStyleCancel handler:nil]];
    [alert addAction:[SDCAlertAction actionWithTitle:@"Concluir" style:SDCAlertActionStyleRecommended handler:^(SDCAlertAction *action){
        [self finishRide];
    }]];
    [alert presentWithCompletion:nil];
}

- (IBAction)didTapChatButton:(id)sender {
    [self openChatWindow];
}


#pragma mark - Ride operations

- (void)cancelRide {
    NSLog(@"Requesting to leave/cancel ride %ld", _ride.rideID);
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:[UserController sharedInstance].userToken forHTTPHeaderField:@"token"];
    NSDictionary *params = @{@"rideId": @(_ride.rideID)};
    
    _cancelButton.enabled = NO;
    [SVProgressHUD show];
    
    [manager POST:[CaronaeAPIBaseURL stringByAppendingString:@"/ride/leaveRide"] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [SVProgressHUD dismiss];
        NSLog(@"User left the ride. (Message: %@)", responseObject[@"message"]);
        
        Chat *chat = [[ChatService sharedInstance] chatForRide:_ride];
        [[ChatService sharedInstance] unsubscribeFromChat:chat];
        [NotificationStore clearNotificationsForRide:@(_ride.rideID) ofType:NotificationTypeAll];
        
        if (_delegate && [_delegate respondsToSelector:@selector(didDeleteRide:)]) {
            [_delegate didDeleteRide:_ride];
        }
        
        [self.navigationController popViewControllerAnimated:YES];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error leaving/cancelling ride: %@", error.localizedDescription);
        [SVProgressHUD dismiss];
        _cancelButton.enabled = YES;
        [CaronaeAlertController presentOkAlertWithTitle:@"Algo deu errado." message:[NSString stringWithFormat:@"Não foi possível cancelar sua carona. (%@)", error.localizedDescription]];
    }];
}

- (void)finishRide {
    NSLog(@"Requesting to finish ride %ld", _ride.rideID);
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:[UserController sharedInstance].userToken forHTTPHeaderField:@"token"];
    NSDictionary *params = @{@"rideId": @(_ride.rideID)};
    
    _finishRideButton.enabled = NO;
    [SVProgressHUD show];
    
    [manager POST:[CaronaeAPIBaseURL stringByAppendingString:@"/ride/finishRide"] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {        [SVProgressHUD dismiss];
        NSLog(@"User finished the ride. (Message: %@)", responseObject[@"message"]);
        
        Chat *chat = [[ChatService sharedInstance] chatForRide:_ride];
        [[ChatService sharedInstance] unsubscribeFromChat:chat];
        [NotificationStore clearNotificationsForRide:@(_ride.rideID) ofType:NotificationTypeAll];
        
        if (_delegate && [_delegate respondsToSelector:@selector(didFinishRide:)]) {
            [_delegate didFinishRide:_ride];
        }
        
        [self.navigationController popViewControllerAnimated:YES];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error finishing ride: %@", error.localizedDescription);
        [SVProgressHUD dismiss];
        _finishRideButton.enabled = YES;
        [CaronaeAlertController presentOkAlertWithTitle:@"Algo deu errado." message:[NSString stringWithFormat:@"Não foi possível concluir sua carona. (%@)", error.localizedDescription]];
    }];
}


#pragma mark - Join request methods

- (void)requestJoinRide {
    NSLog(@"Requesting to join ride %ld", _ride.rideID);
    NSDictionary *params = @{@"rideId": @(_ride.rideID)};
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:[UserController sharedInstance].userToken forHTTPHeaderField:@"token"];
    
    _requestRideButton.enabled = NO;
    [SVProgressHUD show];
    
    [manager POST:[CaronaeAPIBaseURL stringByAppendingString:@"/ride/requestJoin"] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [SVProgressHUD dismiss];
        NSLog(@"Done requesting ride. (Message: %@)", responseObject[@"message"]);
        [RideRequestsStore setRideAsRequested:_ride];
        [_requestRideButton setTitle:CaronaeRequestButtonStateAlreadyRequested forState:UIControlStateNormal];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [SVProgressHUD dismiss];
        NSLog(@"Error requesting to join ride: %@", error.localizedDescription);
        _requestRideButton.enabled = YES;
        [CaronaeAlertController presentOkAlertWithTitle:@"Algo deu errado." message:[NSString stringWithFormat:@"Não foi possível solicitar a carona. (%@)", error.localizedDescription]];
    }];
}

- (void)loadJoinRequests {
    long rideID = _ride.rideID;
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:[UserController sharedInstance].userToken forHTTPHeaderField:@"token"];
    
    [manager GET:[CaronaeAPIBaseURL stringByAppendingString:[NSString stringWithFormat:@"/ride/getRequesters/%ld", rideID]] parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        NSError *error;
        NSArray<User *> *joinRequests = [MTLJSONAdapter modelsOfClass:User.class fromJSONArray:responseObject error:&error];
        
        if (!error) {
            self.joinRequests = joinRequests;
            if (joinRequests.count > 0) {
                [self.requestsTable reloadData];
                [self adjustHeightOfTableview];
            }
            
            [NotificationStore clearNotificationsForRide:@(self.ride.rideID) ofType:NotificationTypeRequest];
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error loading join requests for ride %lu: %@", rideID, error.localizedDescription);
        [CaronaeAlertController presentOkAlertWithTitle:@"Algo deu errado." message:[NSString stringWithFormat:@"Não foi possível carregar as solicitações da sua carona. (%@)", error.localizedDescription]];
    }];
}

- (void)joinRequest:(User *)requestingUser hasAccepted:(BOOL)accepted cell:(JoinRequestCell *)cell {
    NSLog(@"Request for user %@ was %@", requestingUser.name, accepted ? @"accepted" : @"not accepted");
    NSDictionary *params = @{@"userId": requestingUser.userID,
                             @"rideId": @(_ride.rideID),
                             @"accepted": @(accepted)};
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.requestSerializer = [AFJSONRequestSerializer serializer];
    [manager.requestSerializer setValue:[UserController sharedInstance].userToken forHTTPHeaderField:@"token"];
    
    [cell setButtonsEnabled:NO];
    
    [manager POST:[CaronaeAPIBaseURL stringByAppendingString:@"/ride/answerJoinRequest"] parameters:params success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"Answer to join request successfully sent.");
        [self removeJoinRequest:requestingUser];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error accepting join request: %@", error.localizedDescription);
        [cell setButtonsEnabled:YES];
    }];
}

- (void)removeJoinRequest:(User *)requestingUser {
    NSMutableArray *joinRequestsMutable = [NSMutableArray arrayWithArray:self.joinRequests];
    [joinRequestsMutable removeObject:requestingUser];
    
    [self.requestsTable beginUpdates];
    unsigned long index = [self.joinRequests indexOfObject:requestingUser];
    [self.requestsTable deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:index inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
    self.joinRequests = joinRequestsMutable;
    [self.requestsTable endUpdates];
    [self adjustHeightOfTableview];
}

- (void)tappedUserDetailsForRequest:(User *)user {
    self.selectedUser = user;
    [self performSegueWithIdentifier:@"ViewProfile" sender:self];
}


#pragma mark - Table methods (Join requests)

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.joinRequests.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    JoinRequestCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Request Cell" forIndexPath:indexPath];
    
    cell.delegate = self;
    [cell configureCellWithUser:self.joinRequests[indexPath.row]];
    [cell setColor:self.color];
    
    return cell;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(15, 8, 300, 20)];
    label.font = [UIFont boldSystemFontOfSize:13.0f];
    label.text = @"PEDIDOS DE CARONA";
    
    UIView *headerView = [[UIView alloc] init];
    [headerView addSubview:label];
    
    return headerView;
}

- (void)adjustHeightOfTableview {
    [self.view layoutIfNeeded];
    CGFloat height = self.joinRequests.count > 0 ? self.requestsTable.contentSize.height : 0;
    self.requestsTableHeight.constant = height;
    [UIView animateWithDuration:0.25 animations:^{
        [self.view layoutIfNeeded];
    }];
}


#pragma mark - Collection methods (Riders)

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    if (collectionView == _ridersCollectionView) {
        return _ride.users.count;
    }
    else {
        return _mutualFriends.count;
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    RiderCell *cell;
    User *user;
    
    if (collectionView == _ridersCollectionView) {
        user = _ride.users[indexPath.row];
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"Rider Cell" forIndexPath:indexPath];
    }
    else {
        user = _mutualFriends[indexPath.row];
        user.phoneNumber = nil;
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"Friend Cell" forIndexPath:indexPath];
    }
    
    cell.user = user;
    cell.nameLabel.text = user.firstName;
    
    if (user.profilePictureURL.length > 0) {
        [cell.photo crn_setImageWithURL:[NSURL URLWithString:user.profilePictureURL]];
    }
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
    
    if (collectionView == _ridersCollectionView) {
        RiderCell *cell = (RiderCell *)[collectionView cellForItemAtIndexPath:indexPath];
        self.selectedUser = cell.user;
        
        [self performSegueWithIdentifier:@"ViewProfile" sender:self];
    }
}

@end
