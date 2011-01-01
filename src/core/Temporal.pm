use v6;

role Dateish {
    has Int $.year;
    has Int $.month = 1;
    has Int $.day = 1;

    multi method is-leap-year($y = $!year) {
        $y %% 4 and not $y %% 100 or $y %% 400
    }

    multi method days-in-month($year = $!year, $month = $!month) {
           $month == 2        ?? self.is-leap-year($year) ?? 29 !! 28
        !! $month == 4|6|9|11 ?? 30
        !! 31
    }

    method daycount-from-ymd($y is copy, $m is copy, $d) {
        # taken from <http://www.merlyn.demon.co.uk/daycount.htm>
        $y .= Int;
        $m .= Int;
        if $m < 3 {
            $m += 12;
            --$y;
        }
        -678973 + $d + (153 * $m - 2) div 5
            + 365 * $y + $y div 4
            - $y div 100  + $y div 400;
    }

    method ymd-from-daycount($daycount) {
        # taken from <http://www.merlyn.demon.co.uk/daycount.htm>
        my $day = $daycount.Int + 678881;
        my $t = (4 * ($day + 36525)) div 146097 - 1;
        my $year = 100 * $t;
        $day -= 36524 * $t + ($t +> 2);
        $t = (4 * ($day + 366)) div 1461 - 1;
        $year += $t;
        $day -= 365 * $t + ($t +> 2);
        my $month = (5 * $day + 2) div 153;
        $day -= (2 + $month * 153) div 5 - 1;
        if ($month > 9) {
            $month -= 12;
            $year++;
        }
        ($year, $month + 3, $day)
    }

    multi method get-daycount {
        self.daycount-from-ymd($.year, $.month, $.day)
    }

    method day-of-month() { $.day }
  
    method day-of-week($daycount = self.get-daycount) {
        ($daycount + 2) % 7 + 1
    }

    multi method week() { # algorithm from Claus Tøndering
        my $a = $.year - ($.month <= 2).floor;
        my $b = $a div 4 - $a div 100 + $a div 400;
        my $c = ($a - 1) div 4 - ($a - 1) div 100 + ($a - 1) div 400;
        my $s = $b - $c;
        my $e = $.month <= 2 ?? 0 !! $s + 1;
        my $f = $.day + do $.month <= 2
         ?? 31*($.month - 1) - 1
         !! (153*($.month - 3) + 2) div 5 + 58 + $s;

        my $g = ($a + $b) % 7;
        my $d = ($f + $g - $e) % 7;
        my $n = $f + 3 - $d;

           $n < 0           ?? ($.year - 1, 53 - ($g - $s) div 5)
        !! $n > 364 + $s    ?? ($.year + 1, 1)
        !!                     ($.year,     $n div 7 + 1);
    }

    multi method week-year() {
        self.week.[0]
    }

    multi method week-number() {
        self.week.[1]
    }

    multi method weekday-of-month {
        ($.day - 1) div 7 + 1
    }

    multi method day-of-year() {
        [+] $.day, map { self.days-in-month($.year, $^m) }, 1 ..^ $.month
    }

    method check-value($val is rw, $name, $range, :$allow-nonint) {
        $val = $allow-nonint ?? +$val !! $val.Int;
        $val ~~ $range or
            or die "$name must be in {$range.perl}\n";
    }
  
    method check-date { 
    # Asserts the validity of and numifies $!year, $!month, and $!day.
        $!year .= Int;
        self.check-value($!month, 'month', 1 .. 12);
        self.check-value($!day, "day of $!year/$!month",
            1 .. self.days-in-month);
    }

    method truncate-parts($unit, %parts is copy = ()) {
    # Helper for DateTime.truncated-to and Date.truncated-to.
        if $unit eq 'week' {
            my $dc = self.get-daycount;
            my $new-dc = $dc - self.day-of-week($dc) + 1;
            %parts<year month day> =
                self.ymd-from-daycount($new-dc);
        } else { # $unit eq 'month'|'year'
            %parts<day> = 1;
            $unit eq 'year' and %parts<month> = 1;
        }
        %parts;
    }

}

