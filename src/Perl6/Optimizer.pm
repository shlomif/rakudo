INIT {
    pir::load_bytecode('PAST/Pattern.pbc');
};

# the clean way would be to inherit from HLL::Compiler, add some methods,
# and use the resulting Perl6::Optimizer instead of Perl6::Compiler
#
# since this doesn't work for some strange reasons, we just monkey-patch
# Perl6::Compiler to get access to the stages


pir::load_bytecode('dumper.pbc');

sub mydump($x) {
    Q:PIR {
        .local pmc n, o
        o = getstdout
        n = getstderr
        setstdout n
        $P0 = find_lex '$x'
        '_dumper'($P0)
        setstdout o
    };
    1;
}

module Perl6::Compiler {
    method assign_type_check($past) {
        my &assignment  := sub ($opName) { $opName eq '&infix:<=>' }
        my &typed_value := sub ($val)    { ?~$val                   }

        my $pattern := PAST::Pattern::Op.new(:name(&assignment),
                                PAST::Pattern::Var.new(),
                                PAST::Pattern::Val.new(:returns(&typed_value)),
                        );
        my &fold    := sub ($/) {
#            mydump($/.from);
            $/.from;
        };
        $pattern.transform($past, &fold);
    }
}

# vim: ft=perl6
