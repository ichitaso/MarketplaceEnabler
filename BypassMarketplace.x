@import Foundation;
#include <libgen.h>
#include <dlfcn.h>
#import <substrate.h>

typedef CF_ENUM(uint64_t, EligibilityDomainType) {
    /// Install marketplace-distributed apps
    EligibilityDomainTypeHydrogen = 2,
    /// Update/restore marketplace-distributed apps
    EligibilityDomainTypeHelium = 3,
    /// Update/restore web browser engine host apps
    EligibilityDomainTypeLithium = 4,
    /// Install web browser engine host apps
    EligibilityDomainTypeCarbon = 7,
    /// Install apps distributed via the web
    EligibilityDomainTypeArgon = 19,
    /// Update/restore apps distributed via the web
    EligibilityDomainTypePotassium = 20,
};
typedef CF_ENUM(uint64_t, EligibilityAnswer) {
    EligibilityAnswerEligible = 4,
};
typedef CF_ENUM(uint64_t, EligibilityAnswerSource) {
    EligibilityAnswerSourceInvalid = 0,
    EligibilityAnswerSourceComputed = 1,
    EligibilityAnswerSourceForced = 2,
};
//@interface EligibilityOverride : NSObject
//- (NSMutableDictionary *)overrideMap;
//@end
//@interface EligibilityOverrideData : NSObject
//- (instancetype)initWithAnswer:(EligibilityAnswer)answer context:(id)context;
//@end

//%group Hook_eligibilityd
// seems to already be YES
//%hook GlobalConfiguration
//- (BOOL)supportsForcedAnswers {
//    return YES;
//}
//%end
//%hook EligibilityEngine
//- (EligibilityOverride *)_loadOverridesWithError:(NSError **)error {
//    EligibilityOverride *result = %orig;
//    if (!result) {
//        result = [NSClassFromString(@"EligibilityOverride") new];
//    }
//    EligibilityOverrideData *overrideData = [[NSClassFromString(@"EligibilityOverrideData") alloc] initWithAnswer:EligibilityAnswerEligible context:nil];
//    NSMutableDictionary *overrideMap = result.overrideMap;
//    overrideMap[@(EligibilityDomainTypeHydrogen)] = overrideData;
//    overrideMap[@(EligibilityDomainTypeHelium)] = overrideData;
//    overrideMap[@(EligibilityDomainTypeLithium)] = overrideData;
//    overrideMap[@(EligibilityDomainTypeCarbon)] = overrideData;
//    overrideMap[@(EligibilityDomainTypeArgon)] = overrideData;
//    overrideMap[@(EligibilityDomainTypePotassium)] = overrideData;
//    return result;
//}
//%end
//%end

%group Hook_os_eligibility_get_domain_answer
int os_eligibility_get_domain_answer(EligibilityDomainType domain, EligibilityAnswer *answer_ptr, EligibilityAnswerSource *answer_source_ptr, xpc_object_t *status_ptr, xpc_object_t *context_ptr);
%hookf(int, os_eligibility_get_domain_answer, EligibilityDomainType domain, EligibilityAnswer *answer_ptr, EligibilityAnswerSource *answer_source_ptr, xpc_object_t *status_ptr, xpc_object_t *context_ptr) {
    switch (domain) {
        case EligibilityDomainTypeHydrogen:
        case EligibilityDomainTypeHelium:
        case EligibilityDomainTypeLithium:
        case EligibilityDomainTypeCarbon:
        case EligibilityDomainTypeArgon:
        case EligibilityDomainTypePotassium:
            if (answer_ptr) {
                *answer_ptr = EligibilityAnswerEligible;
            }
            if (answer_source_ptr) {
                *answer_source_ptr = EligibilityAnswerSourceForced;
            }
            return 0;
        default:
            return %orig(domain, answer_ptr, answer_source_ptr, status_ptr, context_ptr);
    }
}
%end

// for appstorecomponentsd, we hook URL method to replace region code
%group Hook_appstorecomponentsd
%hook NSURLRequest
- (instancetype)initWithURL:(NSURL *)url {
    NSString *prefix = @"https://amp-api.apps-marketplace.apple.com/v1/catalog/";
    NSString *urlString = url.absoluteString;
    if ([url.absoluteString hasPrefix:prefix]) {
        // replace region code
        NSArray<NSString *> *components = [urlString componentsSeparatedByString:@"/"];
        if (components.count > 6) {
            NSMutableArray<NSString *> *newComponents = [components mutableCopy];
            newComponents[5] = @"fr"; // spoof to France region
            NSURL *newURL = [NSURL URLWithString:[newComponents componentsJoinedByString:@"/"]];
            return %orig(newURL);
        }
    }
    return %orig;
}
%end
%end

// On iPad, managedappdistributiond rejects marketplace/ADP installs with
// "Feature not eligible on this device class" before the eligibility domain is
// even queried. It determines the device class through these libMobileGestalt
// accessors; the daemon maps deviceClassNumber 1 -> "iPhone", 3 -> "iPad".
// Spoof them so the daemon treats an iPad as an iPhone.
static int (*orig_MG_deviceClassNumber)(void *device);
static int my_MG_deviceClassNumber(void *device) {
    return 1; // iPhone
}

static void hookDeviceClass(void) {
    void *f;
    if ((f = dlsym(RTLD_DEFAULT, "MobileGestalt_get_deviceClassNumber"))) {
        MSHookFunction(f, (void *)my_MG_deviceClassNumber, (void **)&orig_MG_deviceClassNumber);
    }
}

%ctor {
    NSString *processName = @(basename(argv[0]));
    if ([processName isEqualToString:@"managedappdistributiond"] || [processName isEqualToString:@"installd"]) {
        %init(Hook_os_eligibility_get_domain_answer);
        hookDeviceClass();
    } else if ([processName isEqualToString:@"appstorecomponentsd"]) {
        %init(Hook_appstorecomponentsd);
    }
}
