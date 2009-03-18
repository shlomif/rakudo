#! perl

=head1 NAME

perl6-with-limits.pl - execute Rakudo with resource limits set, if possible

=cut

if ($^O eq 'linux') {
    exit system "ulimit -t 120; ./perl6 @ARGV";
} else {
    exec './perl6', @ARGV;
}
