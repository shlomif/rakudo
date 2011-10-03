
sub METAOP_ASSIGN(\$op) {
    -> Mu \$a, Mu \$b { $a = $op( $a // $op(), $b) }
}

sub METAOP_NEGATE(\$op) {
    -> Mu \$a, Mu \$b { !$op($a,$b) }
}

sub METAOP_REVERSE(\$op) {
    -> Mu \$a, Mu \$b { $op($b, $a) }
}

sub METAOP_CROSS(\$op) {
    -> **@lol {
        my $rop = METAOP_REDUCE($op);
        my @l;
        my @v;
        @l[0] = (@lol[0].flat,).list;
        my $i = 0;
        my $n = @lol.elems - 1;
        gather {
            while $i >= 0 {
                if @l[$i] {
                    @v[$i] = @l[$i].shift;
                    if $i >= $n { my @x = @v; take $rop(|@x); }
                    else {
                        $i++;
                        @l[$i] = (@lol[$i].flat,).list;
                    }
                }
                else { $i--; }
            }
        }
    }
}

sub METAOP_ZIP(\$op) {
    -> **@lol {
        my $rop = METAOP_REDUCE($op);
        my @l = @lol.map({ (.flat,).list.item });
        gather {
            my $loop = 1;
            while $loop {
                my @z = @l.map({ $loop = 0 unless $_; .shift });
                take-rw $rop(|@z) if $loop;
            }
        }
    }
}

sub METAOP_REDUCE(\$op, :$triangle) {
    my $x :=
    sub (*@values) {
        if $triangle {
            return () unless @values;
            GATHER({
                my $result := @values.shift;
                take $result;
                take ($result := $op($result, @values.shift))
                    while @values;
            }, :infinite(@values.infinite))
        }
        else {
            return $op() unless @values;
            my $result := @values.shift;
            return $op($result) unless @values;
            $result := $op($result, @values.shift)
                while @values;
            $result;
        }
    }
}

sub METAOP_REDUCE_RIGHT(\$op, :$triangle) {
    my $x :=
    sub (*@values) {
        my $list = @values.reverse;
        if $triangle {
            return () unless $list;
            gather {
                my $result := $list.shift;
                take $result;
                take ($result := $op($list.shift, $result))
                    while $list;
            }
        }
        else {
            return $op() unless $list;
            my $result := $list.shift;
            return $op($result) unless $list;
            $result := $op($list.shift, $result)
                while $list;
            $result;
        }
    }
}


sub METAOP_REDUCE_CHAIN(\$op, :$triangle) {
    $triangle
        ??  sub (*@values) {
                my Mu $current = @values.shift;
                my $state = $op();
                gather {
                    take $state;
                    while $state && @values {
                        $state = $op($current, @values[0]);
                        take $state;
                        $current = @values.shift;
                    }
                    take False for @values;
                }

            }
        !! sub (*@values) {
                my $state = $op();
                my Mu $current = @values.shift;
                while @values {
                    $state = $op($current, @values[0]);
                    $current = @values.shift;
                    return $state unless $state;
                }
                $state;
            }
}


sub METAOP_REDUCE_XOR(\$op, :$triangle) {
    NYI "xor reduce NYI";
}

sub METAOP_HYPER(\$op, *%opt) {
    -> Mu \$a, Mu \$b { hyper($op, $a, $b, |%opt) }
}

sub METAOP_HYPER_POSTFIX(\$obj, \$op) { hyper($op, $obj) }

sub METAOP_HYPER_PREFIX(\$op, \$obj) { hyper($op, $obj) }

proto sub hyper(|$) { * }
multi sub hyper(\$op, \$a, \$b, :$dwim-left, :$dwim-right) { 
    my @alist := $a.flat;
    my @blist := $b.flat;
    my $elems = 0;
    if $dwim-left && $dwim-right { $elems = max(@alist.elems, @blist.elems) }
    elsif $dwim-left { $elems = @blist.elems }
    elsif $dwim-right { $elems = @alist.elems }
    else { 
        die "Sorry, lists on both sides of non-dwimmy hyperop are not of same length:\n"
            ~ "    left: @alist.elems() elements, right: @blist.elems() elements\n"
          if @alist.elems != @blist.elems
    }
    @alist := (@alist xx *).munch($elems) if @alist.elems < $elems;
    @blist := (@blist xx *).munch($elems) if @blist.elems < $elems;

    (@alist Z @blist).map(
        -> \$x, \$y {
            Iterable.ACCEPTS($x)
              ?? $x.new(hyper($op, $x, $y, :$dwim-left, :$dwim-right)).item
              !! (Iterable.ACCEPTS($y)
                    ?? $y.new(hyper($op, $x, $y, :$dwim-left, :$dwim-right)).item
                    !! $op($x, $y))
        }
    ).eager
}

multi sub hyper(\$op, \$obj) {
    my Mu $rpa := nqp::list();
    my $a := $obj.flat.eager;
    for (^$a.elems).pick(*) {
        my $o := $a.at_pos($_);
        nqp::bindpos($rpa, nqp::unbox_i($_),
            Iterable.ACCEPTS($o)
              ?? $o.new(hyper($op, $o)).item
              !! $op($o));
    }
    nqp::p6parcel($rpa, Nil);
}

multi sub hyper(\$op, Associative \$h) {
    my @keys = $h.keys;
    hash @keys Z hyper($op, $h{@keys})
}

multi sub hyper(\$op, Associative \$a, Associative \$b, :$dwim-left, :$dwim-right) {
    my %k;
    for $a.keys { %k{$_} = 1 if !$dwim-left || $b.exists($_) }
    for $b.keys { %k{$_} = 1 if !$dwim-right }
    my @keys = %k.keys;
    hash @keys Z hyper($op, $a{@keys}, $b{@keys}, :$dwim-left, :$dwim-right)
}

multi sub hyper(\$op, Associative \$a, \$b, :$dwim-left, :$dwim-right) {
    my @keys = $a.keys;
    hash @keys Z hyper($op, $a{@keys}, $b, :$dwim-left, :$dwim-right);
}

multi sub hyper(\$op, \$a, Associative \$b, :$dwim-left, :$dwim-right) {
    my @keys = $b.keys;
    hash @keys Z hyper($op, $a, $b{@keys}, :$dwim-left, :$dwim-right);
}

