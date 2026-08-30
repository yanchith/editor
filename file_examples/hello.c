#include <stdio.h>

#        include       "dingolingo.h"

int main() {
    float z = 1.5f;
    float y = .5;
    float x = 0.2342342e10;
    const char s0 = "stringo?";
    const char s1 = "Chraščieť";
    const char s2 = "こんにちは";

    int i = x > 1 ? 0 : 42lu; // nocheckin report this to Focus editor.
    int i2 = 1ull;

    printf("Hello, World!");
    return 0;
}