#!/usr/bin/perl
# Provides a list of pages no other page links to.
package IkiWiki::Plugin::orphans;

use warnings;
use strict;
use IkiWiki;

sub import { #{{{
	hook(type => "preprocess", id => "orphans", call => \&preprocess);
} # }}}

sub preprocess (@) { #{{{
	my %params=@_;
	$params{pages}="*" unless defined $params{pages};
	
	# Needs to update whenever a page is added or removed, so
	# register a dependency.
	add_depends($params{page}, $params{pages});
	
	my %linkedto;
	foreach my $p (keys %links) {
		map { $linkedto{bestlink($p, $_)}=1 if length $_ }
			@{$links{$p}};
	}
	
	my @orphans;
	my $discussion=gettext("discussion");
	foreach my $page (keys %pagesources) {
		next if $linkedto{$page};
		next unless pagespec_match($page, $params{pages}, $params{page});
		# If the page has a link to some other page, it's
		# indirectly linked to a page via that page's backlinks.
		next if grep { 
			length $_ &&
			($_ !~ /\/\Q$discussion\E$/i || ! $config{discussion}) &&
			bestlink($page, $_) !~ /^($page|)$/ 
		} @{$links{$page}};
		push @orphans, $page;
	}
	
	return gettext("All pages are linked to by other pages.") unless @orphans;
	return "<ul>\n".
		join("\n",
			map {
				"<li>".
				htmllink($params{page}, $params{destpage}, $_,
					 noimageinline => 1).
				"</li>"
			} sort @orphans).
		"</ul>\n";
} # }}}

1
