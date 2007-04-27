#!/usr/bin/perl
# HTML Tidy plugin
# requires 'tidy' binary, found in Debian or http://tidy.sf.net/
# mostly a proof-of-concept on how to use external filters.
# It is particularly useful when the html plugin is used.
#
# by Faidon Liambotis
package IkiWiki::Plugin::htmltidy;

use warnings;
use strict;
use IkiWiki 2.00;
use IPC::Open2;

sub import { #{{{
	hook(type => "sanitize", id => "tidy", call => \&sanitize);
} # }}}

sub sanitize (@) { #{{{
	my %params=@_;

	my $pid;
	my $sigpipe=0;
	$SIG{PIPE}=sub { $sigpipe=1 };
	$pid=open2(*IN, *OUT, 'tidy -quiet -asxhtml -utf8 --show-body-only yes --show-warnings no --tidy-mark no');
	
	# open2 doesn't respect "use open ':utf8'"
	binmode (IN, ':utf8');
	binmode (OUT, ':utf8'); 
	
	print OUT $params{content};
	close OUT;

	local $/ = undef;
	my $ret=<IN>;
	close IN;
	waitpid $pid, 0;

	return $params{content} if $sigpipe;
	$SIG{PIPE}="DEFAULT";

	return $ret;
} # }}}

1