sub default-formatter(::DateTime $dt, Bool :$subseconds) {
# ISO 8601 timestamp (well, not strictly ISO 8601 if $subseconds
# is true)
    my $o = $dt.offset;
    $o %% 60
        or warn "Default DateTime formatter: offset $o not divisible by 60.\n";
    sprintf '%04d-%02d-%02dT%02d:%02d:%s%s',
        $dt.year, $dt.month, $dt.day, $dt.hour, $dt.minute,
        $subseconds
          ?? $dt.second.fmt('%09.6f')
          !! $dt.whole-second.fmt('%02d'),
        do $o
         ?? sprintf '%s%02d%02d',
                $o < 0 ?? '-' !! '+',
                ($o.abs / 60 / 60).floor,
                ($o.abs / 60 % 60).floor
         !! 'Z';
}

class DateTime-local-timezone does Callable {
    method Str { '<local time zone>' }
    method perl { '$*TZ' }

    method postcircumfix:<( )>($args) { self.offset(|$args) }

    method offset($dt, $to-utc) {
        # We construct local and UTC DateTimes, calculate POSIX times
        # (pretending the local DateTime is actually in UTC), and
        # return the difference. Surprisingly, this actually works!
        if $to-utc { Q:PIR {
            .local pmc dt, a
            dt = find_lex '$dt'
            # Create an array for encodelocaltime.
            a = new 'FixedIntegerArray'
            a = 9
            $P0 = dt.'whole-second'()
            a[0] = $P0
            $P0 = getattribute dt, '$!minute'
            a[1] = $P0
            $P0 = getattribute dt, '$!hour'
            a[2] = $P0
            $P0 = getattribute dt, '$!day'
            a[3] = $P0
            $P0 = getattribute dt, '$!month'
            a[4] = $P0
            $P0 = getattribute dt, '$!year'
            a[5] = $P0
            a[8] = -1
              # Indefinite Daylight-Saving state. This leaves it up
              # to whatever C library we're using to decide how to
              # interpret an ambiguous time.
            # Use encodelocaltime to get a POSIX time, and
            # subtract this from $dt's POSIX time.
            $I0 = encodelocaltime a
            $P0 = find_lex '$dt'
            $P0 = $P0.'posix'(true)
            $I1 = $P0
            $I0 = $I1 - $I0
            $P0 = $I0
            %r = $P0
        }; } else {
            my $p = $dt.posix;
            my ($year, $month, $day, $hour, $minute, $second);
            # Use decodelocaltime to build a local DateTime.
            Q:PIR {
                $P0 = find_lex '$p'
                $I0 = $P0
                .local pmc a
                a = decodelocaltime $I0
                $P0 = find_lex '$second'
                $I0 = a[0]
                '&infix:<=>'($P0, $I0)
                $P0 = find_lex '$minute'
                $I0 = a[1]
                '&infix:<=>'($P0, $I0)
                $P0 = find_lex '$hour'
                $I0 = a[2]
                '&infix:<=>'($P0, $I0)
                $P0 = find_lex '$day'
                $I0 = a[3]
                '&infix:<=>'($P0, $I0)
                $P0 = find_lex '$month'
                $I0 = a[4]
                '&infix:<=>'($P0, $I0)
                $P0 = find_lex '$year'
                $I0 = a[5]
                '&infix:<=>'($P0, $I0)
            };
            ::DateTime\
                .new(:$year, :$month, :$day, :$hour, :$minute, :$second)\
                .posix - $p;
        }
    }
}

class DateTime does Dateish {
    has Int $.hour      = 0;
    has Int $.minute    = 0;
    has     $.second    = 0.0;
    has     $.timezone  = 0; # UTC
    has     &.formatter; # = &default-formatter; # Doesn't work (not in scope?).
    has Int $!saved-offset;
      # Not an optimization but a necessity to ensure that
      # $dt.utc.local.utc is equivalent to $dt.utc. Otherwise,
      # DST-induced ambiguity could ruin our day.

