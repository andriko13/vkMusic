//
//  DoingViewController.m
//  vkMusic
//
//  Created by Andriy Suden on 2/22/16.
//  Copyright © 2016 DropGeeks. All rights reserved.
//

#import "DoingViewController.h"
#import "TableViewCell.h"
#import "AppDelegate.h"

@interface DoingViewController (){
    NSMutableArray *_vkmusic;
    //UIProgressView *_progress;
    NSMutableData *_receivedData;
    long long _expectedBytes;
    NSString *_fileName;
    
    NSString *_songTitle;
}
@end

@implementation DoingViewController
@synthesize _musicTable;
@synthesize _progress;
@synthesize _downloadLabel;
@synthesize _delegate;

#pragma mark view config

- (void)viewDidLoad {
    
    _progress.hidden = YES;
    _downloadLabel.hidden = YES;

    self._delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    [super viewDidLoad];
    _vkmusic = [[NSMutableArray alloc] initWithCapacity:30];
    // Do any additional setup after loading the view.
    
    VKRequest *req;
    unsigned long uid = [self._delegate getFriend];
    NSString *u_id = [NSString stringWithFormat:@"%lu",uid];
    NSLog(@"OUR UID: %lu",uid);
    if (!uid) req = [VKRequest requestWithMethod:@"audio.get" andParameters:nil andHttpMethod:@"GET" classOfModel:[VKAudios class]];
    else {
        req = [VKRequest requestWithMethod:@"audio.get" andParameters:@{VK_API_USER_ID : @(uid)} andHttpMethod:@"GET" classOfModel:[VKAudios class]];
    }
    [req executeWithResultBlock:^(VKResponse *response) {
        for (NSDictionary *a in [response.json objectForKey:@"items"]) {
            VKAudio *s = [VKAudio new];
            s.artist = [a objectForKey:@"artist"];
            s.duration = [a objectForKey:@"duration"];
            s.genre_id = [a objectForKey:@"genre_id"];
            s.id = [a objectForKey:@"id"];
            s.owner_id = [a objectForKey:@"owner_id"];
            s.title = [a objectForKey:@"title"];
            s.url = [a objectForKey:@"url"];
            [_vkmusic addObject:s];
            NSLog(@"%@", s);
        }
        [_musicTable reloadData];
    } errorBlock:^(NSError *err){
        if (err.code != VK_API_ERROR) {
            [err.vkError.request repeat];
        } else {
            NSLog(@"VK error: %@", err);
            [[[UIAlertView alloc] initWithTitle:nil message:[NSString stringWithFormat:@"Access to user's music denied!"] delegate:self cancelButtonTitle:@"Go Back" otherButtonTitles:nil] show];
        }
    }];
}

#pragma mark Memory Warning

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Table methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    // The header for the section is the region name -- get this from the region at the section index.
    return [NSString stringWithFormat:@"Your VK Music"];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_vkmusic count];
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *MyIdentifier = @"MyReuseIdentifier";
    TableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
    if (cell == nil) {
        cell = [[TableViewCell alloc] initWithStyle:UITableViewCellStyleDefault  reuseIdentifier:MyIdentifier];
    }
    
    VKAudio *song = [_vkmusic objectAtIndex:indexPath.row];
    [cell._title setText:[NSString stringWithFormat:@"%@",song.title]];
    NSString *url = [self parseMp3:song];
    cell._url = url;
    
//    cell.textLabel.text = song.title;
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if (cell.selectionStyle != UITableViewCellSelectionStyleNone) {
        //(your code opening a new view)
        VKAudio *song = [_vkmusic objectAtIndex:indexPath.row];
        NSString *url = [self parseMp3:song];
        
        NSArray       *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString  *documentsDirectory = [paths objectAtIndex:0];
        
        _songTitle = [song.title stringByAppendingString:@".mp3"];
        _fileName = [NSString stringWithFormat:@"%@/music/%@", documentsDirectory,_songTitle];
        
        [self downloadFromURL:url name:_songTitle];
    }
}

-(NSString *)parseMp3:(VKAudio const*)song{
    NSString *fullPath = [NSString stringWithFormat:@"%@", song.url];
    
    NSRange rangeOfMp3 = [fullPath rangeOfString:@".mp3"];
    NSUInteger length = rangeOfMp3.length + rangeOfMp3.location;
    NSString *str = [fullPath substringToIndex:length];
    
    NSLog(@"%@",fullPath);
    if (str) return str;
    return nil;
}

-(void)downloadFromURL:(NSString *)urlToDownload name:(NSString *)fileName{
    NSLog(@"Downloading Started");
    NSURL  *url = [NSURL URLWithString:urlToDownload];
    
    NSURLRequest *theRequest = [NSURLRequest requestWithURL:url         cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60];
    _receivedData = [[NSMutableData alloc] initWithLength:0];
    NSURLConnection * connection __unused = [[NSURLConnection alloc] initWithRequest:theRequest delegate:self     startImmediately:YES];
}


- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSLog(@"Received response from connection");
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    _progress.hidden = NO;
    _downloadLabel.hidden = NO;
    [_receivedData setLength:0];
    _expectedBytes = [response expectedContentLength];
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    NSLog(@"Received data from connection");
    [_receivedData appendData:data];
    float progressive = (float)[_receivedData length] / (float)_expectedBytes;
    [_progress setProgress:progressive];
    
    
}

- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"Download Failed");
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
}

- (NSCachedURLResponse *) connection:(NSURLConnection *)connection willCacheResponse:    (NSCachedURLResponse *)cachedResponse {
    return nil;
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection {
    //NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    
    //NSString *documentsDirectory = [paths objectAtIndex:0];
    //NSString *pdfPath = [documentsDirectory stringByAppendingPathComponent:[currentURL stringByAppendingString:@".mp3"]];
    NSLog(@"Succeeded! Received %d bytes of data",[_receivedData length]);
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [_receivedData writeToFile:_fileName atomically:YES];
    _progress.hidden = YES;
    _downloadLabel.hidden = YES;
    [self._delegate fileDidDownload:_songTitle];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)backMainButton:(id)sender {
    [self performSegueWithIdentifier:@"backMain" sender:self];
}
@end
