#!/usr/bin/perl
# Markdown markup language
package IkiWiki::Plugin::mdwn;

use warnings;
use strict;
use IkiWiki;

sub import { #{{{
	hook(type => "htmlize", id => "mdwn", call => \&htmlize);
} # }}}

my $markdown_sub;
sub htmlize (@) { #{{{
	my %params=@_;
	my $content = $params{content};

	if (! defined $markdown_sub) {
		# Markdown is forked and splintered upstream and can be
		# available in a variety of incompatible forms. Support
		# them all.
		no warnings 'once';
		$blosxom::version="is a proper perl module too much to ask?";
		use warnings 'all';

		eval q{use Markdown};
		if (! $@) {
			$markdown_sub=\&Markdown::Markdown;
		}
		else {
			eval q{use Text::Markdown};
			if (! $@) {
				$markdown_sub=\&Text::Markdown::Markdown;
			}
			else {
				do "/usr/bin/markdown" ||
					error("failed to load Markdown.pm perl module ($@) or /usr/bin/markdown ($!)");
				$markdown_sub=\&Markdown::Markdown;
			}
		}
		require Encode;
	}
	
	# Workaround for perl bug (#376329)
	$content=Encode::encode_utf8($content);
	$content=Encode::encode_utf8($content);
	$content=Markdown::Markdown($content);
	$content=Encode::decode_utf8($content);
	$content=Encode::decode_utf8($content);

	return $content;
} # }}}

1
