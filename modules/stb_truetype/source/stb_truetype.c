// This c file exists so that we can make a standalone library out of the h file.

#ifdef WIN32
#define __EXPORT __declspec(dllexport)
#else
#define __EXPORT
#endif

#define STBTT_DEF extern __EXPORT

#define STB_TRUETYPE_IMPLEMENTATION
#include "stb_truetype.h"
