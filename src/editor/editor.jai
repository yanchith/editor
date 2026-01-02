#import "Basic";

#load "platform.jai";
#load "input.jai";

Editor :: struct {
    dummy: s64;
}

init :: (editor: *Editor, platform: Platform) {
    log("Editor init");
}

update_and_render :: (editor: *Editor, platform: Platform, input: Input) {
    log("Editor update and render");
}
