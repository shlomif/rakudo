#!/usr/bin/env perl
use strict;
use warnings;
use MIME::Lite;

sub format_patch {
    my $what = shift;
    open my $h, '-|', qw(git format-patch), $what
        or die qq/Can't launch "git format-patch $what": $!/;
    my @filenames = <$h>;
    chomp @filenames;
    close $h or die qq/Error while executing "git format-patch $what": $!"/;
    return @filenames;
}

sub parse_mail {
    my $fn = shift;
    open my $h, '<', $fn or die "Can't open '$fn' for reading: $!";
    my %header;
    while (<$h>) {
        chomp;
        if (m/^(\w+): (.*)$/) {
            $header{$1} = $2;
        }
        last if m/^\s*$/;
    }
    return \%header;
}

sub MAIN {
    my @filenames = format_patch($ARGV[-1] || '-1');
    my $header = parse_mail($filenames[0]);
    my $mail = MIME::Lite->new(
            From    => $header->{From},
            To      => 'Rakudo patches <moritz@faui2k3.org>',
            Subject => $header->{Subject},
            Type    => 'multipart/mixed',
    );

    $mail->attach(
            Type    => 'TEXT',
            Data    => 'A sample e-mail',
    );

    for (@filenames) {
        $mail->attach(
                Type        => 'text/plain',
                Filename    => $_,
                Path        => $_,
                Disposition => 'attachment',
        );
    }

    $mail->send('smtp', 'faui2k3.org', Debug => 1);
}

MAIN() unless caller;
