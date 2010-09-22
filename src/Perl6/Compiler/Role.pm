class Perl6::Compiler::Role is Perl6::Compiler::Package;

# Holds the signautre for this parametric role, if any.
has $!signature;

# Textual representation of the signature, for constructing the long package name.
has $!signature_text;

# Accessor for signature.
method signature($signature?) {
    if pir::defined__IP($signature) { $!signature := $signature }
    $!signature
}

# Accessor for signature text.
method signature_text($signature_text?) {
    if pir::defined__IP($signature_text) { $!signature_text := $signature_text }
    pir::isnull__IP($!signature_text) ?? '' !! $!signature_text
}

# Do the code generation for the parametric role.
method finish($block) {
    my $decl := PAST::Stmts.new();

    # Sanity check on scoping.
    if self.scope eq 'augment' || self.scope eq 'supercede' {
        pir::die('A role is immutable and may not be modified');
    }

    # Create meta-class RoleHOW, which will hold details of this particular
    # role variant.
    my $how := self.how;
    my @how := Perl6::Grammar::parse_name(~$how);
    my $metaclass := PAST::Var.new( :name(@how.pop), :namespace(@how), :scope('package') );
    my $obj_reg := PAST::Var.new( :name('obj'), :scope('register') );
    my $meta_reg := PAST::Var.new( :name('meta'), :scope('register') );
    my $name := $!name ?? ~$!name !! '';
    $decl.push(PAST::Op.new(
        :pasttype('bind'),
        PAST::Var.new( :name('obj'), :scope('register'), :isdecl(1) ),
        PAST::Op.new(
            :pasttype('callmethod'),
            :name('new'),
            $metaclass,
            $name
        )
    ));
    $decl.push(PAST::Op.new(
        :pasttype('bind'),
        PAST::Var.new( :name('meta'), :scope('register'), :isdecl(1) ),
        PAST::Op.new( :pasttype('callmethod'), :name('HOW'), $obj_reg )
    ));

    # Traits.
    if self.traits {
        for @(self.traits) {
            $_.unshift($obj_reg);
            $decl.push($_);
        }
    }

    # Meta Methods.
    my %meta_methods := $!meta_methods;
    for %meta_methods {
        $decl.push(PAST::Op.new(
            :pasttype('callmethod'),
            :name('add_meta_method'),
            $meta_reg, $obj_reg, ~$_, %meta_methods{~$_}<code_ref>
        ));
    }

    # Methods.
    my %methods := self.methods;
    for %methods {
        $decl.push(PAST::Op.new(
            :pasttype('callmethod'),
            :name('add_method'),
            $meta_reg, $obj_reg, ~$_, 
            PAST::Op.new( :pasttype('callmethod'), :name('clone'), %methods{~$_}<code_ref> )
        ));
    }

    # Attributes.
    my $attr_list := self.attributes();
    for @($attr_list) {
        my $attr := PAST::Op.new(
            :pasttype('callmethod'),
            :name('new'),
            PAST::Var.new( :name('Attribute'),   :namespace(''), :scope('package') ),
            PAST::Val.new( :value($_<name>),     :named('name') ),
            PAST::Val.new( :value($_<accessor>), :named('has_accessor') )
        );
        if pir::defined($_<rw>) {
            $attr.push(PAST::Val.new( :value($_<rw>), :named('rw') ));
        }
        if $_<build> {
            $_<build>.named('build');
            $attr.push($_<build>);
        }
        $decl.push(PAST::Op.new(
            :pasttype('callmethod'),
            :name('add_attribute'),
            $meta_reg, $obj_reg, $attr
        ));
    }

    # Call compose to create the role object.
    $decl.push(PAST::Op.new( :pasttype('callmethod'), :name('compose'), $meta_reg, $obj_reg ));

    # XXX If it's our-scoped, we need to also save a reference to the current
    # context since we need to fixup its outer_ctx later from the main program
    # body. Complete band-aid that we should be able to kill in the not too
    # distant future, but the bug is nasty.
    if !$*SETTING_MODE && ($!scope eq 'our' || $!scope eq '') {
        $decl.unshift(PAST::Op.new(
            :inline('    $P0 = getinterp',
                    '    $P0 = $P0["context"]',
                    '    $P1 = get_hll_global "@!recapture"',
                    '    unless null $P1 goto got_recapture_list',
                    '    $P1 = root_new ["parrot";"ResizablePMCArray"]',
                    '    set_hll_global "@!recapture", $P1',
                    '  got_recapture_list:',
                    '    push $P1, $P0')
        ));
    }

    # We need the block to get the signature, or a default one, plus the
    # decl code as a body.
    my $sig := pir::defined__IP($!signature) ?? $!signature !! Perl6::Compiler::Signature.new();
    Perl6::Actions::add_signature($block, $sig);
    $block.push($decl);
    $block.blocktype('declaration');
    $block.nsentry('');

    # Unless the role is anonymous, in the loadinit we need to have code
    # to add this role variant to the main role object that goes in the
    # namespace or lexpad.
    my $result;
    if $name && $!scope ne 'anon' {
        # Create block that we'll call to do role setup, and embed the
        # block we've already made within it.
        my $init_decl_name := $block.unique('!class_init_');
        my @name := Perl6::Grammar::parse_name($name);
        my $short_name := @name.pop;
        my $rolemaker := PAST::Block.new(
            :name($init_decl_name),
            :blocktype('declaration'),
            PAST::Op.new( :pasttype('bind'),
                PAST::Var.new( :name('master_role'), :scope('register'), :isdecl(1) ),
                PAST::Op.new( :pasttype('call'), :name('!create_master_role'),
                    ~$short_name,
                    ($!scope eq 'our' ??
                        PAST::Var.new( :name($short_name), :namespace(@name), :scope('package') ) !!
                        PAST::Op.new( :pirop('find_lex_skip_current PS'), $name ))
                )
            ),
            PAST::Op.new(
                :pasttype('callmethod'), :name('!add_variant'),
                PAST::Var.new( :name('master_role'), :scope('register') ),
                Perl6::Actions::block_closure(Perl6::Actions::blockref($block), 'Sub', 1)
            )
        );
        
        # Set namespace and install in package, if our scoped.
        if $!scope eq 'our' || $!scope eq '' {
            my @ns := Perl6::Grammar::parse_name($name ~ '[' ~ self.signature_text ~ ']');
            $rolemaker.namespace(@ns);
            $rolemaker.push(PAST::Op.new( :pasttype('bind'),
                PAST::Var.new( :name($short_name), :namespace(@name), :scope('package') ),
                PAST::Var.new( :name('master_role'), :scope('register') )
            ));
            my @PACKAGE := Q:PIR { %r = get_hll_global ['Perl6'; 'Actions'], '@PACKAGE' };
            @PACKAGE[0].block.loadinit().push(PAST::Op.new(
                :pasttype('call'),
                PAST::Var.new( :name($init_decl_name), :namespace(@ns), :scope('package') )
            ));
            $result := PAST::Stmts.new(
                $rolemaker,
                $block,
                PAST::Var.new( :name($short_name), :namespace(@name), :scope('package') )
            );
        }

        # If we're my-scoped, similar but for the lexpad.
        elsif $!scope eq 'my' {
            # Install a binding of the declaration to a name in the lexpad.
            $rolemaker.blocktype('immediate');
            $rolemaker.push(PAST::Var.new( :name('master_role'), :scope('register') ));
            @Perl6::Actions::BLOCK[0][0].push(PAST::Var.new(
                :name($name), :isdecl(1),  :viviself($rolemaker), :scope('lexical')
            ));
            @Perl6::Actions::BLOCK[0][0].push($block);
            @Perl6::Actions::BLOCK[0].symbol($name, :scope('lexical'), :does_abstraction(1));
            $result := PAST::Var.new( :name($name), :scope('lexical') );
        }
        else {
            pir::die('Scope declarator ' ~ ~$!scope ~ ' is not supported on roles');
        }
    }

    # Otherwise, for anonymous, make such an object and hand it back.
    else {
        $result := PAST::Stmts.new(
            PAST::Op.new( :pasttype('bind'),
                PAST::Var.new( :name('tmp_role'), :scope('register'), :isdecl(1) ),
                PAST::Op.new( :pasttype('call'), :name('!create_master_role'), '')
            ),
            PAST::Op.new( :pasttype('callmethod'), :name('!add_variant'),
                PAST::Var.new( :name('tmp_role'), :scope('register') ),
                Perl6::Actions::block_closure($block, 'Sub', 1)
            ),
            PAST::Var.new( :name('tmp_role'), :scope('register') )
        );
    }

    return $result;
}
