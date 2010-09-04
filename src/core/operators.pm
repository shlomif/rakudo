our multi infix:<~~>(Mu $topic, Mu $matcher) {
    $matcher.ACCEPTS($topic)
}

our multi infix:<~~>(Mu $topic, Regex $matcher) {
    Q:PIR {
        $P0 = find_lex '$matcher'
        $P1 = find_lex '$topic'
        %r = $P0.'ACCEPTS'($P1)
        store_dynamic_lex '$/', %r
    };
}

our multi prefix:<?>(Mu $a) {
    pir::can($a, 'Bool')
    ?? $a.Bool
    !!  ( pir::istrue($a) ?? True !! False );
}

our multi prefix:<!>(Mu $a) {
    $a.Bool ?? False !! True;
}

our multi sub prefix:<->($a) {
    pir::neg__NN($a)
}

our multi sub infix:<+>($a, $b) {
    +$a + +$b;
}

our multi sub infix:<->($a, $b) {
    +$a - +$b;
}

our multi sub infix:<*>($a, $b) {
    +$a * +$b;
}

our multi sub infix:</>($a, $b) {
    +$a / +$b;
}

our multi sub infix:<%>($a, $b) {
    +$a % +$b;
}

our multi sub infix:<%%>($a, $b) {
    +$a % +$b == 0;
}

our multi sub infix:<**>($a, $b) {
    (+$a) ** +$b; # parenthesis needed because of precendence.
}

our multi sub infix:<&>(*@items) {
    Junction.new(@items, :all)
}

our multi sub infix:<|>(*@items) {
    Junction.new(@items, :any)
}

our multi sub infix:<^>(*@items) {
    Junction.new(@items, :one)
}

our multi sub infix:<+&>($a, $b) {
    pir::band__III($a, $b);
}

our multi sub infix:<+|>($a, $b) {
    pir::bor__III($a, $b);
}

our multi sub infix:<+^>($a, $b) {
    pir::bxor__III($a, $b);
}

our multi sub infix:«+<»($a, $b) {
    pir::shl__III($a, $b);
}

our multi sub infix:«+>»($a, $b) {
    pir::shr__III($a, $b);
}

our multi sub infix:<~|>($a, $b) {
    pir::bors__SSS($a, $b);
}

our multi sub infix:<~&>($a, $b) {
    pir::bands__SSS($a, $b);
}

our multi sub infix:<~^>($a, $b) {
    pir::bxors__SSS($a, $b);
}

our sub all(*@items) {
    Junction.new(@items, :all);
}

our sub any(*@items) {
    Junction.new(@items, :any);
}

our sub one(*@items) {
    Junction.new(@items, :one);
}

our sub none(*@items) {
    Junction.new(@items, :none);
}

our multi prefix:<not>(Mu $x) { !$x }

our multi prefix:<so>(Mu $x) { ?$x }

our multi prefix:sym<+^>($x) {
    pir::bnot__PP($x)
}

our sub undefine(Mu \$x) {
    my $undefined;
    $x = $undefined;
}

our multi infix:<does>(Mu \$doee, Role $r) {
    &infix:<does>($doee, $r!select)
}

our multi infix:<does>(Mu \$doee, ConcreteRole $r) {
    my $applicator = $r.^applier_for($doee);
    $applicator.apply($doee, [$r]);
    $doee
}

our multi infix:<does>(Mu \$doee, Parcel $roles) {
    my $*SCOPE = 'my';
    my $mr = RoleHOW.new();
    for @($roles) -> $r {
        $mr.^add_composable($r);
    }
    my $r = $mr.^compose();
    $doee does $r;
}

our multi infix:<does>(Mu \$doee, \$value) {
    # Need to manufacture a role here.
    my $r = RoleHOW.new();
    $r.^add_method($value.WHAT.perl, method () { $value });
    $doee does $r.^compose()
}

our multi infix:<but>(Mu \$doee, \$r) {
    $doee.clone() does $r
}

our multi infix:<before>($a, $b) {
    ($a cmp $b) == -1;
}

