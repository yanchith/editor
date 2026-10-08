#![my_thingy]


#[inner]
#[another = "thingy"]
fn main() {
    println!("asdfasdfs");
    let x0 = 0xffff_i32;
    let x1 = 12341234124_u32;
    let x2 = 1.1231231;
    let x4 = 1232e2342342;
    let x5 = 1232E2342342_f64;
    let x6 = 21341243.223e213423234___f32;
    
    let x7 = 0b1101010_i32;
        
    let r0 = 1..2;
    let r1 = ..2;
    let r2 = 1..;
    let r3 = ..;
    
    let fr0 = 1.1..1.1;
}
