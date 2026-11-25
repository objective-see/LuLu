//
//  SelfDefense.m
//  Extension
//
//  Protects LuLu (the app) from being terminated/paused by other programs,
//  via an Endpoint Security client that authorizes signals sent to it
//

#import "consts.h"
#import "SelfDefense.h"

@import OSLog;
#import <dlfcn.h>
#import <bsm/libbsm.h>
#import <EndpointSecurity/EndpointSecurity.h>

/* GLOBALS */

//log handle
extern os_log_t logHandle;

//team id
#define LULU_TEAM_ID "VBG97UB4TA"

//app's (code signing) identifier
#define LULU_APP_ID "com.objective-see.lulu.app"

//'allow the operation when client fails to respond, but don't kill the client'
// ES_DEADLINE_MISS_MODE_FAIL_OPEN, from the macOS 27 SDK
#define DEADLINE_MISS_MODE_FAIL_OPEN 2

//(Apple) programs that may signal LuLu
// launchd: shutdown/restart/logout
// loginwindow: logout, and the 'Force Quit' window
// Dock & Activity Monitor: so the user can (still) force quit
static const char* const allowedSenders[] = {"com.apple.xpc.launchd", "com.apple.loginwindow", "com.apple.dock", "com.apple.ActivityMonitor"};

//(es) string token matches string?
static BOOL matches(es_string_token_t token, const char* string)
{
    return (token.length == strlen(string)) && (0 == strncmp(token.data, string, token.length));
}

//is process (part of) LuLu?
// signed by us, with one of our identifiers
static BOOL isLuLu(const es_process_t* process)
{
    return (YES == matches(process->team_id, LULU_TEAM_ID)) &&
           (process->signing_id.length >= strlen(BUNDLE_ID)) &&
           (0 == strncmp(process->signing_id.data, BUNDLE_ID, strlen(BUNDLE_ID)));
}

//allow signal?
static BOOL shouldAllow(const es_message_t* message)
{
    //(direct) sender
    const es_process_t* sender = message->process;

    //process that asked the sender (launchd) to send it
    // e.g. 'launchctl kill' ...only present in newer message versions
    const es_process_t* instigator = (message->version >= 9) ? message->event.signal.instigator : NULL;

    //allowed?
    BOOL allowed = NO;

    //harmless signal?
    // 0 is just an 'is alive' check, and the others are ignored by default
    // (the system sends some to apps as a matter of course, e.g. launchservicesd a SIGCONT on quit)
    switch(message->event.signal.sig)
    {
        case 0:
        case SIGCONT:
        case SIGURG:
        case SIGCHLD:
        case SIGIO:
        case SIGWINCH:
        case SIGINFO:
            return YES;
    }

    //not for LuLu's app?
    if( (YES != isLuLu(message->event.signal.target)) ||
        (YES != matches(message->event.signal.target->signing_id, LULU_APP_ID)) )
    {
        return YES;
    }

    //sent on behalf of another process?
    // then it's that process that has to be allowed
    if(NULL != instigator) sender = instigator;

    //from LuLu itself (e.g. an upgrade)?
    if(YES == isLuLu(sender)) allowed = YES;

    //from an allowed (Apple) program?
    else if(YES == sender->is_platform_binary)
    {
        for(size_t i = 0; i < sizeof(allowedSenders)/sizeof(allowedSenders[0]); i++)
        {
            if(YES == matches(sender->signing_id, allowedSenders[i])) allowed = YES;
        }
    }

    //log msg
    // both, so there's a record of what can (and can't) terminate LuLu
    os_log(logHandle, "self-defense: %{public}s signal %d sent to LuLu by %{public}.*s (pid: %d)%{public}s", (YES == allowed) ? "allowed" : "denied", message->event.signal.sig, (int)sender->signing_id.length, sender->signing_id.data, audit_token_to_pid(sender->audit_token), (NULL != instigator) ? ", via launchd" : "");

    return allowed;
}

@implementation SelfDefense
{
    //endpoint security client
    es_client_t* client;

    //status
    SelfDefenseStatus status;
}

//start
// no-op if already active, so can be called again (e.g. once full disk access is granted)
-(SelfDefenseStatus)start
{
    //result
    es_new_client_result_t result = 0;

    //event(s) of interest
    es_event_type_t events[] = {ES_EVENT_TYPE_AUTH_SIGNAL};

    //(macOS 27+) function to set what happens if we miss a deadline
    es_return_t (*setDeadlineMissMode)(es_client_t*, int) = dlsym(RTLD_DEFAULT, "es_set_deadline_miss_mode");

    //sync
    @synchronized(self)
    {
        //already active?
        if(NULL != client) goto bail;

        //no 'fail open' support?
        // without it a missed deadline gets the extension (so, the firewall) killed ...not worth it
        if(NULL == setDeadlineMissMode)
        {
            //dbg msg
            os_log_debug(logHandle, "self-defense: not supported on this version of macOS");

            status = SelfDefenseUnsupported;
            goto bail;
        }

        //create client
        result = es_new_client(&client, ^(es_client_t* esClient, const es_message_t* message)
        {
            //authorize
            es_respond_auth_result(esClient, message, (YES == shouldAllow(message)) ? ES_AUTH_RESULT_ALLOW : ES_AUTH_RESULT_DENY, false);
        });
        if(ES_NEW_CLIENT_RESULT_SUCCESS != result)
        {
            //no full disk access?
            // expected, 'til the user grants it
            if(ES_NEW_CLIENT_RESULT_ERR_NOT_PERMITTED == result)
            {
                os_log_debug(logHandle, "self-defense: extension needs full disk access");
                status = SelfDefenseNeedsFullDiskAccess;
            }
            else
            {
                os_log_error(logHandle, "ERROR: self-defense: es_new_client() failed with %d", result);
                status = SelfDefenseError;
            }

            client = NULL;
            goto bail;
        }

        //fail open, then subscribe
        if( (ES_RETURN_SUCCESS != setDeadlineMissMode(client, DEADLINE_MISS_MODE_FAIL_OPEN)) ||
            (ES_RETURN_SUCCESS != es_subscribe(client, events, sizeof(events)/sizeof(events[0]))) )
        {
            os_log_error(logHandle, "ERROR: self-defense: failed to configure endpoint security client");

            es_delete_client(client);
            client = NULL;
            status = SelfDefenseError;
            goto bail;
        }

        //log msg
        os_log(logHandle, "self-defense: active");

        status = SelfDefenseActive;

bail:   ;
    }

    return status;
}

//stop
-(void)stop
{
    //sync
    @synchronized(self)
    {
        //delete client (also unsubscribes)
        if(NULL != client)
        {
            es_delete_client(client);
            client = NULL;

            //log msg
            os_log(logHandle, "self-defense: stopped");
        }

        status = SelfDefenseOff;
    }
}

//current status
-(SelfDefenseStatus)status
{
    @synchronized(self)
    {
        return status;
    }
}

@end