our multi infix:<after>($a, $b) {
    ($a cmp $b) == +1;
}

our multi infix:<?|>($a, $b) {
    ?(?$a +| ?$b)
}

our multi infix:<?&>($a, $b) {
    ?(?$a +& ?$b)
}

our multi infix:<?^>($a, $b) {
    ?(?$a +^ ?$b)
}

our multi infix:<min>(*@args) {
    @args.min;
}

our multi infix:<max>(*@args) {
    @args.max;
}

our multi infix:<minmax>(*@args) {
    @args.minmax;
}

our multi infix:«=>»($key, Mu $value) {
    Pair.new(key => $key, value => $value);
}

our multi infix:<~>($a, $b) {
    my $result = pir::new__Ps('Str');
    pir::assign__vPS($result, pir::concat__SSS(~$a, ~$b));
    $result
}

our sub circumfix:<{ }>(*@elements) {
    my %h = @elements;
    %h.item
}

our sub hash(*@list, *%hash) {
    my %h = (@list, %hash);
    %h
}

our multi infix:sym<//>(Mu $a, Mu $b) {
    $a.defined ?? $a !! $b
}

our multi infix:<==>($a, $b) {
    +$a == +$b;
}

our multi infix:<!=>(Mu $a, Mu $b) {
    $a !== $b
}

our multi infix:«<»($a, $b) {
    +$a < +$b;
}

our multi infix:«<=»($a, $b) {
    +$a <= +$b;
}

our multi infix:«>»($a, $b) {
    +$a > +$b;
}

our multi infix:«>=»($a, $b) {
    +$a >= +$b;
}

our multi infix:<eq>($a, $b) {
    pir::iseq__ISS(~$a, ~$b) ?? True !! False
}

our multi infix:<ne>(Mu $a, Mu $b) {
    $a !eq $b
}

our multi infix:<lt>($a, $b) {
    pir::islt__ISS(~$a, ~$b) ?? True !! False
}

our multi infix:<le>($a, $b) {
    pir::isle__ISS(~$a, ~$b) ?? True !! False
}

our multi infix:<gt>($a, $b) {
    pir::isgt__ISS(~$a, ~$b) ?? True !! False
}

our multi infix:<ge>($a, $b) {
    pir::isge__ISS(~$a, ~$b) ?? True !! False
}

# XXX Lazy version would be nice in the future too.
class Whatever { ... }

our multi infix:<xx>(Mu \$item, Whatever) {
    (1..*).map( { $item } )
}

our multi infix:<xx>(Mu \$item, $n) {
    (1..+$n).map( { $item } )
}


our multi prefix:<|>(@a) { @a.Capture }
our multi prefix:<|>(%h) { %h.Capture }
our multi prefix:<|>(Capture $c) { $c }
our multi prefix:<|>(Mu $anything) { Capture.new($anything) }

our multi infix:<:=>(Mu \$target, Mu \$source) {
    #Type Checking. The !'s avoid putting actual binding in a big nest.
    if !pir::isnull(pir::getprop__PsP('type', $target)) {
        if !pir::getprop__PsP('type', $target).ACCEPTS($source) {
            die("You cannot bind a variable of type {$source.WHAT} to a variable of type {$target.WHAT}.");
        }
    }

    if !pir::isnull(pir::getprop__PsP('WHENCE', pir::descalarref__PP($target)))
        { pir::getprop__PsP('WHENCE', pir::descalarref__PP($target)).() }

    #and now, for the actual process
    pir::setprop__0PsP(
        pir::copy__0PP($target, pir::new__PsP('ObjectRef', $source)),
        'rw',
        pir::getprop__PsP('rw', $source)
    );
}

our multi infix:<:=>(Signature $s, Parcel \$p) {
    $s!BIND($p.Capture());
}

our multi infix:<:=>(Signature $s, Mu \$val) {
    $s!BIND(Capture.new($val));
}

our multi infix:<::=>(Mu \$target, Mu \$source) {
    #since it's only := with setting readonly, let's avoid recoding.
    $target := $source;
    #XX pay attention to this little guy, we don't quite understand or are
    #able to implement the full details of ::=
    pir::delprop__0Ps($target, 'rw');
}

