# Copyright (C) 2009, The Perl Foundation.
# $Id$

class Perl6::Compiler::Signature;

# This class represents a signature in the compiler. It takes care of
# producing an AST that will generate the signature, based upon all of
# the various bits of information it is provided up to that point. The
# motivation for this is making actions.pm simpler, but also to allow
# the underlying signature construction mechanism to change more easily.
# It will also allow more efficient code generation.


has $!entries;
has $!default_type;
has $!bind_target;

# Instantiates a Signature.
method new(*@params) {
    my $new_sig := Q:PIR { %r = new ['Perl6';'Compiler';'Signature'] };
    for @params {
        $new_sig.add_parameter($_);
    }
    $new_sig
}

# Accessor for $!bind_target.
method bind_target($bind_target?) {
    if $bind_target { $!bind_target := $bind_target }
    $!bind_target
}


# Adds a parameter to the signature.
method add_parameter($new_entry) {
    self.entries.push($new_entry);
}


# As for add_parameter, but puts it into position relative to the other
# positional parameters.
method add_placeholder_parameter($new_entry) {
    my @entries := self.entries;
    
    # First check we don't have a parameter of this name.
    for @entries {
        if $_.var_name eq $new_entry.var_name {
            return 1;
        }
    }
    
    # Now look for insertion position.
    my @temp;
    if +@entries == 0 {
        @entries.push($new_entry);
        return 1;
    }
    elsif $new_entry.named_slurpy {
        unless @entries[+@entries - 1].named_slurpy {
            @entries.push($new_entry);
        }
    }
    elsif $new_entry.pos_slurpy {
        if @entries[+@entries - 1].named_slurpy {
            @temp.unshift(@entries.pop);
        }
        unless +@entries && @entries[+@entries - 1].pos_slurpy {
            @entries.push($new_entry);
        }
        for @temp { @entries.push($_); }
    }
    elsif +@($new_entry.names) {
        # Named.
        while +@entries && !@(@entries[0].names) {
            @temp.unshift(@entries.shift);
        }
        @entries.unshift($new_entry);
        for @temp { @entries.unshift($_); }
    }
    else {
        # Positional.
        while +@entries && @entries[0].var_name lt $new_entry.var_name &&
                !@(@entries[0].names) && !@entries[0].pos_slurpy && !@entries[0].named_slurpy {
            @temp.unshift(@entries.shift);
        }
        @entries.unshift($new_entry);
        for @temp { @entries.unshift($_); }
    }
}


# Sets the default type of the parameters.
method set_default_parameter_type($type_name) {
    $!default_type := $type_name;
}


# Gets the default type of the parameters.
method get_default_parameter_type() {
    $!default_type || 'Mu'
}


# Adds an invocant to the signature, if it does not already have one.
method add_invocant() {
    my @entries := self.entries;
    if +@entries == 0 || !@entries[0].invocant {
        my $param := Perl6::Compiler::Parameter.new();
        $param.var_name("");
        $param.invocant(1);
        $param.multi_invocant(1);
        @entries.unshift($param);
    }
}


# Checks if the signature contains a named slurpy parameter.
method has_named_slurpy() {
    my @entries := self.entries;
    unless +@entries { return 0; }
    my $last := @entries[ +@entries - 1 ];
    return $last.named_slurpy();
}


# Gets a PAST::Op node with children being PAST::Var nodes that declare the
# various variables mentioned within the signature, with a valid viviself to
# make sure they are initialized either to the default value or an empty
# instance of the correct type.
method get_declarations() {
    my $result := PAST::Op.new( :pasttype('stmts') );
    my @entries := self.entries;
    for @entries {
        # If the parameter has a name, add it.
        if pir::length($_.var_name) > 1 {
            my $var := PAST::Var.new(
                :name($_.var_name),
                :scope('lexical'),
                :viviself(Perl6::Actions::sigiltype($_.sigil))
            );
            $var<sigil>       := $_.sigil;
            $var<twigil>      := $_.twigil;
            $var<desigilname> := pir::substr($_.var_name, ($_.twigil ?? 2 !! 1));
            $var<traits>      := $_.traits;
            $result.push($var);
        }
        elsif pir::length($_.var_name) == 1 {
            # A placeholder, but could be being used in a declaration, so emit
            # a Whatever.
            my @name := Perl6::Grammar::parse_name('Whatever');
            $result.push(PAST::Op.new(
                :pasttype('callmethod'), :name('new'), :lvalue(1),
                PAST::Var.new( :name(@name.pop), :namespace(@name), :scope('package') )
            ));
        }

        # If there are captured type variables, need variables for those too.
        if $_.type_captures {
            for @($_.type_captures) {
                my $var := PAST::Var.new(
                    :name($_),
                    :scope('lexical'),
                    :viviself(Perl6::Actions::sigiltype('::'))
                );
                $var<sigil> := '::';
                $result.push($var);
            }
        }

        # Check any sub-signatures.
        if pir::defined__IP($_.sub_llsig) {
            for @($_.sub_llsig.get_declarations) {
                $result.push($_);
            }
        }
    }
    return $result;
}


