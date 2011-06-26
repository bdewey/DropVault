//
//  DVCacheManager.m
//  DropVault
//
//  Created by Brian Dewey on 3/7/11.
//  Copyright 2011 Brian Dewey. 
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

#import "DVCacheManager.h"

static NSString *cacheRoot_;
static NSArray *cacheRootComponents_;


@implementation DVCacheManager

#pragma mark Properties

@synthesize delegate = delegate_;
@synthesize restClient = restClient_;
@synthesize metadata = metadata_;

//
//  PRIVATE: Create the containing directory for a path.
//

- (void)createContainingDirectoryForPath:(NSString *)path {
  [[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent]
                            withIntermediateDirectories:YES 
                                             attributes:nil 
                                                  error:NULL];
}

//
//  PRIVATE: Get the tombstones array, creating it if necessary.
//

- (NSMutableArray *)tombstones {
  
  if (tombstones_ == nil) {
    tombstones_ = [[NSMutableArray alloc] init];
  }
  return tombstones_;
}

//
//  PRIVATE: Get the pending uploads array, creating it if necessary.
//

- (NSMutableArray *)pendingUploads {
  
  if (pendingUploads_ == nil) {
    pendingUploads_ = [[NSMutableArray alloc] init];
  }
  return pendingUploads_;
}

//
//  PRIVATE: Archive the metadata object.
//

- (void)archiveMetadata {
  
  NSString *archivePath = [[[DVCacheManager cacheRoot] stringByDeletingLastPathComponent]
                           stringByAppendingPathComponent:@"metadata.dat"];
  [NSKeyedArchiver archiveRootObject:self.metadata toFile:archivePath];
}

//
//  PRIVATE: Recover the metadata archive.
//

- (void)recoverMetadata {
  
  NSString *archivePath = [[[DVCacheManager cacheRoot] stringByDeletingLastPathComponent]
                           stringByAppendingPathComponent:@"metadata.dat"];
  self.metadata = [NSKeyedUnarchiver unarchiveObjectWithFile:archivePath];
}

//
//  PRIVATE: Save the tombstones.
//

- (void)saveTombstones {
  
  NSString *tombstonePath = [[[DVCacheManager cacheRoot] stringByDeletingLastPathComponent]
                             stringByAppendingPathComponent:@"tombstone.dat"];
  [[self tombstones] writeToFile:tombstonePath atomically:YES];
}

//
//  PRIVATE: Load the tombstones.
//

- (void)loadTombstones {
  
  NSString *tombstonePath = [[[DVCacheManager cacheRoot] stringByDeletingLastPathComponent]
                             stringByAppendingPathComponent:@"tombstone.dat"];
  tombstones_ = [[NSMutableArray arrayWithContentsOfFile:tombstonePath] retain];
}

//
//  PRIVATE: Save the pending uploads.
//

- (void)savePendingUploads {
  
  NSString *path = [[[DVCacheManager cacheRoot] stringByDeletingLastPathComponent]
                             stringByAppendingPathComponent:@"pendingUploads.dat"];
  [[self pendingUploads] writeToFile:path atomically:YES];
  _GTMDevLog(@"%s -- just saved pending uploads: %@", 
             __PRETTY_FUNCTION__,
             [[self pendingUploads] description]);
}

//
//  PRIVATE: Load the pending uploads.
//

- (void)loadPendingUploads {
  
  NSString *path = [[[DVCacheManager cacheRoot] stringByDeletingLastPathComponent]
                    stringByAppendingPathComponent:@"pendingUploads.dat"];
  pendingUploads_ = [[NSMutableArray arrayWithContentsOfFile:path] retain];
}

#pragma mark Lifecycle Management

//
//  Initialization. Ensure that |self.cacheRoot| exists.
//

- (id)init {
  
  if ((self = [super init]) != nil) {
    [DVCacheManager createCacheRootDirectory];
    [self recoverMetadata];
    [self loadTombstones];
    [self loadPendingUploads];
  }
  return self;
}

- (void)dealloc {
  [metadata_ release];
  [restClient_ release];
  [tombstones_ release];
  [pendingUploads_ release];
  [super dealloc];
}

//
//  Gets or creates the |DBRestClient| object for communicating with DropBox.
//

- (DBRestClient *)restClient {
  if (restClient_ == nil) {
    restClient_ = [[DBRestClient alloc] initWithSession:[DBSession sharedSession]];
    restClient_.delegate = self;
  }
  return restClient_;
}


#pragma mark Loading metadata

- (IBAction)loadMetadata {
  [self.restClient loadMetadata:kDropVaultPath];
}

//
//  Successfully loaded metadata. Remember it and let the delegate know.
//

- (void)restClient:(DBRestClient *)client loadedMetadata:(DBMetadata *)metadata {
  self.metadata = metadata;
  [self archiveMetadata];
  if ([delegate_ respondsToSelector:@selector(cacheManagerDidLoadMetadata:)]) {
    [delegate_ cacheManagerDidLoadMetadata:self];
  }
}

//
//  Failed to load metadata. Let the delegate know.
//