# XXX Wants to be a macro when we have them.
our sub WHAT(\$x) {
    $x.WHAT
}

our multi sub item(*@values) {
    @values.Seq
}
our multi sub item(@values) {
    @values.Seq
}
our multi sub item($item) {
    $item
}

our multi sub infix:<...>(@lhs is copy, $rhs) {
    my sub succ-or-pred($lhs, $rhs) {
        if $lhs ~~ Str && $rhs ~~ Str && $lhs.chars == 1 && $rhs.chars == 1 {
            if $lhs cmp $rhs != 1 {
                -> $x { $x.ord.succ.chr };
            } else {
                -> $x { $x.ord.pred.chr };
            }
        } elsif $rhs ~~ Whatever || $lhs cmp $rhs != 1 {
            -> $x { $x.succ };
        } else {
            -> $x { $x.pred };
        }
    }

    my sub succ-or-pred2($lhs0, $lhs1, $rhs) {
        if $lhs1 cmp $lhs0 == 0 {
            $next = { $_ };
        } else {
            $next = succ-or-pred($lhs1, $rhs);
        }
    }

    my sub is-on-the-wrong-side($first , $second , $third , $limit , $is-geometric-switching-sign) {
        return Bool::False if $limit ~~ Whatever;
        if $is-geometric-switching-sign {
            ($second.abs >= $third.abs && $limit.abs > $first.abs) || ($second.abs <= $third.abs && $limit.abs < $first.abs);
        } else {
            ($second >= $third && $limit > $first) || ($second <= $third && $limit < $first);
        }
    }

    my $limit;
    $limit = $rhs if !($rhs ~~ Whatever);

    my $is-geometric-switching-sign = Bool::False;
    my $next;
    if @lhs[@lhs.elems - 1] ~~ Code {
        $next = @lhs.pop;
    } else {
        given @lhs.elems {
            when 0 { fail "Need something on the LHS"; }
            when 1 {
                $next = succ-or-pred(@lhs[0], $rhs)
            }
            default {
                my $diff = @lhs[*-1] - @lhs[*-2];
                if $diff == 0 {
                    $next = succ-or-pred2(@lhs[*-2], @lhs[*-1], $rhs)
                } elsif @lhs.elems == 2 || @lhs[*-2] - @lhs[*-3] == $diff {
                    return Nil if is-on-the-wrong-side(@lhs[0] , @lhs[*-2] , @lhs[*-1] , $rhs , Bool::False);
                    $next = { $_ + $diff };
                } elsif @lhs[*-2] / @lhs[*-3] == @lhs[*-1] / @lhs[*-2] {
                    $is-geometric-switching-sign = (@lhs[*-2] * @lhs[*-1] < 0);
                    return Nil if is-on-the-wrong-side(@lhs[*-3] , @lhs[*-2] , @lhs[*-1] , $rhs , $is-geometric-switching-sign) ;
                    my $factor = @lhs[*-2] / @lhs[*-3];
                    if $factor ~~ ::Rat && $factor.denominator == 1 {
                        $factor = $factor.Int;
                    }
                    $next = { $_ * $factor };
                } else {
                    fail "Unable to figure out pattern of series";
                }
            }
        }
    }

    my $arity = any( $next.signature.params>>.slurpy ) ?? Inf !! $next.count;

    gather {
        my @args;
        my $previous;
        my $top = $arity min @lhs.elems;
        my $lhs-orig-count = @lhs.elems ;
        my $count=0;

        if @lhs || !$limit.defined || $limit cmp $previous != 0 {
            loop {
                @args.push(@lhs[0]) if @lhs && $count >= $lhs-orig-count - $top;
                my $current = @lhs.shift()  // $next.(|@args) // last;

                my $cur_cmp = 1;
                if $limit.defined {
                    $cur_cmp = $limit cmp $current;
                    if $previous.defined {
                        my $previous_cmp = $previous cmp $limit;
                        if ($is-geometric-switching-sign) {
                            $cur_cmp = $limit.abs cmp $current.abs;
                            $previous_cmp = $previous.abs cmp $limit.abs;
                        }
                        last if @args && $previous_cmp == $cur_cmp ;
                    }
                }
                $previous = $current;
                take $current ;
                $count++;

                last if $cur_cmp == 0;

                @args.push($previous) if $count > $lhs-orig-count;
                while @args.elems > $arity {
                    @args.shift;
                }
            }
        }
    }
}