    multi method new(Int :$year!, :&formatter=&default-formatter, *%_) {
        my $dt = self.bless(*, :$year, :&formatter, |%_);
        $dt.check-date;
        $dt.check-time;
        $dt;
    }

    method check-time { 
    # Asserts the validity of and numifies $!hour, $!minute, and $!second.
        self.check-value($!hour, 'hour', 0 ..^ 24);
        self.check-value($!minute, 'minute', 0 ..^ 60);
        self.check-value($!second, 'second', 0 ..^ 62, :allow-nonint);
        if $!second >= 60 {
            # Ensure this is an actual leap second.
            self.second < 61
                or die 'No second 61 has yet been defined';
            my $dt = self.utc;
            $dt.hour == 23 && $dt.minute == 59
                or die 'A leap second can occur only at hour 23 and minute 59 UTC';
            my $date = sprintf '%04d-%02d-%02d',
                $dt.year, $dt.month, $dt.day;
            $date eq any(tai-utc::leap-second-dates)
                or die "There is no leap second on UTC $date";
        }
    }

    multi method new(::Date :$date!, *%_) {
        self.new(year => $date.year, month => $date.month,
            day => $date.day, |%_)
    }

    multi method new(Instant $i, :$timezone=0, :&formatter=&default-formatter) {
        my ($p, $leap-second) = $i.to-posix;
        my $dt = self.new: floor($p - $leap-second), :&formatter;
        $dt.clone(second => $dt.second + $p % 1 + $leap-second
            ).in-timezone($timezone);
    }

    multi method new(Int $time is copy, :$timezone=0, :&formatter=&default-formatter) {
    # Interpret $time as a POSIX time.
        my $second  = $time % 60; $time = $time div 60;
        my $minute  = $time % 60; $time = $time div 60;
        my $hour    = $time % 24; $time = $time div 24;
        # Day month and leap year arithmetic, based on Gregorian day #.
        # 2000-01-01 noon UTC == 2451558.0 Julian == 2451545.0 Gregorian
        $time += 2440588;   # because 2000-01-01 == Unix epoch day 10957
        my $a = $time + 32044;     # date algorithm from Claus Tøndering
        my $b = (4 * $a + 3) div 146097; # 146097 = days in 400 years
        my $c = $a - (146097 * $b) div 4;
        my $d = (4 * $c + 3) div 1461;       # 1461 = days in 4 years
        my $e = $c - ($d * 1461) div 4;
        my $m = (5 * $e + 2) div 153; # 153 = days in Mar-Jul Aug-Dec
        my $day   = $e - (153 * $m + 2) div 5 + 1;
        my $month = $m + 3 - 12 * ($m div 10);
        my $year  = $b * 100 + $d - 4800 + $m div 10;
        self.bless(*, :$year, :$month, :$day,
            :$hour, :$minute, :$second,
            :&formatter).in-timezone($timezone);
    }

    multi method new(Str $format, :$timezone is copy = 0, :&formatter=&default-formatter) {
        $format ~~ /^ (\d**4) '-' (\d\d) '-' (\d\d) T (\d\d) ':' (\d\d) ':' (\d\d) (Z || (<[\-\+]>) (\d\d)(\d\d))? $/
            or die 'Invalid DateTime string; please an ISO 8601 timestamp';
        my $year   = (+$0).Int;
        my $month  = (+$1).Int;
        my $day    = (+$2).Int;
        my $hour   = (+$3).Int;
        my $minute = (+$4).Int;
        my $second = +$5;
        if $6 {
            $timezone
                and die "DateTime.new(Str): :timezone argument not allowed with a timestamp offset";
            if $6 eq 'Z' {
                $timezone = 0;                
            } else {
                $timezone = (($6[0][1]*60 + $6[0][2]) * 60).Int;
                  # RAKUDO: .Int is needed to avoid to avoid the nasty '-0'.
                $6[0][0] eq '-' and $timezone = -$timezone;
            }
        }
        self.new(:$year, :$month, :$day, :$hour, :$minute,
            :$second, :$timezone, :&formatter);
    }

