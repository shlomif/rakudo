INIT {
    # I have no idea what I actually need to load here :(
    pir::load_bytecode('PCT/HLLCompiler.pbc');
    pir::load_bytecode('P6object.pbc');
    pir::load_bytecode('PAST/Pattern.pbc');
};

class Perl6::Optimizer is HLL::Compiler {
    method assign_type_check($past) {
        pir::printerr__vS("Running new compilation stage\n");
        $past;
    }
}

# vim: ft=perl6
