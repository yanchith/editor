#ifdef WIN32
#define __EXPORT __declspec(dllexport)
#else
#define __EXPORT
#endif

// NOTE(jt): I am not sure what __EXPORT is, but without Bindings_Generator does not see the
// functions. .c files for STB libraries shipping with the compiler analogous defines.
#define STBTT_DEF extern __EXPORT

#define STB_TRUETYPE_IMPLEMENTATION
#include "stb_truetype.h"
