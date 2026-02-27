#if DEBUG {
    debug_assert :: (arg: bool, message := "", args: .. Any, loc := #caller_location) #no_debug #expand {
        assert(arg, message, args, loc);
    }
} else {
    debug_assert :: (#discard arg: bool, #discard message := "", #discard args: .. Any, #discard loc := #caller_location) #expand {}
}
