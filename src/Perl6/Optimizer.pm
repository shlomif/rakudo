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
    method augment_lexinfo($past) {
        # always match a block
        my $find_blocks := PAST::Pattern::Block.new();

        my &fold_blocks := sub($/) {
            my $current_block := $/.orig;

            # for each block, find immediate child blocks, and add
            # info from the current lexical block to it
            my &add_lex := sub ($/) {
                # magic PAST transformation here which I have
                # yet to figure out :-)
                # should add info about lexicals from $current_block
                # to $/.orig
                $/.orig;
            }
            my $find_child_blocks := PAST::Pattern::Block.new();
            $find_child_blocks.transform(
                                $/.orig,
                                &add_lex,
                                :descend_until($find_blocks),
                                :min_depth(1),
                            );

            # for each block, find variables declarations that are
            # directly in the block, and not in an inner block
            my $find_direct_vars := PAST::Pattern::Var.new();

            my &link_var := sub ($/) {
                my $past := $/.orig.clone;
                $past<block> := $current_block;
                $past;
            };

            $find_direct_vars.transform($/.orig,
                                &link_var,
                                :descend_until($find_blocks),
                        );
        }
    }

    method assign_type_check($past) {
        my &assignment  := sub ($opName) { $opName eq '&infix:<=>' }
        my &typed_value := sub ($val)    { ?~$val                   }

        my $pattern := PAST::Pattern::Op.new(:name(&assignment),
                                PAST::Pattern::Var.new(),
                                PAST::Pattern::Val.new(:returns(&typed_value)),
                        );
        my &fold    := sub ($/) {
#            mydump($/.orig);
            $/.orig;
        };
#        $pattern.transform($past, &fold);
        $past;
    }
}

# vim: ft=perl6
