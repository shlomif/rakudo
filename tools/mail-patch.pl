#!/usr/bin/env perl
use strict;
use warnings;
use MIME::Lite;
use Getopt::Long;

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

    my $s = !GetOptions(
            'subject=s' => \my $subject,
            'help'      => \my $help,
    );
    if ($s || $help) {
        usage();
        exit $s;
    }
    my @filenames = format_patch($ARGV[-1] || '-1');

    if (@filenames > 0 && !$subject) {
        unlink @filenames;
        die "you need to supply a subject with the --subject option\n"
            "when you want to submit multiple patches\n";
    }

    my $header = parse_mail($filenames[0]);
    my $mail = MIME::Lite->new(
            From    => $header->{From},
            To      => 'Rakudo patches <moritz@faui2k3.org>',
            Subject => $subject || $header->{Subject},
            Type    => 'multipart/mixed',
    );

    $mail->attach(
            Type    => 'TEXT',
            Data    => "Patches submitted via toos/mail-patch.pl\n",
    );

    for (@filenames) {
        $mail->attach(
                Type        => 'text/plain',
                Filename    => $_,
                Path        => $_,
                Disposition => 'attachment',
        );
    }

    $| = 1;
    print "sending mail ...";
    $mail->send('smtp', 'faui2k3.org');
    print " done\n";
}

MAIN() unless caller;

sub usage {
    print <<"USAGE";
Usage:
    $0 [options] [WHAT]

Options:
    --help          This help message
    --subject=subj  Set a subject for the mail. Mandatory when multiple
                    patches are submitted. Otherwise defaults to the
                    first line of the commit message

Arguments:
    WHAT            What patches to send. -2 means "the last two commits",
                    a branch name means "all the difference to that branch".
                    Defaults to -1 (last commit)

USAGE
}
