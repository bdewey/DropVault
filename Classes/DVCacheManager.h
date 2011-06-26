//
//  DVCacheManager.h
//  DropVault
//
//  This class manages the local cache of DropBox content.
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

#import <Foundation/Foundation.h>
#import "DropboxSDK.h"

//
//  The different states that a file in the cache can be in.
//

typedef enum {
  
  //
  //  The file doesn't exist, either locally or on DropBox.
  //
  
  DVCacheStateDoesNotExist,
  
  //
  //  The file is only local--there isn't a DropBox equivalent.
  //
  
  DVCacheStateOnlyLocal,
  
  //
  //  The file is local AND pending an upload to DropBox.
  //
  
  DVCacheStatePendingUpload,
  
  //
  //  The file is only on DropBox. It hasn't been cached.
  //
  
  DVCacheStateOnlyDropBox,
  
  //
  //  The file has been deleted locally, and we're still waiting to make the
  //  corresponding deletion from DropBox.
  //
  
  DVCacheStateTombstone,
  
  //
  //  The file exists both locally and on DropBox, and the local file has a
  //  greater last modified time than DropBox.
  //
  
  DVCacheStateLocalLatest,
  
  //
  //  The file exists both locally and on DropBox, and the DropBox file has a
  //  greater last modified time than local.
  //
  
  DVCacheStateDropBoxLatest,
  
  //
  //  The file exists both locally and on DropBox, and they have the same
  //  last modified time.
  //
  
  DVCacheStateEquivalent
} DVCacheState;

@protocol DVCacheManagerDelegate;
@interface DVCacheManager : NSObject<DBRestClientDelegate> {
  @private
  id<DVCacheManagerDelegate> delegate_;
  DBRestClient *restClient_;
  DBMetadata *metadata_;
  NSMutableArray *tombstones_;
  NSMutableArray *pendingUploads_;
}

//  ----------------------------------------------------------------------------
//  Properties

//
//  The delegate for the cache manager.
//

@property (nonatomic, assign) id<DVCacheManagerDelegate> delegate;

//
//  The DropBox RestClient we use for communicating with the DropBox service.
//

@property (nonatomic, retain) DBRestClient *restClient;

//
//  This is the metadata for the DropVault directory.
//

@property (nonatomic, retain) DBMetadata *metadata;

//  ----------------------------------------------------------------------------
//  Class methods

//
//  Gets the path to the local cached file for a DropBox file.
//

+ (NSString *)cachePathForDropBoxPath:(NSString *)path;

//
//  Gets the DropBox path corresponding to a cache path.
//

+ (NSString *)dropBoxPathForCachePath:(NSString *)path;

//
//  Gets the cache root.
//

+ (NSString *)cacheRoot;

//
//  Gets the components of |cacheRoot|.
//

+ (NSArray *)cacheRootComponents;

//
//  Makes sure that |cacheRoot| exists. Called by default when creating a 
//  |DVCacheManager|, so you often don't need to call this.
//

+ (void)createCacheRootDirectory;


//  ----------------------------------------------------------------------------
//  Actions

//
//  Update the metadata.
//

- (IBAction)loadMetadata;

//
//  Finds the DBMetadata record that matches a specific file in the cache.
//  Returns |nil| if none found.
//

- (DBMetadata *)metadataForPath:(NSString *)path;

//
//  Cache a copy of a DropBox file.
//

- (IBAction)cacheCopyOfDropBoxPath:(NSString *)path;

//
//  Delete a file, from the cache and from DropBox.
//

- (IBAction)deleteDropBoxPath:(NSString *)path;

//
//  Upload the cached copy of a file to DropBox.
//

- (IBAction)uploadCacheToDropBoxPath:(NSString *)path;

//
//  Determines if the cached copy of |path| is up to date relative to the
//  DropBox copy.
//

- (DVCacheState)cacheStateForPath:(NSString *)path;

@end

//  ----------------------------------------------------------------------------
//
//  This protocol is all of the messages sent as part of cache maintenance.
//  All messages are optional.
//

@protocol DVCacheManagerDelegate <NSObject>

@optional

//
//  The cache manager successfully loaded metadata from DropBox.
//

- (void)cacheManagerDidLoadMetadata:(DVCacheManager *)cacheManager;

//
//  The cache manager was not able to load metadata from DropBox.
//

- (void)cacheManagerLoadMetadataFailed:(DVCacheManager *)cacheManager;

//
//  The cache manager successfully retreived a copy of a DropBox file.
//  Note that |path| is the path to the local cache copy, not the DropBox path.
//

- (void)cacheManager:(DVCacheManager *)cacheManager didCacheCopyOfFile:(NSString *)path;

//
//  The cache manager was unable to refresh its copy of a DropBox file.
//  Note that |path| is the path to the local cache copy, not the DropBox path.
//

- (void)cacheManager:(DVCacheManager *)cacheManager didFailCacheOfFile:(NSString *)path;

//
//  Reports progress on caching a file.
//

- (void)cacheManager:(DVCacheManager *)cacheManager loadProgress:(CGFloat)progress forFile:(NSString*)destPath;

//
//  File upload succeeded.
//

- (void)cacheManager:(DVCacheManager *)cacheManager didUploadFile:(NSString *)path;

//
//  File upload failed.
//

- (void)cacheManager:(DVCacheManager *)cacheManager didFailUploadOfFile:(NSString *)path;

@end