our multi sub infix:<...>($lhs, $rhs) {
    $lhs.list ... $rhs;
}

our multi sub infix:<...>($lhs, @rhs is copy) {
    fail "Need something on RHS" if !@rhs;
    ($lhs ... @rhs.shift), @rhs
}

our multi sub infix:<...>(@lhs, @rhs is copy) {
    fail "Need something on RHS" if !@rhs;
    (@lhs ... @rhs.shift), @rhs
}

our multi sub infix:<eqv>(Mu $a, Mu $b) {
    $a.WHAT === $b.WHAT && $a === $b;
}

our multi sub infix:<eqv>(@a, @b) {
    unless @a.WHAT === @b.WHAT && @a.elems == @b.elems {
        return Bool::False
    }
    for @a.keys -> $i {
        unless @a[$i] eqv @b[$i] {
            return Bool::False;
        }
    }
    Bool::True
}

our multi sub infix:<eqv>(Pair $a, Pair $b) {
    $a.key eqv $b.key && $a.value eqv $b.value;
}

our multi sub infix:<eqv>(Capture $a, Capture $b) {
    @($a) eqv @($b) && %($a) eqv %($b)
}

class EnumMap { ... }
our multi sub infix:<eqv>(EnumMap $a, EnumMap $b) {
    if +$a != +$b { return Bool::False }
    for $a.kv -> $k, $v {
        unless $b.exists($k) && $b{$k} eqv $v {
            return Bool::False;
        }
    }
    Bool::True;
}

our multi sub infix:<eqv>(Numeric $a, Numeric $b) {
    $a.WHAT === $b.WHAT && ($a cmp $b) == 0;
}

our multi sub infix:<Z>($lhs, $rhs) {
    my $lhs-list = flat($lhs.list);
    my $rhs-list = flat($rhs.list);
    gather while ?$lhs-list && ?$rhs-list {
        my $a = $lhs-list.shift;
        my $b = $rhs-list.shift;
        take $a;
        take $b;
    }
}

our multi sub infix:<X>($lhs, $rhs) {
    my $lhs-list = flat($lhs.list);
    my $rhs-list = flat($rhs.list);
    gather while ?$lhs-list {
        my $a = $lhs-list.shift;
        for @($rhs-list) -> $b {
            my $b-copy = $b;
            take ($a, $b-copy);
        }
    }
}

# if we want &infix:<||> accessible (for example for meta operators), we need
# to define it, because the normal || is short-circuit and special cased by
# the grammar. Same goes for 'or', '&&' and 'and'

our multi sub infix:<||>(Mu $a, Mu $b) { $a || $b }
our multi sub infix:<or>(Mu $a, Mu $b) { $a or $b }
our multi sub infix:<&&>(Mu $a, Mu $b) { $a && $b }
our multi sub infix:<and>(Mu $a, Mu $b) { $a and $b }

# Eliminate use of this one, but keep the pir around for
# the moment, as it may come in handy elsewhere.
#
# multi sub infix_prefix_meta_operator:<!>($a, $b, $c) {
#     !(pir::get_hll_global__CS($a)($b, $c));
# }

our multi sub infix:«<==»($a, $b) {
    die "Sorry, feed operators not yet implemented";
}

our multi sub infix:«==>»($a, $b) {
    die "Sorry, feed operators not yet implemented";
}

our multi sub infix:«<<==»($a, $b) {
    die "Sorry, feed operators not yet implemented";
}

our multi sub infix:«==>>»($a, $b) {
    die "Sorry, feed operators not yet implemented";
}