    multi method now(:$timezone=$*TZ, :&formatter=&default-formatter) {
        self.new(now, :$timezone, :&formatter)
    }

    multi method clone(*%_) {
        self.new(:$!year, :$!month, :$!day,
            :$!hour, :$!minute, :$!second,
            timezone => $!timezone,
            formatter => &!formatter,
            |%_)
    }

    multi method clone-without-validating(*%_) { # A premature optimization.
        self.bless(*, :$!year, :$!month, :$!day,
            :$!hour, :$!minute, :$!second,
            timezone => $!timezone,
            formatter => &!formatter,
            |%_)
    }

    multi method Instant() {
        Instant.from-posix: self.posix + $.second % 1, $.second >= 60;
    }

    multi method posix($ignore-timezone?) {
        $ignore-timezone or self.offset == 0
            or return self.utc.posix;
        # algorithm from Claus Tøndering
        my $a = (14 - $.month.Int) div 12;
        my $y = $.year.Int + 4800 - $a;
        my $m = $.month.Int + 12 * $a - 3;
        my $jd = $.day + (153 * $m + 2) div 5 + 365 * $y
            + $y div 4 - $y div 100 + $y div 400 - 32045;
        ($jd - 2440588) * 24 * 60 * 60
            + 60*(60*$.hour + $.minute) + self.whole-second;
    }

    method offset {
        $!saved-offset or
            $!timezone ~~ Callable
         ?? $!timezone(self, True)
         !! $!timezone
    }

    multi method truncated-to(*%args) {
        %args.keys == 1
            or die 'DateTime.truncated-to: exactly one named argument needed';
        my $unit = %args.keys[0];
        $unit eq any(<second minute hour day week month year>)
            or die "DateTime.truncated-to: Unknown truncation unit '$unit'";
        my %parts;
        given $unit {
            %parts<second> = self.whole-second;
            when 'second'     {}
            %parts<second> = 0;
            when 'minute'     {}
            %parts<minute> = 0;
            when 'hour'       {}
            %parts<hour> = 0;
            when 'day'        {}
            # Fall through to Dateish.
            %parts = self.truncate-parts($unit, %parts);
        }
        self.clone-without-validating(|%parts);
    }

    multi method whole-second() {
        floor $.second
    }

    method in-timezone($timezone) {
        $timezone eqv $!timezone and return self;
        my $old-offset = self.offset;
        my $new-offset = $timezone ~~ Callable
          ?? $timezone(self.utc, False)
          !! $timezone;
        my %parts;
        # Is the logic for handling leap seconds right?
        # I don't know, but it passes the tests!
        my $a = ($!second >= 60 ?? 59 !! $!second)
            + $new-offset - $old-offset;
        %parts<second> = $!second >= 60 ?? $!second !! $a % 60;
        my $b = $!minute + floor $a / 60;
        %parts<minute> = $b % 60;
        my $c = $!hour + floor $b / 60;
        %parts<hour> = $c % 24;
        # Let Dateish handle any further rollover.
        floor $c / 24 and %parts<year month day> =
           self.ymd-from-daycount\
               (self.get-daycount + floor $c / 24);
        self.clone-without-validating:
            :$timezone, saved-offset => $new-offset, |%parts;
    }

    method utc() {
        self.in-timezone(0)
    }
    method local() {
        self.in-timezone($*TZ)
    }

    method Date() {
        ::Date.new(self)
    }

    method Str() {
        &!formatter(self)
    }

    multi method perl() {
        sprintf 'DateTime.new(%s)', join ', ', map { "{.key} => {.value}" }, do
            :$.year, :$.month, :$.day, :$.hour, :$.minute,
            second => $.second.perl,
            (timezone => $.timezone.perl
                unless $.timezone === 0),
            (:$!saved-offset
                if $!saved-offset and $.timezone ~~ Callable),
            (formatter => $.formatter.perl
                unless &.formatter eqv &default-formatter)
    }

}

class Date does Dateish {
    has Int $.daycount;

    method !set-daycount($dc) { $!daycount = $dc }

    multi method get-daycount { $!daycount }