- (void)restClient:(DBRestClient *)client loadMetadataFailedWithError:(NSError *)error {
  if ([delegate_ respondsToSelector:@selector(cacheManagerLoadMetadataFailed:)]) {
    [delegate_ cacheManagerLoadMetadataFailed:self];
  }
}

//
//  The cache root is the |NSCachesDirectory| *plus* |@"DropBoxCache"|.
//  This is where all cached DropBox content will be stored.
//  (The archived metadata will go straight into |NSCachesDirectory|. The
//  @"DropBoxCache" path component is there to make sure that there can never
//  be a name conflict with the archived metadata.)
//

+ (NSString *)cacheRoot {
  if (cacheRoot_ == nil) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, 
                                                         NSUserDomainMask, 
                                                         YES);
    cacheRoot_ = [[[paths objectAtIndex:0] 
                   stringByAppendingPathComponent:@"DropBoxCache"] 
                  retain];
  }
  return cacheRoot_;
}

//
//  PRIVATE: Gets the path components of |self.cacheRoot|.
//

+ (NSArray *)cacheRootComponents {
  if (cacheRootComponents_ == nil) {
    cacheRootComponents_ = [[[self cacheRoot] pathComponents] retain];
  }
  return cacheRootComponents_;
}

//
//  Makes sure that the |cacheRoot| directory exists.
//

+ (void)createCacheRootDirectory {
  [[NSFileManager defaultManager] createDirectoryAtPath:[DVCacheManager cacheRoot]
                            withIntermediateDirectories:YES 
                                             attributes:nil 
                                                  error:NULL];
}

//
//  Gets the path to the local cached file for a DropBox file.
//

+ (NSString *)cachePathForDropBoxPath:(NSString *)path {

  NSArray *components = [[DVCacheManager cacheRootComponents] arrayByAddingObjectsFromArray:[path pathComponents]];
  NSString *cachePath = [[NSString pathWithComponents:components] stringByStandardizingPath];
  return cachePath;
}

//
//  Gets the DropBox path corresponding to a local cache file.
//

+ (NSString *)dropBoxPathForCachePath:(NSString *)path {
  
  return [path stringByReplacingOccurrencesOfString:cacheRoot_ withString:@""];
}

//
//  Gets the metadata entry corresponding to a path. Returns |nil| if none found.
//

- (DBMetadata *)metadataForPath:(NSString *)path {
  
  NSUInteger index = [metadata_.contents indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop) {
    if ([[DVCacheManager cachePathForDropBoxPath:[obj path]] isEqualToString:path]) {
      *stop = YES;
      return YES;
    }
    return NO;
  }];
  if (index != NSNotFound) {
    return [metadata_.contents objectAtIndex:index];
  }
  return nil;
}

//
//  Determines if the cached copy of |path| is up to date relative to the
//  DropBox copy.
//

- (DVCacheState)cacheStateForPath:(NSString *)path {
  
  NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path 
                                                                              error:NULL];
  DBMetadata *dbMetadata = [self metadataForPath:path];
  
  if ((attributes == nil) && (dbMetadata == nil)) {
    
    return DVCacheStateDoesNotExist;
  }
  _GTMDevLog(@"%s -- pending uploads is %@", 
             __PRETTY_FUNCTION__, 
             [[self pendingUploads] description]);
  
  //
  //  Alas, |path| is a path into the cache, and |pendingUploads| stores DropBox
  //  paths. So look through everything in |pendingUploads| to see if any have
  //  a cachePath that is equal to |path|.
  //
  
  NSUInteger index = [[self pendingUploads] indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop) {
    if ([[DVCacheManager cachePathForDropBoxPath:obj] isEqualToString:path]) {
      *stop = YES;
      return YES;
    }
    return NO;
  }];
  if (index != NSNotFound) {
    
    return DVCacheStatePendingUpload;
  }
  if (dbMetadata == nil) {
    
    return DVCacheStateOnlyLocal;
  }
  if ([[self tombstones] containsObject:dbMetadata.path]) {
  
    return DVCacheStateTombstone;
  }
  if (attributes == nil) {
    
    return DVCacheStateOnlyDropBox;
  }
  
  NSDate *fileDate = [attributes fileModificationDate];
  NSDate *metadataDate = dbMetadata.lastModifiedDate;
  
  _GTMDevLog(@"%s -- file date is %@, metadata date is %@", 
             __PRETTY_FUNCTION__, 
             fileDate, 
             metadataDate);
  
  switch ([fileDate compare:metadataDate]) {
    case NSOrderedAscending:
      return DVCacheStateDropBoxLatest;
      
    case NSOrderedDescending:
      return DVCacheStateLocalLatest;
      
    case NSOrderedSame:
      return DVCacheStateEquivalent;
  }
  
  _GTMDevAssert(NO, @"Shouldn't get here");
  return DVCacheStateEquivalent;
}

#pragma mark -
#pragma mark Caching file content

