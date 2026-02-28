#import "CEProf"(IMPORT_MODE = .RUNTIME);

main :: () {
    ProfileFrame();
    ProfileZone("Main");

    result := f(1, 5);

    write_string("Done");
}

f :: (a: s64, b: s64) -> s64 {
    ProfileZone("f");
    result := a;
    for 1..10 {
        a += b;
        a *= a + b;
    }

    return result;
}