    multi method new(:$year!, :$month, :$day) {
        my $d = self.bless(*, :$year, :$month, :$day);
        $d.check-date;
        $d!set-daycount(self.daycount-from-ymd($year,$month,$day));
        $d;
    }

    multi method new($year, $month, $day) {
        self.new(:$year, :$month, :$day);
    }

    multi method new(Str $date) {
        $date ~~ /^ \d\d\d\d '-' \d\d '-' \d\d $/
            or die 'Invalid Date string; please use the format "yyyy-mm-dd"';
        self.new(|$date.split('-').map(*.Int));
    }

    multi method new(::DateTime $dt) {
        self.bless(*, 
            :year($dt.year), :month($dt.month), :day($dt.day),
            :daycount(self.daycount-from-ymd($dt.year,$dt.month,$dt.day))
        );
    }

    multi method new-from-daycount($daycount) {
        my ($year, $month, $day) = self.ymd-from-daycount($daycount);
        self.bless(*, :$daycount, :$year, :$month, :$day);
    }

    multi method today() {
        self.new(::DateTime.now);
    }

    multi method truncated-to(*%args) {
        %args.keys == 1
            or die "Date.truncated-to: exactly one named argument needed.";
        my $unit = %args.keys[0];
        $unit eq any(<week month year>)
            or die "DateTime.truncated-to: Unknown truncation unit '$unit'";
        self.clone(|self.truncate-parts($unit));
    }

    multi method clone(*%_) {
        self.new(:$!year, :$!month, :$!day, |%_)
    }

    multi method succ() {
        Date.new-from-daycount($!daycount + 1);
    }
    multi method pred() {
        Date.new-from-daycount($!daycount - 1);
    }

    multi method Str() {
        sprintf '%04d-%02d-%02d', $.year, $.month, $.day;
    }

    multi method perl() {
        "Date.new($.year.perl(), $.month.perl(), $.day.perl())";
    }

}

multi infix:<+>(Date $d, Int $x) is export {
    Date.new-from-daycount($d.daycount + $x)
}
multi infix:<+>(Int $x, Date $d) is export {
    Date.new-from-daycount($d.daycount + $x)
}
multi infix:<->(Date $d, Int $x) is export {
    Date.new-from-daycount($d.daycount - $x)
}
multi infix:<->(Date $a, Date $b) is export {
    $a.daycount - $b.daycount;
}
multi infix:<cmp>(Date $a, Date $b) is export {
    $a.daycount cmp $b.daycount
}
multi infix:«<=>»(Date $a, Date $b) is export {
    $a.daycount <=> $b.daycount
}
multi infix:<==>(Date $a, Date $b) is export {
    $a.daycount == $b.daycount
}
multi infix:<!=>(Date $a, Date $b) is export {
    $a.daycount != $b.daycount
}
multi infix:«<=»(Date $a, Date $b) is export {
    $a.daycount <= $b.daycount
}
multi infix:«<»(Date $a, Date $b) is export {
    $a.daycount < $b.daycount
}
multi infix:«>=»(Date $a, Date $b) is export {
    $a.daycount >= $b.daycount
}
multi infix:«>»(Date $a, Date $b) is export {
    $a.daycount > $b.daycount
}

=begin pod

=head1 SEE ALSO
Perl 6 spec <S32-Temporal|http://perlcabal.org/syn/S32/Temporal.html>.
The Perl 5 DateTime Project home page L<http://datetime.perl.org>.
Perl 5 perldoc L<doc:DateTime> and L<doc:Time::Local>.
 
The best yet seen explanation of calendars, by Claus Tøndering
L<Calendar FAQ|http://www.tondering.dk/claus/calendar.html>.
Similar algorithms at L<http://www.hermetic.ch/cal_stud/jdn.htm>
and L<http://www.merlyn.demon.co.uk/daycount.htm>.
 
<ISO 8601|http://en.wikipedia.org/wiki/ISO_8601>
<Time zones|http://en.wikipedia.org/wiki/List_of_time_zones>

As per the recommendation, the strftime() method has bee moved into a
loadable module called DateTime::strftime.

=end pod
