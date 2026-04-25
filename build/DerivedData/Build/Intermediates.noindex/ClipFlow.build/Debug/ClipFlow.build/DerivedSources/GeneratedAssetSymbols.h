#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "ClipFlowLogo" asset catalog image resource.
static NSString * const ACImageNameClipFlowLogo AC_SWIFT_PRIVATE = @"ClipFlowLogo";

/// The "ClipFlowLogoDark" asset catalog image resource.
static NSString * const ACImageNameClipFlowLogoDark AC_SWIFT_PRIVATE = @"ClipFlowLogoDark";

/// The "ClipFlowLogoLight" asset catalog image resource.
static NSString * const ACImageNameClipFlowLogoLight AC_SWIFT_PRIVATE = @"ClipFlowLogoLight";

#undef AC_SWIFT_PRIVATE
