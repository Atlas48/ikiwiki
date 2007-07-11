#!/usr/bin/perl
package IkiWiki::Plugin::htmlscrubber;

use warnings;
use strict;
use IkiWiki 2.00;

sub import { #{{{
	hook(type => "sanitize", id => "htmlscrubber", call => \&sanitize);
} # }}}

sub sanitize (@) { #{{{
	my %params=@_;
	return scrubber()->scrub($params{content});
} # }}}

my $_scrubber;
sub scrubber { #{{{
	return $_scrubber if defined $_scrubber;
	
	eval q{use HTML::Scrubber};
	error($@) if $@;
	# Lists based on http://feedparser.org/docs/html-sanitization.html
	$_scrubber = HTML::Scrubber->new(
		allow => [qw{
			a abbr acronym address area b big blockquote br
			button caption center cite code col colgroup dd del
			dfn dir div dl dt em fieldset font form h1 h2 h3 h4
			h5 h6 hr i img input ins kbd label legend li map
			menu ol optgroup option p pre q s samp select small
			span strike strong sub sup table tbody td textarea
			tfoot th thead tr tt u ul var
		}],
		default => [undef, { (
			map { $_ => 1 } qw{
				abbr accept accept-charset accesskey action
				align alt axis border cellpadding cellspacing
				char charoff charset checked cite class
				clear cols colspan color compact coords
				datetime dir disabled enctype for frame
				headers height href hreflang hspace id ismap
				label lang longdesc maxlength media method
				multiple name nohref noshade nowrap prompt
				readonly rel rev rows rowspan rules scope
				selected shape size span src start summary
				tabindex target title type usemap valign
				value vspace width
			} ),
			"/" => 1, # emit proper <hr /> XHTML
			}],
	);
	return $_scrubber;
} # }}}

1
