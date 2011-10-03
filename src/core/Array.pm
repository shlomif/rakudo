class Array {
    # Has attributes and parent List declared in BOOTSTRAP.    

    method new(|$) { 
        my Mu $args := pir::perl6_current_args_rpa__P();
        nqp::shift($args);
        nqp::p6list($args, self.WHAT, Bool::True);
    }
    
    method at_pos($pos is copy) is rw {
        $pos = $pos.Int;
        self.exists($pos)
          ?? nqp::atpos(nqp::getattr(self, List, '$!items'), nqp::unbox_i($pos))
          !! pir::setattribute__0PPsP(my $v, Scalar, '$!whence',
                 -> { nqp::bindpos(nqp::getattr(self, List, '$!items'), nqp::unbox_i($pos), $v) } )
    }

    method flattens() { 1 }

    multi method perl(Array:D \$self:) {
        nqp::iscont($self)
          ?? '[' ~ self.map({.perl}).join(', ') ~ ']'
          !! self.WHAT.perl ~ '.new(' ~ self.map({.perl}).join(', ') ~ ')'
    }

    method REIFY(Parcel \$parcel) {
        my Mu $rpa := nqp::getattr($parcel, Parcel, '$!storage');
        my Mu $iter := nqp::iterator($rpa);
        my $i = 0;
        while $iter {
            nqp::bindpos($rpa, nqp::unbox_i($i++), my $v = nqp::shift($iter));
        }
        pir::find_method__PPs(List, 'REIFY')(self, $parcel)
    }

    method STORE_AT_POS(\$pos, Mu $v is copy) is rw {
        pir::find_method__PPs(List, 'STORE_AT_POS')(self, $pos, $v);
    }

    method STORE(|$) {
        # get arguments, shift off invocant
        my $args := pir::perl6_current_args_rpa__P();
        nqp::shift($args);
        # clear our current items, and create a flattening iterator
        # that will bring in values from $args
        nqp::bindattr(self, List, '$!items', Mu);
        nqp::bindattr(self, List, '$!nextiter', nqp::p6listiter($args, self));
        self.eager
    }

}


sub circumfix:<[ ]>(*@elems) is rw { my $x = @elems }
