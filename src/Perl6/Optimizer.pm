INIT {
    # I have no idea what I actually need to load here :(
#    pir::load_bytecode('PAST/Pattern.pbc');
};

# the clean way would be to inherit from HLL::Compiler, add some methods,
# and use the resulting Perl6::Optimizer instead of Perl6::Compiler
#
# since this doesn't work for some strange reasons, we just monkey-patch
# Perl6::Compiler to get access to the stages
module Perl6::Compiler {
    method assign_type_check($past) {
        pir::printerr__vS("Running new compilation stage\n");
        $past;
    }
}

# vim: ft=perl6
