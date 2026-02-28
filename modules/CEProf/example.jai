#import,file "module.jai"(IMPORT_MODE = .RUNTIME);

main :: () {
    ProfileZone("Main");

    result := f(1, 5);
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
