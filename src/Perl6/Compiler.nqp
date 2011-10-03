use NQPP6Regex;
use QRegex;

class Perl6::Compiler is HLL::Compiler {
    method command_eval(*@args, *%options) {
        if pir::exists(%options, 'doc') && !%options<doc> {
            %options<doc> := 'text';
        }

        my $hll_ns := pir::get_root_global__Ps('perl6');
        my $argiter := nqp::iterator(@args);
        nqp::shift($argiter) if $argiter && !pir::defined(%options<e>);
        $hll_ns<$!ARGITER> := $argiter;
        my $super := pir::find_method__PPs(HLL::Compiler, 'command_eval');
        my %*COMPILING;
        %*COMPILING<%?OPTIONS> := %options;
        $super(self, |@args, |%options);
    }

    method autoprint($value) {
        unless pir::getinterp__P().stdout_handle().tell() > $*AUTOPRINTPOS {
            if pir::can($value, 'gist') {
                nqp::say(nqp::unbox_s($value.gist));
            } else {
                nqp::say(~$value);
            }
        }
    }
}


