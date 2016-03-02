//
//  NUPubNubManager.m
//  NextUserKit
//
//  Created by Dino on 2/9/16.
//  Copyright © 2016 NextUser. All rights reserved.
//

#import "NUPubNubClient.h"
#import "PubNub.h"

@interface NUPubNubClient () <PNObjectEventListener>

@property (nonatomic) PubNub *client;

@end

@implementation NUPubNubClient

- (id)initWithSession:(NUTrackerSession *)session
{
    if (self = [super initWithSession:session]) {
        
        NSString *publishKey = nil;
        NSString *subscribeKey = nil;
        PNConfiguration *configuration = [PNConfiguration configurationWithPublishKey:publishKey
                                                                         subscribeKey:subscribeKey];
        self.client = [PubNub clientWithConfiguration:configuration];
        [self.client addListener:self];

        
//        PNChannel *channel = [PNChannel channelWithName:@"demo_tutorial"];

    }
    
    return self;
}

#pragma mark - Override (Subclass category)

- (void)startListening
{
    [self subscribeToChannel:nil];
}

- (void)stopListening
{
    [self unsubscribeFromChannel:nil];
}

- (void)fetchMissedMessages
{
    [self.client historyForChannel: @"my_channel" start:nil end:nil limit:100
                    withCompletion:^(PNHistoryResult *result, PNErrorStatus *status) {
                        
                        // Check whether request successfully completed or not.
                        if (!status.isError) {
                            
                            // Handle downloaded history using:
                            //   result.data.start - oldest message time stamp in response
                            //   result.data.end - newest message time stamp in response
                            //   result.data.messages - list of messages
                        }
                        // Request processing failed.
                        else {
                            
                            // Handle message history download error. Check 'category' property to find
                            // out possible issue because of which request did fail.
                            //
                            // Request can be resent using: [status retry];
                        }
                    }];
}

#pragma mark - Private API

- (void)subscribeToChannel:(NSString *)channel
{
    [self.client subscribeToChannels: @[channel] withPresence:NO];
}

- (void)unsubscribeFromChannel:(NSString *)channel
{
    [self.client unsubscribeFromChannels: @[channel] withPresence:NO];
}

#pragma mark - Object Event Listener

- (void)client:(PubNub *)client didReceiveMessage:(PNMessageResult *)message {
    
    // Handle new message stored in message.data.message
    if (message.data.actualChannel) {
        
        // Message has been received on channel group stored in
        // message.data.subscribedChannel
    }
    else {
        
        // Message has been received on channel stored in
        // message.data.subscribedChannel
    }
    NSLog(@"Received message: %@ on channel %@ at %@", message.data.message,
          message.data.subscribedChannel, message.data.timetoken);
}

- (void)client:(PubNub *)client didReceiveStatus:(PNSubscribeStatus *)status {
    
    /* UNSUBSCRIBE
    if (status.category == PNUnexpectedDisconnectCategory) {
        // This event happens when radio / connectivity is lost
    }
    
    else if (status.category == PNConnectedCategory) {
        
        // Connect event. You can do stuff like publish, and know you'll get it.
        // Or just use the connected event to confirm you are subscribed for
        // UI / internal notifications, etc
        
    }
    else if (status.category == PNReconnectedCategory) {
        
        // Happens as part of our regular operation. This event happens when
        // radio / connectivity is lost, then regained.
    }
    else if (status.category == PNDecryptionErrorCategory) {
        
        // Handle messsage decryption error. Probably client configured to
        // encrypt messages and on live data feed it received plain text.
    }
     */
    
    if (status.category == PNUnexpectedDisconnectCategory) {
        // This event happens when radio / connectivity is lost
    }
    
    else if (status.category == PNConnectedCategory) {
        
        // Connect event. You can do stuff like publish, and know you'll get it.
        // Or just use the connected event to confirm you are subscribed for
        // UI / internal notifications, etc
        
        [self.client publish: @"Hello from the PubNub Objective-C SDK" toChannel:@"my_channel"
              withCompletion:^(PNPublishStatus *status) {
                  
                  // Check whether request successfully completed or not.
                  if (!status.isError) {
                      
                      // Message successfully published to specified channel.
                  }
                  // Request processing failed.
                  else {
                      
                      // Handle message publish error. Check 'category' property to find out possible issue
                      // because of which request did fail.
                      //
                      // Request can be resent using: [status retry];
                  }
              }];
    }
    else if (status.category == PNReconnectedCategory) {
        
        // Happens as part of our regular operation. This event happens when
        // radio / connectivity is lost, then regained.
    }
    else if (status.category == PNDecryptionErrorCategory) {
        
        // Handle messsage decryption error. Probably client configured to
        // encrypt messages and on live data feed it received plain text.
    }
}

@end
