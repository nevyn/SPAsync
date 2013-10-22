/** In order for SPAsync to be embeddable in libraries, all visible symbols must
    be namespaced so that they don't clash with other copies of the same library.
    For example, if Lookback.framework embeds SPAsync, and Lookback gets linked into
    Spotify.app, and Spotify.app also uses SPAsync, Spotify.app must either
    1) use the SPAsync in Lookback;
    2) use the same package manager as Lookback (if everyone in the world used CocoaPods, I would be so happy);
    3) or Lookback could use a namespaced version of SPAsync, which could co-exist
       with a version of SPAsync in Spotify.app.
    
    This header file implements support for #3, which users of SPAsync can optionally use. To use it,
    embed the .h and .m files you need in your project, and #define SPASYNC_NAMESPACE to a valid c identifier,
    either in your prefix header or with a "Preprocessor Macros" build setting.
    
    Thanks, wolf! http://rentzsch.tumblr.com/post/40806448108/ns-poor-mans-namespacing-for-objective-c
*/

#ifndef SPASYNC_NAMESPACE
// Default to using the 'SP' prefix
#define SPASYNC_NAMESPACE SP
#endif

#define JRNS_CONCAT_TOKENS(a,b) a##b
#define JRNS_EVALUATE(a,b) JRNS_CONCAT_TOKENS(a,b)
#define SPA_NS(original_name) JRNS_EVALUATE(SPASYNC_NAMESPACE, original_name)