- (IBAction)cacheCopyOfDropBoxPath:(NSString *)path {
  
  NSString *cachePath = [DVCacheManager cachePathForDropBoxPath:path];
  [self createContainingDirectoryForPath:cachePath];
  DVCacheState cacheState = [self cacheStateForPath:cachePath];
  switch (cacheState) {
    case DVCacheStateLocalLatest:
    case DVCacheStateEquivalent:
    case DVCacheStateOnlyLocal:
      
      //
      //  DropBox doesn't have anything new for us. Just go straight to the 
      //  delegate.
      //
      
      if ([delegate_ respondsToSelector:@selector(cacheManager:didCacheCopyOfFile:)]) {
        [delegate_ cacheManager:self didCacheCopyOfFile:cachePath];
      }
      break;
      
    default:
      
      //
      //  We need to get updated information from DropBox.
      //
      
      [self.restClient loadFile:path intoPath:cachePath];
  }
}

//
//  Pass through download progress notifications to the delegate.
//

- (void)restClient:(DBRestClient *)client loadProgress:(CGFloat)progress forFile:(NSString *)destPath {
  
  if ([delegate_ respondsToSelector:@selector(cacheManager:loadProgress:forFile:)]) {
    [delegate_ cacheManager:self loadProgress:progress forFile:destPath];
  }
}

- (void)restClient:(DBRestClient *)client loadedFile:(NSString *)destPath {
  
  //
  //  Try to update the last modified time of |destPath| to match the value in
  //  the DropBox metadata.
  //
  
  DBMetadata *md = [self metadataForPath:destPath];
  if (md != nil) {
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[md lastModifiedDate], NSFileModificationDate, nil];
    [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:destPath error:NULL];
  }
  
  //
  //  Notify the delegate that the download succeeded.
  //
  
  if ([delegate_ respondsToSelector:@selector(cacheManager:didCacheCopyOfFile:)]) {
    [delegate_ cacheManager:self didCacheCopyOfFile:destPath];
  }
}

//
//  Failed to get a DropBox path. Let the delegate know.
//

- (void)restClient:(DBRestClient *)client loadFileFailedWithError:(NSError *)error {
  
  if ([delegate_ respondsToSelector:@selector(cacheManager:didFailCacheOfFile:)]) {
    NSString *path = [[error userInfo] objectForKey:@"sourcePath"];
    [delegate_ cacheManager:self didFailCacheOfFile:path];
  }
}

#pragma mark Deleting files

- (IBAction)deleteDropBoxPath:(NSString *)path {
  
  //
  //  Delete the local cached copy.
  //
  
  NSString *cachePath = [DVCacheManager cachePathForDropBoxPath:path];
  [[NSFileManager defaultManager] removeItemAtPath:cachePath error:NULL];
  
  //
  //  Remember this on the tombstone list until we get confirmation that 
  //  the DropBox copy was also deleted.
  //
  
  [[self tombstones] addObject:path];
  [self saveTombstones];
  
  //
  //  And now try to delete the DropBox copy.
  //
  
  [self.restClient deletePath:path];
}

- (void)restClient:(DBRestClient *)client deletedPath:(NSString *)path {
  
  [[self tombstones] removeObject:path];
  [self saveTombstones];
  
  //
  //  Reload our metadata.
  //
  
  [self loadMetadata];
}

- (void)restClient:(DBRestClient *)client deletePathFailedWithError:(NSError *)error {
  
}

#pragma mark Uploading files

- (IBAction)uploadCacheToDropBoxPath:(NSString *)path {
  
  NSString *cachePath = [DVCacheManager cachePathForDropBoxPath:path];
  if (![[NSFileManager defaultManager] fileExistsAtPath:cachePath]) {
    
    //
    //  Error: There is no file to upload.
    //
    
    if ([delegate_ respondsToSelector:@selector(cacheManager:didFailUploadOfFile:)]) {
      [delegate_ cacheManager:self didFailUploadOfFile:path];
    }
    return;
  }
  
  //
  //  And remember the pending upload.
  //
  
  [[self pendingUploads] addObject:path];
  [self savePendingUploads];
  
  //
  //  Upload to DropBox.
  //
  
  _GTMDevLog(@"%s -- uploading %@", __PRETTY_FUNCTION__, path);
  [self.restClient uploadFile:[path lastPathComponent] 
                       toPath:[path stringByDeletingLastPathComponent]
                     fromPath:cachePath];
}

//
//  Successful upload.
//

- (void)restClient:(DBRestClient *)client uploadedFile:(NSString *)destPath from:(NSString *)srcPath {
  _GTMDevAssert([[self pendingUploads] containsObject:destPath], 
                @"We should be expecting %@ in %@",
                destPath,
                [[self pendingUploads] description]);
  [[self pendingUploads] removeObject:destPath];
  [self savePendingUploads];
  if ([delegate_ respondsToSelector:@selector(cacheManager:didUploadFile:)]) {
    [delegate_ cacheManager:self didUploadFile:destPath];
  }
}

//
//  The upload failed. Tell the delegate.
//

- (void)restClient:(DBRestClient *)client uploadFileFailedWithError:(NSError *)error {

  if ([delegate_ respondsToSelector:@selector(cacheManager:didFailUploadOfFile:)]) {
    NSString *path = [[error userInfo] objectForKey:@"sourcePath"];
    [delegate_ cacheManager:self didFailUploadOfFile:path];
  }
}

@end