# Sets all parameters without an explicit read type to default to rw.
method set_rw_by_default() {
    my @entries := self.entries;
    for @entries {
        $_.is_rw(1);
    }
}


# Produces an AST for generating a low-level signature object. Optionally can
# instead produce code to generate a high-level signature object.
method ast($low_level?) {
    my $ast     := PAST::Stmts.new();
    my @entries := self.entries;
    my $SIG_ELEM_BIND_CAPTURE       := 1;
    my $SIG_ELEM_BIND_PRIVATE_ATTR  := 2;
    my $SIG_ELEM_BIND_PUBLIC_ATTR   := 4;
    my $SIG_ELEM_SLURPY_POS         := 8;
    my $SIG_ELEM_SLURPY_NAMED       := 16;
    my $SIG_ELEM_SLURPY_BLOCK       := 32;
    my $SIG_ELEM_INVOCANT           := 64;
    my $SIG_ELEM_MULTI_INVOCANT     := 128;
    my $SIG_ELEM_IS_RW              := 256;
    my $SIG_ELEM_IS_COPY            := 512;
    my $SIG_ELEM_IS_PARCEL          := 1024;
    my $SIG_ELEM_IS_OPTIONAL        := 2048;
    my $SIG_ELEM_ARRAY_SIGIL        := 4096;
    my $SIG_ELEM_HASH_SIGIL         := 8192;
    my $SIG_ELEM_DEFAULT_FROM_OUTER := 16384;
    my $SIG_ELEM_IS_CAPTURE         := 32768;
    
    # Allocate a signature and stick it in a register.
    my $sig_var := PAST::Var.new( :name($ast.unique('signature_')), :scope('register') );
    $ast.push(PAST::Op.new(
        :pasttype('bind'),
        PAST::Var.new( :name($sig_var.name()), :scope('register'), :isdecl(1) ),
        PAST::Op.new( :inline('    %r = allocate_llsig ' ~ +@entries) )
    ));

    # We'll likely also find a register holding a null value helpful to have.
    $ast.push(PAST::Op.new( :inline('    null $P0') ));
    $ast.push(PAST::Op.new( :inline('    null $S0') ));
    my $null_reg := PAST::Var.new( :name('$P0'), :scope('register') );
    my $null_str := PAST::Var.new( :name('$S0'), :scope('register') );

    # For each of the parameters, emit a call to add the parameter.
    my $i := 0;
    for @entries {
        # First, compute flags.
        my $flags := 0;
        if $_.optional                  { $flags := $flags + $SIG_ELEM_IS_OPTIONAL; }
        if $_.pos_slurpy                { $flags := $flags + $SIG_ELEM_SLURPY_POS; }
        if $_.named_slurpy              { $flags := $flags + $SIG_ELEM_SLURPY_NAMED; }
        if $_.sigil eq '@'              { $flags := $flags + $SIG_ELEM_ARRAY_SIGIL; }
        if $_.sigil eq '%'              { $flags := $flags + $SIG_ELEM_HASH_SIGIL; }
        if $_.invocant                  { $flags := $flags + $SIG_ELEM_INVOCANT; }
        if $_.multi_invocant            { $flags := $flags + $SIG_ELEM_MULTI_INVOCANT; }
        if $_.is_rw                     { $flags := $flags + $SIG_ELEM_IS_RW; }
        if $_.is_parcel                 { $flags := $flags + $SIG_ELEM_IS_PARCEL; }
        if $_.is_copy                   { $flags := $flags + $SIG_ELEM_IS_COPY; }
        if $_.default_from_outer        { $flags := $flags + $SIG_ELEM_DEFAULT_FROM_OUTER; }
        if $_.is_capture                { $flags := $flags + $SIG_ELEM_IS_CAPTURE; }
        if $_.twigil eq '!'             { $flags := $flags + $SIG_ELEM_BIND_PRIVATE_ATTR }
        if $_.twigil eq '.' {
            # Set flag, and we'll pull the sigil and twigil off to leave us
            # with the method name.
            $flags := $flags + $SIG_ELEM_BIND_PUBLIC_ATTR;
            $_.var_name(pir::substr($_.var_name, 2));
        }

        # Fix up nominal type.
        my $nom_type := $null_reg;
        if $_.pos_slurpy || $_.named_slurpy {
            $nom_type := PAST::Var.new( :name('Mu'), :scope('package') );
        }
        elsif $_.sigil eq "$" || $_.sigil eq "" {
            if !$_.nom_type {
                my @name := Perl6::Grammar::parse_name(
                    $_.invocant ?? 'Mu' !! self.get_default_parameter_type());
                $nom_type := PAST::Var.new(
                    :name(@name.pop()),
                    :namespace(@name),
                    :scope('package')
                );
            }
            else {
                $nom_type := $_.nom_type;
            }
        }
        elsif $_.sigil ne "" {
            # May well be a parametric role based type.
            my $role_name;
            if    $_.sigil eq "@" { $role_name := "Positional" }
            elsif $_.sigil eq "%" { $role_name := "Associative" }
            elsif $_.sigil eq "&" { $role_name := "Callable" }
            if $role_name {
                my $role_type := PAST::Var.new( :name($role_name), :namespace(''), :scope('package') );
                if !$_.nom_type {
                    $nom_type := $role_type;
                }
                else {
                    $nom_type := PAST::Op.new(
                        :pasttype('callmethod'),
                        :name('!select'),
                        $role_type,
                        $_.nom_type
                    );
                }
            }
        }

        # Constraints list needs to build a ResizablePMCArray.
        my $constraints := $null_reg;
        if +@($_.cons_types) {
            $constraints := PAST::Op.new( );
            my $pir := "    %r = root_new ['parrot'; 'ResizablePMCArray']\n";
            my $i := 0;
            for @($_.cons_types) {
                $pir := $pir ~ "    push %r, %" ~ $i ~ "\n";
                $constraints.push($_);
            }
            $constraints.inline($pir);
        }

        # Names and type capture lists needs to build a ResizableStringArray.
        my $names := $null_reg;
        if +@($_.names) {
            my $pir := "    %r = root_new ['parrot'; 'ResizableStringArray']\n";
            for @($_.names) { $pir := $pir ~ '    push %r, utf8:"' ~ ~$_ ~ "\"\n"; }
            $names := PAST::Op.new( :inline($pir) );
        }
        my $type_captures := $null_reg;
        if +@($_.type_captures) {
            my $pir := "    %r = root_new ['parrot'; 'ResizableStringArray']\n";
            for @($_.type_captures) { $pir := $pir ~ '    push %r, utf8:"' ~ ~$_ ~ "\"\n"; }
            $type_captures := PAST::Op.new( :inline($pir) );
        }

        # Fix up sub-signature AST.
        my $sub_sig := $null_reg;
        if pir::defined__IP($_.sub_llsig) {
            $sub_sig := PAST::Stmts.new();
            $_.sub_llsig.set_default_parameter_type(self.get_default_parameter_type);
            $sub_sig.push( $_.sub_llsig.ast(1) );
            $sub_sig.push( PAST::Var.new( :name('signature'), :scope('register') ) );
        }

        # Emit op to build signature element.
        $ast.push(PAST::Op.new(
            :pirop('set_llsig_elem vPisiPPPPPPS'),
            $sig_var,
            $i,
            ($_.var_name eq '' || $_.var_name eq $_.sigil ?? $null_str !! ~$_.var_name),
            $flags,
            $nom_type,
            $constraints,
            $names,
            $type_captures,
            ($_.default ?? $_.default !! $null_reg),
            $sub_sig,
            ($_.coerce_to ?? $_.coerce_to !! $null_str)
        ));
        $i := $i + 1;
    }

    # If we had to build a high-level signature, do so.
    if ($low_level) {
        $ast.push(PAST::Op.new(
            :pasttype('bind'),
            PAST::Var.new( :name('signature'), :scope('register'), :isdecl(1) ),
            $sig_var
        ));
    }
    else {
        my $node := PAST::Op.new(
            :pasttype('callmethod'),
            :name('new'),
            PAST::Var.new( :name('Signature'),, :scope('package') ),
            PAST::Var.new( :name($sig_var.name()), :scope('register'), :named('llsig') )
        );
        if self.bind_target() eq 'lexical' {
            $node.push(PAST::Op.new(
                :named('bind_target'),
                :inline('    %r = getinterp',
                        '    %r = %r["lexpad"]')
            ));
        }
        $ast.push($node);
    }

    return $ast;
}


method arity() {
    my $arity := 0;
    for self.entries {
        $arity := $arity + !($_.optional || $_.pos_slurpy || $_.named_slurpy);
    }
    $arity;
}


# Accessor for entries in the signature object.
method entries() {
    unless $!entries { $!entries := Q:PIR { %r = new ['ResizablePMCArray'] } }
    $!entries
}


# Tests if the signature declares the given symbol.
method declares_symbol($name) {
    for self.entries {
        if $_.var_name eq $name {
            return 1;
        }
    }
    return 0;
}

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 100
# End:
# vim: expandtab shiftwidth=4:
